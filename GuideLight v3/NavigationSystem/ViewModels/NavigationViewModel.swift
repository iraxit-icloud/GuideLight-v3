//
//  NavigationViewModel.swift
//  GuideLight v3
//
//  Multi-stop navigation with arrival messages + dynamic veil + real % progress
//

import Foundation
import ARKit
import Combine
import simd

// MARK: - Selection result for voice workflows
enum DestinationSelectionResult {
    case success(String)           // picked name
    case ambiguous([Beacon])       // top candidates
    case notFound
}

// MARK: - Navigation View Model
@MainActor
class NavigationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var navigationState: NavigationState = .notStarted
    @Published var currentPath: NavigationPath?
    @Published var currentWaypointIndex: Int = 0
    @Published var progress: NavigationProgress?
    @Published var destinationBeacon: Beacon?
    @Published var availableDestinations: [Beacon] = []
    
    // Arrival message system
    @Published var arrivalMessage: String?
    @Published var showArrivalMessage: Bool = false
    
    // Path JSON for external visualization
    @Published var pathJSON: String?
    
    // Dynamic veil (readability in bright scenes)
    @Published var ambientLightIntensity: Float = 1000    // ~0..2000+ (ARKit)
    @Published var veilOpacity: Double = 0.72             // 0.5..0.9 dynamically adjusted
    
    // MARK: - Private Properties
    private var arSession: ARSession?
    public let map: IndoorMap
    private let pathfinder: PathfindingEngine
    private var lastUpdateTime: Date?
    private var lastDistanceToWaypoint: Float?
    private var calibration: CalibrationData
    
    private let arrivalThreshold: Float = 0.5
    private let updateInterval: TimeInterval = 0.1
    
    // MARK: - Computed Properties
    
    var currentWaypoint: NavigationWaypoint? {
        guard let path = currentPath,
              currentWaypointIndex < path.waypoints.count else {
            return nil
        }
        return path.waypoints[currentWaypointIndex]
    }
    
    var nextWaypoint: NavigationWaypoint? {
        guard let path = currentPath,
              currentWaypointIndex + 1 < path.waypoints.count else {
            return nil
        }
        return path.waypoints[currentWaypointIndex + 1]
    }
    
    var isAtDestination: Bool {
        guard let path = currentPath else { return false }
        return currentWaypointIndex >= path.waypoints.count - 1
    }
    
    // MARK: - Initialization
    
    init(map: IndoorMap, calibration: CalibrationData) {
        self.map = map
        self.calibration = calibration
        self.pathfinder = PathfindingEngine(map: map)
        
        CoordinateTransformManager.setCalibration(calibration)
        
        availableDestinations = map.beacons.filter { beacon in
            beacon.isAccessible && !beacon.isObstacle
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        print("🧭 Navigation initialized")
        print("   Available destinations: \(availableDestinations.count)")
    }
    
    // MARK: - Voice: select by name with fuzzy match
    
    /// Voice-friendly entry point. Attempts to match a destination name and, if found (or unambiguous),
    /// starts navigation immediately.
    func selectDestination(named raw: String,
                           session: ARSession,
                           currentPosition: simd_float3) async -> DestinationSelectionResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .notFound }
        
        let candidates = fuzzyMatchDestinations(query: trimmed)
        guard !candidates.isEmpty else { return .notFound }
        
        if candidates.count == 1 {
            self.selectDestination(candidates[0], currentPosition: currentPosition, session: session)
            return .success(candidates[0].name)
        }
        
        // If multiple candidates, prefer exact/starts-with/contains ranking; if still >1, return ambiguous
        let ranked = rank(candidates: candidates, for: trimmed)
        if ranked.count > 1 {
            return .ambiguous(Array(ranked.prefix(3)))
        } else if let only = ranked.first {
            self.selectDestination(only, currentPosition: currentPosition, session: session)
            return .success(only.name)
        }
        return .notFound
    }
    
    private func fuzzyMatchDestinations(query: String) -> [Beacon] {
        let q = normalize(query)
        if q.isEmpty { return [] }
        // 1) exact (case/diacritics-insensitive)
        let exact = availableDestinations.filter { normalize($0.name) == q }
        if !exact.isEmpty { return exact }
        // 2) starts-with
        let starts = availableDestinations.filter { normalize($0.name).hasPrefix(q) }
        if !starts.isEmpty { return starts }
        // 3) contains
        let contains = availableDestinations.filter { normalize($0.name).contains(q) }
        if !contains.isEmpty { return contains }
        // 4) whitespace-insensitive contains (e.g., "conf room a" vs "conference room a")
        let nowhiteQ = q.replacingOccurrences(of: " ", with: "")
        let nowhite = availableDestinations.filter {
            normalize($0.name).replacingOccurrences(of: " ", with: "").contains(nowhiteQ)
        }
        return nowhite
    }
    
    private func rank(candidates: [Beacon], for query: String) -> [Beacon] {
        let q = normalize(query)
        return candidates.sorted { a, b in
            let an = normalize(a.name)
            let bn = normalize(b.name)
            // exact > starts-with > contains > length proximity
            if an == q, bn != q { return true }
            if bn == q, an != q { return false }
            if an.hasPrefix(q), !bn.hasPrefix(q) { return true }
            if bn.hasPrefix(q), !an.hasPrefix(q) { return false }
            // shorter edit distance first (very lightweight proxy using length diff)
            let ad = abs(Int(an.count) - Int(q.count))
            let bd = abs(Int(bn.count) - Int(q.count))
            return ad < bd
        }
    }
    
    private func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Destination Selection (by Beacon)
    
    func selectDestination(_ beacon: Beacon, currentPosition: simd_float3, session: ARSession) {
        self.destinationBeacon = beacon
        self.arSession = session
        
        navigationState = .computingPath
        
        guard let path = pathfinder.findPath(from: currentPosition, to: beacon) else {
            navigationState = .failed("Could not find path to destination")
            return
        }
        
        currentPath = path
        currentWaypointIndex = 0
        navigationState = .navigating(currentWaypoint: 0, totalWaypoints: path.waypoints.count)
        
        // Export path as JSON
        pathJSON = path.toJSONString()
        print("📊 Path JSON generated:")
        print(pathJSON ?? "Error generating JSON")
        
        print("🗺️ Navigation started to \(beacon.name)")
        print("   Waypoints: \(path.waypoints.count)")
        print("   Distance: \(String(format: "%.1fm", path.totalDistance))")
        
        startNavigationUpdates()
    }
    
    // MARK: - Navigation Updates
    
    private func startNavigationUpdates() {
        Task {
            while case .navigating = navigationState {
                await updateNavigationProgress()
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }
        }
    }
    
    func updateNavigationProgress() async {
        guard let frame = arSession?.currentFrame,
              let waypoint = currentWaypoint else {
            return
        }
        
        // === Dynamic veil based on scene brightness ===
        if let le = frame.lightEstimate {
            ambientLightIntensity = Float(le.ambientIntensity) // ~0..2000+
            let normalized = min(2.0, Double(ambientLightIntensity) / 1000.0)
            // brighter scene => darker veil (for contrast), clamped 0.5..0.9
            veilOpacity = max(0.5, min(0.9, 0.5 + 0.2 * normalized))
        }
        
        // === Position/heading & distances ===
        let currentPosition3D = CoordinateTransformManager.extractPosition(from: frame.camera)
        let currentHeading = CoordinateTransformManager.extractHeading(from: frame.camera)
        
        let currentPosition2D = simd_float2(currentPosition3D.x, currentPosition3D.z)
        let waypointPosition2D = simd_float2(waypoint.position.x, waypoint.position.z)
        
        let distanceToWaypoint = CoordinateTransformManager.calculateDistance(
            from: currentPosition2D,
            to: waypointPosition2D
        )
        
        let targetHeading = CoordinateTransformManager.calculateHeading(
            from: currentPosition2D,
            to: waypointPosition2D
        )
        
        let headingError = -CoordinateTransformManager.calculateCompassDirection(
            from: currentPosition2D,
            to: waypointPosition2D,
            currentHeading: currentHeading
        )
        
        let remainingDistance = currentPath?.distance(from: currentWaypointIndex) ?? 0
        let totalPathDistance = currentPath?.totalDistance ?? remainingDistance
        let estimatedTime = TimeInterval(remainingDistance / 1.2) // ~1.2 m/s walking
        
        progress = NavigationProgress(
            currentWaypointIndex: currentWaypointIndex,
            distanceToNextWaypoint: distanceToWaypoint,
            totalDistanceRemaining: remainingDistance,
            estimatedTimeRemaining: estimatedTime,
            currentHeading: currentHeading,
            targetHeading: targetHeading,
            headingError: headingError,
            totalPathDistance: totalPathDistance
        )
        
        if CoordinateTransformManager.hasArrived(
            currentPosition: currentPosition2D,
            destination: waypointPosition2D,
            threshold: arrivalThreshold
        ) {
            await arriveAtWaypoint()
        }
        
        if let lastDistance = lastDistanceToWaypoint, lastDistance < distanceToWaypoint {
            if CoordinateTransformManager.shouldRecalculatePath(
                currentPosition: currentPosition2D,
                expectedPosition: waypointPosition2D,
                threshold: 2.0
            ) {
                print("⚠️ User deviated from path")
            }
        }
        
        lastDistanceToWaypoint = distanceToWaypoint
        lastUpdateTime = Date()
    }
    
    // MARK: - Waypoint Arrival
    
    private func arriveAtWaypoint() async {
        guard let path = currentPath else { return }
        
        let waypoint = path.waypoints[currentWaypointIndex]
        print("✅ Arrived at waypoint: \(waypoint.name)")
        
        // Determine if this is the final waypoint
        let isFinal = (currentWaypointIndex >= path.waypoints.count - 1)
        
        // MODIFIED: Handle start position differently
        var message: String
        
        if isFinal {
            message = "Arrived"
        } else {
            // MODIFIED: Check if this is the start position (type .start)
            if waypoint.type == .start {
                // For start position, just say "Proceed to [destination]"
                let nextDestinationName: String? = {
                    let slice = path.waypoints.suffix(from: currentWaypointIndex + 1)
                    if let nextDest = slice.first(where: { $0.type == .destination }) {
                        return nextDest.name.isEmpty ? "next destination" : nextDest.name
                    }
                    if let next = nextWaypoint {
                        return next.name.isEmpty ? "next destination" : next.name
                    }
                    return nil
                }()
                
                if let destinationName = nextDestinationName {
                    message = "Proceed to \(destinationName)"
                } else {
                    message = "Proceed to destination"
                }
            } else {
                // For other waypoints, keep the original logic
                let arrivedAtX: String = waypoint.name.isEmpty ? "Arrived" : "Arrived at \(waypoint.name)"
                
                let nextDestinationName: String? = {
                    let slice = path.waypoints.suffix(from: currentWaypointIndex + 1)
                    if let nextDest = slice.first(where: { $0.type == .destination }) {
                        return nextDest.name.isEmpty ? "next destination" : nextDest.name
                    }
                    if let next = nextWaypoint {
                        return next.name.isEmpty ? "next destination" : next.name
                    }
                    return nil
                }()
                
                if let y = nextDestinationName {
                    message = "\(arrivedAtX), now proceed to \(y)"
                } else {
                    message = arrivedAtX
                }
            }
        }
        
        // Show + speak arrival message
        arrivalMessage = message
        showArrivalMessage = true
        VoiceGuide.shared.speak(message)
        
        if let instruction = waypoint.audioInstruction {
            print("🔊 \(instruction)")
        }
        
        // Hide message after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                self.showArrivalMessage = false
                self.arrivalMessage = nil
            }
        }
        
        // Advance waypoint
        currentWaypointIndex += 1
        
        if currentWaypointIndex >= path.waypoints.count {
            navigationState = .arrived
            print("🎯 Arrived at final destination!")
        } else {
            navigationState = .navigating(
                currentWaypoint: currentWaypointIndex,
                totalWaypoints: path.waypoints.count
            )
            lastDistanceToWaypoint = nil
            print("➡️ Now navigating to: \(path.waypoints[currentWaypointIndex].name)")
        }
    }
    
    // MARK: - Navigation Control
    
    func pauseNavigation() {
        navigationState = .paused
        print("⏸️ Navigation paused")
    }
    
    func resumeNavigation() {
        guard let path = currentPath else { return }
        navigationState = .navigating(
            currentWaypoint: currentWaypointIndex,
            totalWaypoints: path.waypoints.count
        )
        print("▶️ Navigation resumed")
        startNavigationUpdates()
    }
    
    func cancelNavigation() {
        navigationState = .notStarted
        currentPath = nil
        currentWaypointIndex = 0
        progress = nil
        destinationBeacon = nil
        lastDistanceToWaypoint = nil
        pathJSON = nil
        arrivalMessage = nil
        showArrivalMessage = false
        print("❌ Navigation cancelled")
    }
    
    // MARK: - Compass Visualization (used by UI)
    
    func getCompassRotation() -> Float {
        guard let progress = progress else { return 0 }
        return progress.headingError
    }
    
    func getCompassColor() -> String {
        guard let progress = progress else { return "gray" }
        return progress.alignmentQuality.color
    }
    
    // MARK: - Formatting helpers (used by overlays)
    
    func formatDistance(_ distance: Float) -> String {
        if distance < 1.0 {
            return String(format: "%.0fcm", distance * 100)
        } else if distance < 10.0 {
            return String(format: "%.1fm", distance)
        } else {
            return String(format: "%.0fm", distance)
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
