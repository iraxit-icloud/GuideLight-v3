import Foundation
import ARKit
import SceneKit
import Combine
import simd

// MARK: - Build Map View Model
@MainActor
class BuildMapViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isARSessionRunning = false
    @Published var arSessionState: ARSessionState = .notStarted
    @Published var placementMode: PlacementMode = .beacon
    @Published var currentMap: IndoorMap
    @Published var selectedBeaconCategory: BeaconCategory = .general
    @Published var selectedDoorwayType: DoorwayType = .standard
    @Published var showingNameDialog = false
    @Published var tempItemName = ""
    @Published var errorMessage: String?
    @Published var isPlacingDoorway = false
    @Published var firstDoorwayPoint: simd_float3?
    
    // MARK: - Private Properties
    private var arSession = ARSession()
    private var cancellables = Set<AnyCancellable>()
    private var floorHeightOffset: Float = 0.0
    private var pendingBeaconPosition: simd_float3?
    private var pendingDoorwayStartPosition: simd_float3?
    
    // Expose AR session for view access
    var session: ARSession { arSession }
    
    // MARK: - Initialization
    override init() {
        self.currentMap = IndoorMap(name: "New Map")
        super.init()
        setupARSession()
    }
    
    // MARK: - AR Session Management
    private func setupARSession() {
        arSession.delegate = self
        
        // Configure AR session for floor plane detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        arSession.run(configuration)
        arSessionState = .starting
    }
    
    func startARSession() {
        guard !isARSessionRunning else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isARSessionRunning = true
        arSessionState = .running
        
        print("🔥 Started new AR mapping session")
    }
    
    func pauseARSession() {
        arSession.pause()
        isARSessionRunning = false
        arSessionState = .paused
    }
    
    func resetARSession() {
        arSession.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
        floorHeightOffset = 0.0
        firstDoorwayPoint = nil
        isPlacingDoorway = false
        arSessionState = .running
        
        print("🔄 Reset AR mapping session")
    }
    
    // MARK: - Placement Mode Management
    func setPlacementMode(_ mode: PlacementMode) {
        placementMode = mode
        
        // Reset doorway placement if switching away from doorway mode
        if mode != .doorway {
            cancelDoorwayPlacement()
        }
    }
    
    private func cancelDoorwayPlacement() {
        isPlacingDoorway = false
        firstDoorwayPoint = nil
        pendingDoorwayStartPosition = nil
    }
    
    // MARK: - Placement Logic
    func handleTap(at screenPoint: CGPoint, in view: ARSCNView) {
        guard arSessionState == .running else { return }
        
        // Perform raycast to find floor intersection
        guard let raycastResult = performRaycast(from: screenPoint, in: view) else {
            errorMessage = "Could not find floor surface. Try pointing at the floor."
            return
        }
        
        let worldPosition = raycastResult.worldTransform.translation
        
        switch placementMode {
        case .beacon:
            startBeaconPlacement(at: worldPosition)
        case .doorway:
            handleDoorwayPlacement(at: worldPosition)
        }
    }
    
    private func performRaycast(from screenPoint: CGPoint, in view: ARSCNView) -> ARRaycastResult? {
        // First try to hit existing planes
        let raycastQuery = view.raycastQuery(from: screenPoint, allowing: .existingPlaneGeometry, alignment: .horizontal)
        if let query = raycastQuery {
            let results = arSession.raycast(query)
            if let result = results.first {
                return result
            }
        }
        
        // Fallback to estimated plane
        let estimatedQuery = view.raycastQuery(from: screenPoint, allowing: .estimatedPlane, alignment: .horizontal)
        if let query = estimatedQuery {
            let results = arSession.raycast(query)
            return results.first
        }
        
        return nil
    }
    
    // MARK: - Beacon Placement
    private func startBeaconPlacement(at position: simd_float3) {
        pendingBeaconPosition = position
        tempItemName = ""
        showingNameDialog = true
    }
    
    func confirmBeaconPlacement() {
        guard let position = pendingBeaconPosition,
              !tempItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a name for the beacon"
            return
        }
        
        let beacon = Beacon(
            name: tempItemName.trimmingCharacters(in: .whitespacesAndNewlines),
            position: position,
            category: selectedBeaconCategory
        )
        
        addBeacon(beacon)
        
        // Reset state
        pendingBeaconPosition = nil
        tempItemName = ""
        showingNameDialog = false
    }
    
    private func addBeacon(_ beacon: Beacon) {
        var updatedBeacons = currentMap.beacons
        updatedBeacons.append(beacon)
        currentMap = currentMap.updated(beacons: updatedBeacons)
        
        // Notify about beacon addition (console logging)
        print("📍 BEACON ADDED:")
        print("   Name: \(beacon.name)")
        print("   Coordinates: x=\(beacon.position.x), y=\(beacon.position.y), z=\(beacon.position.z)")
        print("   Category: \(beacon.category.rawValue)")
        
        // Send notification (if JSONMapManager is set up to listen)
        NotificationCenter.default.post(
            name: NSNotification.Name("BeaconAdded"),
            object: nil,
            userInfo: [
                "name": beacon.name,
                "coordinates": [
                    "x": Double(beacon.position.x),
                    "y": Double(beacon.position.y),
                    "z": Double(beacon.position.z)
                ],
                "category": beacon.category.rawValue
            ]
        )
    }
    
    // MARK: - Doorway Placement
    private func handleDoorwayPlacement(at position: simd_float3) {
        if !isPlacingDoorway {
            // Start doorway placement - first point
            firstDoorwayPoint = position
            pendingDoorwayStartPosition = position
            isPlacingDoorway = true
        } else {
            // Complete doorway placement - second point
            guard let startPoint = firstDoorwayPoint else { return }
            startDoorwayPlacement(startPoint: startPoint, endPoint: position)
        }
    }
    
    private func startDoorwayPlacement(startPoint: simd_float3, endPoint: simd_float3) {
        // Validate minimum doorway width
        let width = simd_distance(startPoint, endPoint)
        guard width >= 0.3 else { // Minimum 30cm width
            errorMessage = "Doorway too narrow. Minimum width is 30cm."
            cancelDoorwayPlacement()
            return
        }
        
        guard width <= 5.0 else { // Maximum 5m width
            errorMessage = "Doorway too wide. Maximum width is 5m."
            cancelDoorwayPlacement()
            return
        }
        
        pendingDoorwayStartPosition = startPoint
        pendingBeaconPosition = endPoint // Reuse for end position
        tempItemName = ""
        showingNameDialog = true
    }
    
    func confirmDoorwayPlacement() {
        guard let startPoint = pendingDoorwayStartPosition,
              let endPoint = pendingBeaconPosition,
              !tempItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a name for the doorway"
            return
        }
        
        let doorway = Doorway(
            name: tempItemName.trimmingCharacters(in: .whitespacesAndNewlines),
            startPoint: startPoint,
            endPoint: endPoint,
            doorwayType: selectedDoorwayType
        )
        
        addDoorway(doorway)
        
        // Reset state
        cancelDoorwayPlacement()
        pendingBeaconPosition = nil
        tempItemName = ""
        showingNameDialog = false
    }
    
    private func addDoorway(_ doorway: Doorway) {
        var updatedDoorways = currentMap.doorways
        updatedDoorways.append(doorway)
        currentMap = currentMap.updated(doorways: updatedDoorways)
        
        // Notify about doorway addition (console logging)
        let centerPoint = simd_float3(
            (doorway.startPoint.x + doorway.endPoint.x) / 2,
            (doorway.startPoint.y + doorway.endPoint.y) / 2,
            (doorway.startPoint.z + doorway.endPoint.z) / 2
        )
        
        print("🚪 DOORWAY ADDED:")
        print("   Name: \(doorway.name)")
        print("   From: (\(doorway.startPoint.x), \(doorway.startPoint.y), \(doorway.startPoint.z))")
        print("   To: (\(doorway.endPoint.x), \(doorway.endPoint.y), \(doorway.endPoint.z))")
        print("   Center: (\(centerPoint.x), \(centerPoint.y), \(centerPoint.z))")
        print("   Width: \(simd_distance(doorway.startPoint, doorway.endPoint))m")
        print("   Type: \(doorway.doorwayType.rawValue)")
        
        // Send notification (if JSONMapManager is set up to listen)
        NotificationCenter.default.post(
            name: NSNotification.Name("DoorwayAdded"),
            object: nil,
            userInfo: [
                "name": doorway.name,
                "fromRoom": "Room A", // You might want to implement room detection logic
                "toRoom": "Room B",   // You might want to implement room detection logic
                "coordinates": [
                    "x": Double(centerPoint.x),
                    "y": Double(centerPoint.y),
                    "z": Double(centerPoint.z)
                ],
                "startPoint": [
                    "x": Double(doorway.startPoint.x),
                    "y": Double(doorway.startPoint.y),
                    "z": Double(doorway.startPoint.z)
                ],
                "endPoint": [
                    "x": Double(doorway.endPoint.x),
                    "y": Double(doorway.endPoint.y),
                    "z": Double(doorway.endPoint.z)
                ],
                "doorwayType": doorway.doorwayType.rawValue,
                "width": Double(simd_distance(doorway.startPoint, doorway.endPoint))
            ]
        )
    }
    
    // MARK: - Item Management
    func removeBeacon(_ beacon: Beacon) {
        let updatedBeacons = currentMap.beacons.filter { $0.id != beacon.id }
        currentMap = currentMap.updated(beacons: updatedBeacons)
    }
    
    func removeDoorway(_ doorway: Doorway) {
        let updatedDoorways = currentMap.doorways.filter { $0.id != doorway.id }
        currentMap = currentMap.updated(doorways: updatedDoorways)
    }
    
    func cancelPlacement() {
        pendingBeaconPosition = nil
        pendingDoorwayStartPosition = nil
        tempItemName = ""
        showingNameDialog = false
        cancelDoorwayPlacement()
    }
    
    // MARK: - Map Management
    func updateMapName(_ name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        currentMap = IndoorMap(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: currentMap.description,
            beacons: currentMap.beacons,
            doorways: currentMap.doorways
        )
    }
    
    func clearMap() {
        currentMap = IndoorMap(name: currentMap.name)
        cancelDoorwayPlacement()
        
        print("🧹 Cleared map data")
    }
    
    // MARK: - Save/Complete Map Function
    func saveMap() {
        let mapData = generateMapData()
        let mapName = currentMap.name.isEmpty ? "Map \(Date().formatted(.dateTime.day().month().year().hour().minute()))" : currentMap.name
        
        print("💾 MANUAL MAP SAVE:")
        print("   Name: \(mapName)")
        print("   Beacons: \(currentMap.beacons.count)")
        print("   Doorways: \(currentMap.doorways.count)")
        
        // Create JSONMap directly and save using singleton
        let jsonMap = JSONMap(name: mapName, jsonData: mapData, description: "Saved from AR mapping session")
        
        // Use singleton to add map
        SimpleJSONMapManager.shared.addMap(jsonMap)
        
        // FIXED: Clear the current session after saving to remove the "Save as Map" button
        SimpleJSONMapManager.shared.resetCurrentSession()
        
        // Also send notification for consistency
        NotificationCenter.default.post(
            name: NSNotification.Name("MapCompleted"),
            object: nil,
            userInfo: [
                "mapName": mapName,
                "mapData": mapData
            ]
        )
        
        print("✅ Map saved successfully and current session cleared!")
    }
    
    // MARK: - Generate Map Data Function
    private func generateMapData() -> [String: Any] {
        let beaconsData = currentMap.beacons.map { beacon in
            return [
                "id": beacon.id.uuidString,
                "name": beacon.name,
                "category": beacon.category.rawValue,
                "position": [
                    "x": Double(beacon.position.x),
                    "y": Double(beacon.position.y),
                    "z": Double(beacon.position.z)
                ]
            ] as [String: Any]
        }
        
        let doorwaysData = currentMap.doorways.map { doorway in
            return [
                "id": doorway.id.uuidString,
                "name": doorway.name,
                "doorwayType": doorway.doorwayType.rawValue,
                "startPoint": [
                    "x": Double(doorway.startPoint.x),
                    "y": Double(doorway.startPoint.y),
                    "z": Double(doorway.startPoint.z)
                ],
                "endPoint": [
                    "x": Double(doorway.endPoint.x),
                    "y": Double(doorway.endPoint.y),
                    "z": Double(doorway.endPoint.z)
                ],
                "width": Double(simd_distance(doorway.startPoint, doorway.endPoint))
            ] as [String: Any]
        }
        
        return [
            "mapName": currentMap.name,
            "description": currentMap.description ?? "",
            "beacons": beaconsData,
            "doorways": doorwaysData,
            "metadata": [
                "createdDate": Date().timeIntervalSince1970,
                "version": "1.0",
                "totalBeacons": currentMap.beacons.count,
                "totalDoorways": currentMap.doorways.count
            ]
        ]
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Placement Mode
enum PlacementMode: String, CaseIterable {
    case beacon = "beacon"
    case doorway = "doorway"
    
    var displayName: String {
        switch self {
        case .beacon: return "Beacon"
        case .doorway: return "Doorway"
        }
    }
    
    var icon: String {
        switch self {
        case .beacon: return "flag.fill"
        case .doorway: return "rectangle.portrait.and.arrow.right"
        }
    }
}

// MARK: - AR Session State
enum ARSessionState: Equatable {
    case notStarted
    case starting
    case running
    case paused
    case failed(String)
    
    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .paused: return "Paused"
        case .failed(let errorMsg): return "Failed: \(errorMsg)"
        }
    }
    
    static func == (lhs: ARSessionState, rhs: ARSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.starting, .starting),
             (.running, .running),
             (.paused, .paused):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - ARSessionDelegate
extension BuildMapViewModel: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update session state
        Task { @MainActor in
            if self.arSessionState != .running && session.currentFrame != nil {
                self.arSessionState = .running
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Handle plane detection for floor calibration
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor,
               planeAnchor.alignment == .horizontal {
                // Set floor height reference from first horizontal plane
                Task { @MainActor in
                    if self.floorHeightOffset == 0.0 {
                        self.floorHeightOffset = planeAnchor.transform.translation.y
                    }
                }
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.arSessionState = .failed(error.localizedDescription)
            self.errorMessage = "AR Session failed: \(error.localizedDescription)"
        }
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.arSessionState = .paused
        }
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.arSessionState = .running
        }
    }
}

// MARK: - Helper Extensions
extension matrix_float4x4 {
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
}
