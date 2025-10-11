//
//  PathNavigationViewModel.swift (ENHANCED FOR FIND MY STYLE)
//  Navigation State Management with Find My Experience
//  FIXED: Now uses X,Z horizontal plane (ignoring Y vertical height)
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

// MARK: - Enhanced Path Navigation View Model
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
    @Published var arrowRotation: Double = 0 // Rotation angle for directional arrow
    @Published var directionColor: Color = .gray // Color feedback (green when aligned)
    @Published var isAligned: Bool = false // True when pointing at target
    @Published var distanceText: String = "Calculating..." // Formatted distance text
    
    // Relocalization
    @Published var relocalizationState: RelocalizationState = .notStarted
    @Published var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published var isRelocalized: Bool = false
    
    // MARK: - Private Properties
    private var graph: NavigationGraph?
    private var pathfindingEngine: PathfindingEngine?
    private var arSession = ARSession()
    private var cancellables = Set<AnyCancellable>()
    
    // ARWorldMap for coordinate alignment
    private var loadedWorldMap: ARWorldMap?
    private var selectedMap: JSONMap?
    
    // Helpers
    private let hapticHelper = HapticFeedbackHelper()
    private let audioHelper = AudioGuidanceHelper()
    private let performanceMonitor = PerformanceMonitor()
    private let logger = NavigationLogger.shared
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    // Position tracking
    private var lastPosition: simd_float3?
    private var lastUpdateTime: Date = Date()
    private var previousTurnInstruction: TurnInstruction = .straight
    
    // NEW: Haptic tracking for Find My style feedback
    private var lastAlignmentHapticTime: Date = .distantPast
    private let alignmentHapticInterval: TimeInterval = 2.0 // Haptic every 2 seconds when aligned
    
    // Thresholds
    private let arrivalThreshold: Float = 0.5 // meters
    private let updateFrequency: TimeInterval = 0.1 // 10 Hz updates for smooth compass
    private let audioGuidanceDistance: Float = 3.0 // meters
    private let alignmentThreshold: Float = 30.0 // degrees (within 30° = aligned)
    
    var session: ARSession { arSession }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupARSession()
        logger.log("PathNavigationViewModel initialized")
    }
    
    // MARK: - AR Session Setup
    private func setupARSession() {
        arSession.delegate = self
    }
    
    func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.worldAlignment = .gravityAndHeading // Important for compass
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        logger.log("AR Session started with gravity and heading alignment")
    }
    
    func pauseARSession() {
        arSession.pause()
        logger.log("AR Session paused")
    }
    
    // MARK: - Load Map with ARWorldMap
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
        configuration.worldAlignment = .gravityAndHeading // Important!
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
    
    // MARK: - Select Destination
    func selectDestination(_ destination: NavigationNode) {
        selectedDestination = destination
        navigationState = .selectingDestination
        logger.log("Destination: \(destination.name)")
        
        if enableHapticFeedback {
            hapticHelper.pathCalculated()
        }
    }
    
    // MARK: - Calculate Path
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
                    
                    path.printJSON()
                    
                    self.logger.log("✅ Path: \(path.path.count) steps, \(String(format: "%.2f", path.totalDistance))m")
                    
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
    
    // MARK: - Start Navigation
    func startNavigation() {
        guard currentPath != nil else { return }
        navigationState = .navigating
        currentPathIndex = 0
        showDestinationReached = false
        lastPosition = getCurrentCameraPosition()
        lastUpdateTime = Date()
        
        logger.log("Navigation started")
        
        if enableHapticFeedback {
            hapticHelper.navigationStarted()
        }
        
        if enableAudioGuidance, let target = getNextTarget() {
            speakGuidance("Navigation started. Heading to \(target.name).")
        }
    }
    
    // MARK: - Update Navigation (FIXED FOR X,Z HORIZONTAL PLANE)
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
        
        // Update statistics
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
        let distance = currentPosition.distance(to: targetNode.position)
        distanceToNextPoint = distance
        
        // NEW: Update Find My style compass properties
        updateFindMyCompass(currentPosition: currentPosition, targetNode: targetNode)
        
        // Update statistics
        if var stats = statistics {
            let remainingDistance = calculateRemainingDistance(
                from: currentPathIndex,
                path: path.path,
                currentPosition: currentPosition
            )
            stats.updateETA(remainingDistance: remainingDistance)
            statistics = stats
        }
        
        // Audio guidance
        if enableAudioGuidance && distance <= audioGuidanceDistance && audioHelper.shouldProvideGuidance() {
            provideAudioGuidance(targetNode: targetNode, distance: distance)
        }
        
        // Check arrival
        if distance <= arrivalThreshold {
            waypointReached(targetNode)
        }
    }
    
    // MARK: - FIXED: Update Find My Compass (X,Z Horizontal Plane)
    private func updateFindMyCompass(currentPosition: simd_float3, targetNode: NavigationNode) {
        
        // 1. Update distance text
        updateDistanceText(distanceToNextPoint)
        
        // 2. Get camera direction from AR frame
        guard let frame = arSession.currentFrame else { return }
        
        // Get camera forward direction (projected to horizontal X,Z plane)
        let cameraTransform = frame.camera.transform
        let cameraForward3D = -simd_float3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )
        
        // Project to horizontal plane (X,Z) - Y is vertical, ignore it
        let cameraForward2D = simd_float2(cameraForward3D.x, cameraForward3D.z)
        let cameraHeading = atan2(cameraForward2D.x, cameraForward2D.y)
        
        // 3. Calculate bearing to target (horizontal X,Z plane)
        let targetDirection2D = simd_float2(
            targetNode.position.x - currentPosition.x,
            targetNode.position.z - currentPosition.z
        )
        let targetBearing = atan2(targetDirection2D.x, targetDirection2D.y)
        
        // 4. Calculate relative angle (how much to rotate arrow)
        var relativeAngle = targetBearing - cameraHeading
        
        // Normalize to -π to π
        while relativeAngle > .pi { relativeAngle -= 2 * .pi }
        while relativeAngle < -.pi { relativeAngle += 2 * .pi }
        
        // Convert to degrees for UI rotation
        arrowRotation = Double(relativeAngle * 180 / .pi)
        
        // 5. Check alignment (within threshold degrees)
        let alignmentThresholdRad = alignmentThreshold * .pi / 180
        let wasAligned = isAligned
        isAligned = abs(relativeAngle) < alignmentThresholdRad
        
        // 6. Update color based on alignment
        updateDirectionColor(alignmentAngle: abs(relativeAngle))
        
        // 7. Trigger haptic if newly aligned
        if isAligned && !wasAligned {
            triggerAlignmentHaptic()
        } else if isAligned && Date().timeIntervalSince(lastAlignmentHapticTime) > alignmentHapticInterval {
            triggerAlignmentHaptic()
        }
        
        // 8. Update turn instruction (with hysteresis) using horizontal plane direction
        let direction3D = currentPosition.horizontalDirection(to: targetNode.position)
        let cameraForward3DProjected = simd_float3(cameraForward2D.x, 0, cameraForward2D.y)
        turnInstruction = TurnInstruction.from(
            currentDirection: cameraForward3DProjected,
            targetDirection: direction3D,
            previousInstruction: previousTurnInstruction
        )
        previousTurnInstruction = turnInstruction
        
        // 9. Update compass direction
        let angle = currentPosition.angle(to: targetNode.position)
        currentDirection = CompassDirection.from(angle: angle)
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
        // Green when aligned, yellow when somewhat aligned, orange/red when off
        let maxAngle: Float = .pi // 180 degrees
        let normalizedAngle = min(alignmentAngle / maxAngle, 1.0)
        
        if normalizedAngle < 0.17 { // < 30 degrees
            directionColor = .green
        } else if normalizedAngle < 0.4 { // < 72 degrees
            directionColor = .yellow
        } else if normalizedAngle < 0.6 { // < 108 degrees
            directionColor = .orange
        } else {
            directionColor = .red
        }
    }
    
    private func triggerAlignmentHaptic() {
        guard enableHapticFeedback else { return }
        lastAlignmentHapticTime = Date()
        
        // Light tap when aligned
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - Waypoint Reached
    private func waypointReached(_ node: NavigationNode) {
        logger.log("Reached: \(node.name) (\(currentPathIndex + 1)/\(currentPath?.path.count ?? 0))")
        
        if enableHapticFeedback {
            hapticHelper.waypointReached()
        }
        
        if var stats = statistics {
            stats.waypointsReached += 1
            statistics = stats
        }
        
        NotificationCenter.default.post(
            name: .waypointReached,
            object: nil,
            userInfo: ["nodeName": node.name, "index": currentPathIndex]
        )
        
        currentPathIndex += 1
        
        if enableAudioGuidance, let nextTarget = getNextTarget() {
            speakGuidance("Reached \(node.name). Next: \(nextTarget.name).")
        }
        
        if currentPathIndex >= currentPath?.path.count ?? 0 {
            reachedDestination()
        }
    }
    
    private func reachedDestination() {
        logger.log("Destination reached!")
        
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
            speakGuidance("You've arrived at \(selectedDestination?.name ?? "your destination")!")
        }
        
        NotificationCenter.default.post(name: .destinationReached, object: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.resetNavigation()
        }
    }
    
    // MARK: - Audio Guidance
    private func provideAudioGuidance(targetNode: NavigationNode, distance: Float) {
        let guidance = audioHelper.generateGuidance(
            distance: distance,
            targetName: targetNode.name,
            direction: currentDirection,
            turn: turnInstruction
        )
        
        speakGuidance(guidance)
        audioHelper.markGuidanceProvided()
    }
    
    private func speakGuidance(_ text: String) {
        guard !speechSynthesizer.isSpeaking else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speechSynthesizer.speak(utterance)
        
        logger.debug("Audio: \(text)")
    }
    
    // MARK: - Helper Methods
    func getCurrentCameraPosition() -> simd_float3? {
        guard let frame = arSession.currentFrame else { return nil }
        return frame.camera.position
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
    
    private func calculateRemainingDistance(from index: Int, path: [NavigationNode], currentPosition: simd_float3) -> Float {
        guard index < path.count else { return 0 }
        
        var distance: Float = 0
        distance += currentPosition.distance(to: path[index].position)
        
        for i in index..<(path.count - 1) {
            distance += path[i].position.distance(to: path[i + 1].position)
        }
        
        return distance
    }
    
    // MARK: - Reset Navigation
    func resetNavigation() {
        currentPath = nil
        currentPathIndex = 0
        selectedDestination = nil
        showDestinationReached = false
        statistics = nil
        lastPosition = nil
        navigationState = .mapLoaded
        
        // Reset Find My properties
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
