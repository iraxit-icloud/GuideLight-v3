//
//  PathNavigationViewModel.swift
//  FIXED VERSION with all missing types and enums
//

import Foundation
import ARKit
import Combine
import simd
import AVFoundation
import SwiftUI

// MARK: - Navigation State
enum NavigationState: Equatable {
    case idle
    case loadingMap
    case mapLoaded
    case selectingDestination
    case calculatingPath
    case pathCalculated
    case navigating
    case destinationReached
    case error(String)
}

// MARK: - Coordinate Transformation Mode
enum CoordinateTransformMode: String, CaseIterable {
    case none = "None (Original)"
    case invertZ = "Invert Z"
    case invertX = "Invert X"
    case invertXZ = "Invert X & Z (180° rotation)"
    case swapXZ = "Swap X ↔ Z"
    case rotate90CW = "Rotate 90° Clockwise"
    case rotate90CCW = "Rotate 90° Counter-clockwise"
    
    func transform(_ position: simd_float3) -> simd_float3 {
        switch self {
        case .none:
            return position
        case .invertZ:
            return simd_float3(position.x, position.y, -position.z)
        case .invertX:
            return simd_float3(-position.x, position.y, position.z)
        case .invertXZ:
            return simd_float3(-position.x, position.y, -position.z)
        case .swapXZ:
            return simd_float3(position.z, position.y, position.x)
        case .rotate90CW:
            return simd_float3(position.z, position.y, -position.x)
        case .rotate90CCW:
            return simd_float3(-position.z, position.y, position.x)
        }
    }
}

// MARK: - Enhanced Path Navigation View Model with Diagnostics
@MainActor
class PathNavigationViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var navigationState: NavigationState = .idle
    @Published var availableDestinations: [NavigationNode] = []
    @Published var selectedDestination: NavigationNode?
    @Published var currentPath: PathResult?
    @Published var currentPathIndex: Int = 0
    @Published var distanceToNextPoint: Float = 0
    @Published var showDestinationReached: Bool = false
    @Published var statistics: NavigationStatistics?
    @Published var currentDirection: CompassDirection = .north
    @Published var turnInstruction: TurnInstruction = .straight
    @Published var enableAudioGuidance: Bool = false
    @Published var enableHapticFeedback: Bool = true
    
    // NEW: Find My Style Properties
    @Published var arrowRotation: Double = 0
    @Published var directionColor: Color = .gray
    @Published var isAligned: Bool = false
    @Published var distanceText: String = "Calculating..."
    
    // NEW: Diagnostic Properties
    @Published var coordinateTransformMode: CoordinateTransformMode = .none
    @Published var diagnosticInfo: String = ""
    @Published var showDiagnostics: Bool = false
    
    // Relocalization
    @Published var relocalizationState: RelocalizationState = .notStarted
    @Published var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published var isRelocalized: Bool = false
    
    // MARK: - Private Properties
    private var graph: NavigationGraph?
    private var pathfindingEngine: PathfindingEngine?
    private var arSession = ARSession()
    private var cancellables = Set<AnyCancellable>()
    
    private var loadedWorldMap: ARWorldMap?
    private var selectedMap: JSONMap?
    
    private let hapticHelper = HapticFeedbackHelper()
    private let audioHelper = AudioGuidanceHelper()
    private let performanceMonitor = PerformanceMonitor()
    private let logger = NavigationLogger.shared
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    // Position tracking with diagnostics
    private var lastPosition: simd_float3?
    private var lastUpdateTime: Date = Date()
    private var previousTurnInstruction: TurnInstruction = .straight
    private var lastAlignmentHapticTime: Date = .distantPast
    
    // Diagnostic tracking
    private var previousDistance: Float = 0
    private var movementHistory: [(position: simd_float3, distance: Float)] = []
    
    // Thresholds
    private let arrivalThreshold: Float = 0.5
    private let updateFrequency: TimeInterval = 0.1
    private let audioGuidanceDistance: Float = 3.0
    private let alignmentThreshold: Float = 30.0
    private let alignmentHapticInterval: TimeInterval = 2.0
    
    var session: ARSession { arSession }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupARSession()
        logger.log("PathNavigationViewModel initialized with diagnostics")
    }
    
    private func setupARSession() {
        arSession.delegate = self
    }
    
    func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.worldAlignment = .gravity
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        logger.log("AR Session started")
    }
    
    func pauseARSession() {
        arSession.pause()
        logger.log("AR Session paused")
    }
    
    // MARK: - Diagnostic Functions
    
    func testAllTransformations() {
        guard let currentPos = getRawCameraPosition(),
              let target = getNextTarget() else {
            diagnosticInfo = "⚠️ Cannot test: No position or target available"
            return
        }
        
        var output = "🧪 COORDINATE TRANSFORMATION TESTS\n"
        output += String(repeating: "=", count: 60) + "\n\n"
        output += "📍 Current Position (Raw): \(formatVector(currentPos))\n"
        output += "🎯 Target: \(target.name) at \(formatVector(target.position))\n\n"
        
        for mode in CoordinateTransformMode.allCases {
            let transformedPos = mode.transform(currentPos)
            let distance = calculateDistance(from: transformedPos, to: target.position)
            
            output += "[\(mode.rawValue)]\n"
            output += "  Transformed: \(formatVector(transformedPos))\n"
            output += "  Distance: \(String(format: "%.2f", distance))m\n"
            
            if mode == coordinateTransformMode {
                output += "  👉 CURRENTLY ACTIVE\n"
            }
            output += "\n"
        }
        
        output += String(repeating: "=", count: 60) + "\n"
        diagnosticInfo = output
        print(output)
    }
    
    func runMovementDiagnostic() {
        guard movementHistory.count >= 2,
              let target = getNextTarget() else {
            diagnosticInfo = "⚠️ Not enough movement data. Keep moving!"
            return
        }
        
        let recent = movementHistory.suffix(2)
        let prev = recent.first!
        let curr = recent.last!
        
        let results = CoordinateSystemDiagnostic.analyzeMovement(
            previousPosition: prev.position,
            currentPosition: curr.position,
            targetPosition: target.position,
            previousDistance: prev.distance,
            currentDistance: curr.distance
        )
        
        var output = "🚶 MOVEMENT ANALYSIS\n"
        output += String(repeating: "=", count: 60) + "\n\n"
        output += formatDiagnosticResults(results)
        
        diagnosticInfo = output
        print(output)
        
        if let analysis = results["analysis"] as? [String: Any],
           let inverted = analysis["coordinateSystemInverted"] as? String,
           inverted.contains("YES") {
            print("⚠️ COORDINATE SYSTEM INVERSION DETECTED!")
            print("💡 Recommended fix: Try 'Invert X & Z' transformation mode")
        }
    }
    
    // MARK: - Camera Position (with transformation)
    
    private func getRawCameraPosition() -> simd_float3? {
        guard let frame = arSession.currentFrame else { return nil }
        let transform = frame.camera.transform
        return simd_float3(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }
    
    func getCurrentCameraPosition() -> simd_float3? {
        guard let rawPosition = getRawCameraPosition() else { return nil }
        return coordinateTransformMode.transform(rawPosition)
    }
    
    // MARK: - Load Map & Navigation
    
    func loadSelectedMap() {
        navigationState = .loadingMap
        relocalizationState = .notStarted
        isRelocalized = false
        logger.log("Loading selected map with ARWorldMap...")
        
        Task {
            let loadStatus = SimpleJSONMapManager.shared.getMapLoadStatus()
            
            switch loadStatus {
            case .noMapSelected:
                await MainActor.run {
                    self.navigationState = .error(loadStatus.errorMessage ?? "No map selected")
                    self.logger.error("No map selected for navigation")
                }
                
            case .mapSelectedButNoARWorldMap(let mapName):
                await MainActor.run {
                    self.navigationState = .error(loadStatus.errorMessage ?? "Map needs update")
                    self.logger.error("Selected map '\(mapName)' lacks ARWorldMap")
                    if self.enableHapticFeedback {
                        self.hapticHelper.warning()
                    }
                }
                
            case .mapSelectedButFilesMissing(let mapName):
                await MainActor.run {
                    self.navigationState = .error(loadStatus.errorMessage ?? "Map files missing")
                    self.logger.error("Map '\(mapName)' files are missing")
                    if self.enableHapticFeedback {
                        self.hapticHelper.error()
                    }
                }
                
            case .mapSelectedAndReady(let mapName, let fileName):
                logger.log("✅ Map ready: \(mapName), File: \(fileName)")
                
                guard let map = SimpleJSONMapManager.shared.getSelectedMapForNavigation() else {
                    await MainActor.run {
                        self.navigationState = .error("Failed to retrieve map")
                    }
                    return
                }
                
                await MainActor.run {
                    self.selectedMap = map
                }
                
                await self.loadARWorldMap(for: map)
            }
        }
    }
    
    private func loadARWorldMap(for map: JSONMap) async {
        logger.log("Loading ARWorldMap...")
        
        SimpleJSONMapManager.shared.loadSelectedMapForNavigation { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let (map, worldMap)):
                    self.loadedWorldMap = worldMap
                    self.selectedMap = map
                    self.logger.log("✅ ARWorldMap loaded: \(worldMap.anchors.count) anchors")
                    self.startRelocalization(with: map)
                    
                case .failure(let error):
                    self.navigationState = .error("Failed to load ARWorldMap: \(error.localizedDescription)")
                    self.logger.error("ARWorldMap load failed: \(error)")
                    if self.enableHapticFeedback {
                        self.hapticHelper.error()
                    }
                }
            }
        }
    }
    
    private func startRelocalization(with map: JSONMap) {
        guard let worldMap = loadedWorldMap else {
            navigationState = .error("No ARWorldMap available")
            return
        }
        
        logger.log("Starting relocalization...")
        relocalizationState = .scanning
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.worldAlignment = .gravity
        configuration.initialWorldMap = worldMap
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        Task {
            await waitForRelocalization()
            await MainActor.run {
                if self.isRelocalized {
                    self.buildGraphFromMap(map)
                } else {
                    self.navigationState = .error("Relocalization timed out")
                    self.logger.error("Relocalization failed")
                    if self.enableHapticFeedback {
                        self.hapticHelper.error()
                    }
                }
            }
        }
    }
    
    private func waitForRelocalization() async {
        let maxWaitTime: TimeInterval = 30.0
        let checkInterval: TimeInterval = 0.5
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            
            if await MainActor.run(body: { self.isRelocalized }) {
                logger.log("✅ Relocalization successful!")
                return
            }
        }
        
        logger.warning("Relocalization timeout")
    }
    
    private func buildGraphFromMap(_ map: JSONMap) {
        logger.log("Building graph from: \(map.name)")
        
        let graph = NavigationGraph()
        graph.buildFromMapJSON(map.jsonData)
        
        self.graph = graph
        self.pathfindingEngine = PathfindingEngine(graph: graph)
        self.availableDestinations = graph.getAllBeaconNodes()
        self.navigationState = .mapLoaded
        
        self.logger.log("✅ Map loaded, \(self.availableDestinations.count) destinations")
        
        if self.enableHapticFeedback {
            self.hapticHelper.pathCalculated()
        }
    }
    
    func selectDestination(_ destination: NavigationNode) {
        selectedDestination = destination
        navigationState = .selectingDestination
        logger.log("Destination: \(destination.name)")
        
        if enableHapticFeedback {
            hapticHelper.pathCalculated()
        }
    }
    
    func calculatePath() {
        guard let destination = selectedDestination,
              let engine = pathfindingEngine,
              let currentPosition = getCurrentCameraPosition() else {
            navigationState = .error("Cannot calculate path")
            logger.error("Path calculation failed: missing data")
            return
        }
        
        navigationState = .calculatingPath
        logger.log("Calculating path to: \(destination.name)")
        
        Task {
            let pathResult = await Task.detached(priority: .userInitiated) {
                engine.findPath(from: currentPosition, to: destination.id)
            }.value
            
            await MainActor.run {
                if let path = pathResult {
                    self.currentPath = path
                    self.currentPathIndex = 0
                    self.navigationState = .pathCalculated
                    
                    self.statistics = NavigationStatistics(
                        startTime: Date(),
                        totalDistance: path.totalDistance,
                        pathLength: path.path.count
                    )
                    
                    self.logger.log("✅ Path: \(path.path.count) steps, \(String(format: "%.2f", path.totalDistance))m")
                    
                    // ALWAYS print the full path for debugging
                    self.printFullPath(path)
                    
                    if self.enableHapticFeedback {
                        self.hapticHelper.pathCalculated()
                    }
                    
                    NotificationCenter.default.post(name: .navigationStarted, object: nil)
                } else {
                    self.navigationState = .error("No path found")
                    self.logger.error("No path to \(destination.name)")
                    
                    if self.enableHapticFeedback {
                        self.hapticHelper.error()
                    }
                }
            }
        }
    }
    
    func startNavigation() {
        guard currentPath != nil else { return }
        navigationState = .navigating
        currentPathIndex = 0
        showDestinationReached = false
        lastPosition = getCurrentCameraPosition()
        lastUpdateTime = Date()
        movementHistory.removeAll()
        
        logger.log("Navigation started with transform mode: \(coordinateTransformMode.rawValue)")
        
        if enableHapticFeedback {
            hapticHelper.navigationStarted()
        }
        
        if enableAudioGuidance, let target = getNextTarget() {
            speakGuidance("Navigation started. Heading to \(target.name).")
        }
    }
    
    // MARK: - Update Navigation (with diagnostics)
    
    func forceNavigationUpdate() {
        // Force immediate update when transformation changes
        print("\n🔄 FORCING NAVIGATION UPDATE")
        print("   Transformation: \(coordinateTransformMode.rawValue)")
        
        // Print detailed diagnostic
        printRealtimeDiagnostic()
        
        updateNavigation()
    }
    
    func updateNavigation() {
        guard navigationState == .navigating,
              let path = currentPath,
              let currentPosition = getCurrentCameraPosition() else {
            return
        }
        
        performanceMonitor.update()
        
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= updateFrequency else {
            return
        }
        
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        
        if var stats = statistics, let lastPos = lastPosition {
            stats.updateSpeed(currentPosition: currentPosition, lastPosition: lastPos, deltaTime: deltaTime)
            statistics = stats
        }
        
        lastPosition = currentPosition
        
        guard currentPathIndex < path.path.count else {
            reachedDestination()
            return
        }
        
        let targetNode = path.path[currentPathIndex]
        let distance = calculateDistance(from: currentPosition, to: targetNode.position)
        distanceToNextPoint = distance
        
        // Track movement for diagnostics
        movementHistory.append((position: currentPosition, distance: distance))
        if movementHistory.count > 10 {
            movementHistory.removeFirst()
        }
        
        updateFindMyCompass(currentPosition: currentPosition, targetNode: targetNode)
        
        if var stats = statistics {
            let remainingDistance = calculateRemainingDistance(
                from: currentPathIndex,
                path: path.path,
                currentPosition: currentPosition
            )
            stats.updateETA(remainingDistance: remainingDistance)
            statistics = stats
        }
        
        if enableAudioGuidance && distance <= audioGuidanceDistance && audioHelper.shouldProvideGuidance() {
            provideAudioGuidance(targetNode: targetNode, distance: distance)
        }
        
        if distance <= arrivalThreshold {
            waypointReached(targetNode)
        }
        
        previousDistance = distance
    }
    
    private func updateFindMyCompass(currentPosition: simd_float3, targetNode: NavigationNode) {
        updateDistanceText(distanceToNextPoint)
        
        guard let frame = arSession.currentFrame else { return }
        
        let cameraTransform = frame.camera.transform
        let cameraForward3D_raw = -simd_float3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )
        
        // CRITICAL FIX: Transform the camera forward direction too!
        let cameraForward3D = coordinateTransformMode.transform(cameraForward3D_raw)
        
        let cameraForwardHorizontal = simd_float2(cameraForward3D.x, cameraForward3D.z)
        let cameraForwardNorm = simd_normalize(cameraForwardHorizontal)
        let cameraHeading = atan2(cameraForwardNorm.x, cameraForwardNorm.y)
        
        let dx = targetNode.position.x - currentPosition.x
        let dz = targetNode.position.z - currentPosition.z
        let targetDirection = simd_normalize(simd_float2(dx, dz))
        let targetBearing = atan2(targetDirection.x, targetDirection.y)
        
        var relativeAngle = targetBearing - cameraHeading
        while relativeAngle > .pi { relativeAngle -= 2 * .pi }
        while relativeAngle < -.pi { relativeAngle += 2 * .pi }
        
        arrowRotation = Double(relativeAngle * 180 / .pi)
        
        print("🧭 Transform: \(coordinateTransformMode.rawValue) | Distance: \(String(format: "%.2f", distanceToNextPoint))m | Arrow: \(String(format: "%.1f", arrowRotation))°")
        
        let alignmentThresholdRad = alignmentThreshold * .pi / 180
        let wasAligned = isAligned
        isAligned = abs(relativeAngle) < alignmentThresholdRad
        
        updateDirectionColor(alignmentAngle: abs(relativeAngle))
        
        if isAligned && !wasAligned {
            triggerAlignmentHaptic()
        } else if isAligned && Date().timeIntervalSince(lastAlignmentHapticTime) > alignmentHapticInterval {
            triggerAlignmentHaptic()
        }
        
        let direction3D = currentPosition.horizontalDirection(to: targetNode.position)
        let cameraForward3DProjected = simd_float3(cameraForwardNorm.x, 0, cameraForwardNorm.y)
        turnInstruction = TurnInstruction.from(
            currentDirection: cameraForward3DProjected,
            targetDirection: direction3D,
            previousInstruction: previousTurnInstruction
        )
        previousTurnInstruction = turnInstruction
        
        let angle = currentPosition.angle(to: targetNode.position)
        currentDirection = CompassDirection.from(angle: angle)
    }
    
    // MARK: - Helper Functions
    
    private func printFullPath(_ path: PathResult) {
        print(String(repeating: "=", count: 80))
        print("🗺️  FULL NAVIGATION PATH")
        print(String(repeating: "=", count: 80))
        print("Final Destination: \(path.path.last?.name ?? "Unknown")")
        print("Total Distance: \(String(format: "%.2f", path.totalDistance))m")
        print("Total Waypoints: \(path.path.count)")
        print("")
        print("PATH SEQUENCE:")
        print(String(repeating: "-", count: 80))
        
        for (index, node) in path.path.enumerated() {
            let nodeType: String
            switch node.nodeType {
            case .beacon(let category):
                nodeType = "🎯 BEACON (\(category))"
            case .waypoint:
                nodeType = "📍 WAYPOINT"
            case .doorway:
                nodeType = "🚪 DOORWAY"
            }
            
            let position = node.position
            print("\(index + 1). \(nodeType)")
            print("   Name: \(node.name)")
            print("   Position: X:\(String(format: "%.2f", position.x)) Y:\(String(format: "%.2f", position.y)) Z:\(String(format: "%.2f", position.z))")
            
            if index > 0 {
                let prevNode = path.path[index - 1]
                let dist = calculateDistance(from: prevNode.position, to: position)
                print("   Distance from previous: \(String(format: "%.2f", dist))m")
            }
            print("")
        }
        
        print(String(repeating: "=", count: 80))
        print("")
    }
    
    private func calculateDistance(from: simd_float3, to: simd_float3) -> Float {
        let dx = to.x - from.x
        let dz = to.z - from.z
        return sqrt(dx * dx + dz * dz)
    }
    
    private func formatVector(_ vector: simd_float3) -> String {
        return String(format: "X: %.2f, Y: %.2f, Z: %.2f", vector.x, vector.y, vector.z)
    }
    
    private func formatDiagnosticResults(_ results: [String: Any]) -> String {
        var output = ""
        for (key, value) in results.sorted(by: { $0.key < $1.key }) {
            if let nestedDict = value as? [String: Any] {
                output += "\(key):\n"
                for (nestedKey, nestedValue) in nestedDict {
                    output += "  \(nestedKey): \(nestedValue)\n"
                }
            } else {
                output += "\(key): \(value)\n"
            }
        }
        return output
    }
    
    private func calculateRemainingDistance(from index: Int, path: [NavigationNode], currentPosition: simd_float3) -> Float {
        guard index < path.count else { return 0 }
        
        var distance: Float = 0
        distance += calculateDistance(from: currentPosition, to: path[index].position)
        
        for i in index..<(path.count - 1) {
            distance += calculateDistance(from: path[i].position, to: path[i + 1].position)
        }
        
        return distance
    }
    
    private func updateDistanceText(_ distance: Float) {
        if distance < 1.0 {
            distanceText = String(format: "%.0f cm", distance * 100)
        } else if distance < 10.0 {
            distanceText = String(format: "%.1f m", distance)
        } else {
            distanceText = String(format: "%.0f m", distance)
        }
    }
    
    private func updateDirectionColor(alignmentAngle: Float) {
        let maxAngle: Float = .pi
        let normalizedAngle = min(alignmentAngle / maxAngle, 1.0)
        
        if normalizedAngle < 0.17 {
            directionColor = .green
        } else if normalizedAngle < 0.4 {
            directionColor = .yellow
        } else if normalizedAngle < 0.6 {
            directionColor = .orange
        } else {
            directionColor = .red
        }
    }
    
    private func triggerAlignmentHaptic() {
        guard enableHapticFeedback else { return }
        lastAlignmentHapticTime = Date()
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func waypointReached(_ node: NavigationNode) {
        logger.log("Reached: \(node.name)")
        
        if var stats = statistics {
            stats.waypointsReached += 1
            statistics = stats
        }
        
        if enableHapticFeedback {
            hapticHelper.waypointReached()
        }
        
        currentPathIndex += 1
        
        if currentPathIndex >= (currentPath?.path.count ?? 0) {
            reachedDestination()
        } else if enableAudioGuidance, let nextTarget = getNextTarget() {
            speakGuidance("Reached \(node.name). Continue to \(nextTarget.name).")
        }
    }
    
    private func reachedDestination() {
        guard let destination = currentPath?.path.last else { return }
        
        logger.log("🎉 Reached destination: \(destination.name)")
        navigationState = .destinationReached
        showDestinationReached = true
        
        if var stats = statistics {
            stats.endTime = Date()
            statistics = stats
        }
        
        if enableHapticFeedback {
            hapticHelper.destinationReached()
        }
        
        if enableAudioGuidance {
            speakGuidance("You have arrived at \(destination.name).")
        }
        
        NotificationCenter.default.post(name: .navigationEnded, object: nil)
    }
    
    private func provideAudioGuidance(targetNode: NavigationNode, distance: Float) {
        let distanceText = distance < 1.0 ?
            "\(Int(distance * 100)) centimeters" :
            String(format: "%.1f meters", distance)
        
        let directionText = turnInstruction.description
        speakGuidance("\(directionText). \(distanceText) to \(targetNode.name).")
    }
    
    private func speakGuidance(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
        audioHelper.markGuidanceProvided()
    }
    
    func getNextTarget() -> NavigationNode? {
        guard let path = currentPath,
              currentPathIndex < path.path.count else {
            return nil
        }
        return path.path[currentPathIndex]
    }
    
    func getFinalDestination() -> NavigationNode? {
        return currentPath?.path.last
    }
    
    func getDirectionToNextTarget() -> simd_float3? {
        guard let target = getNextTarget(),
              let currentPosition = getCurrentCameraPosition() else {
            return nil
        }
        
        return currentPosition.horizontalDirection(to: target.position)
    }
    
    func resetNavigation() {
        currentPath = nil
        currentPathIndex = 0
        selectedDestination = nil
        showDestinationReached = false
        statistics = nil
        lastPosition = nil
        navigationState = .mapLoaded
        movementHistory.removeAll()
        
        arrowRotation = 0
        directionColor = .gray
        isAligned = false
        distanceText = "Calculating..."
        
        logger.log("Navigation reset")
        
        NotificationCenter.default.post(name: .navigationEnded, object: nil)
    }
    
    func clearAll() {
        graph = nil
        pathfindingEngine = nil
        availableDestinations.removeAll()
        currentPath = nil
        selectedDestination = nil
        currentPathIndex = 0
        navigationState = .idle
        showDestinationReached = false
        statistics = nil
        lastPosition = nil
        loadedWorldMap = nil
        selectedMap = nil
        isRelocalized = false
        relocalizationState = .notStarted
        movementHistory.removeAll()
        
        logger.log("Cleared all")
    }
    
    var currentFPS: Double {
        return performanceMonitor.currentFPS
    }
    
    var isPerformanceGood: Bool {
        return performanceMonitor.isPerformanceGood
    }
}

// MARK: - ARSessionDelegate
extension PathNavigationViewModel: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            let mappingStatus = frame.worldMappingStatus
            self.worldMappingStatus = mappingStatus
            
            if !self.isRelocalized {
                switch mappingStatus {
                case .notAvailable:
                    self.relocalizationState = .notStarted
                case .limited:
                    self.relocalizationState = .limited
                case .extending, .mapped:
                    if !self.isRelocalized {
                        self.isRelocalized = true
                        self.relocalizationState = .mapped
                        self.logger.log("✅ Relocalization: \(mappingStatus)")
                        
                        if self.enableHapticFeedback {
                            self.hapticHelper.pathCalculated()
                        }
                    }
                @unknown default:
                    self.relocalizationState = .scanning
                }
            }
            
            if self.navigationState == .navigating {
                self.updateNavigation()
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.navigationState = .error("AR Session failed: \(error.localizedDescription)")
            self.relocalizationState = .failed(error.localizedDescription)
            self.logger.error("AR failed: \(error.localizedDescription)")
            
            if self.enableHapticFeedback {
                self.hapticHelper.error()
            }
        }
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.logger.warning("AR interrupted")
        }
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.logger.log("AR interruption ended")
            
            if self.isRelocalized && self.loadedWorldMap != nil {
                self.logger.log("Re-checking relocalization...")
                self.isRelocalized = false
            }
        }
    }
}
