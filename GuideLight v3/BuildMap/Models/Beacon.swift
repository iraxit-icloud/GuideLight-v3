//
//  Beacon.swift - SIMPLIFIED
//  Essential fields during capture, optional fields editable later
//

import Foundation
import simd

// MARK: - Beacon Model (Simplified)
struct Beacon: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let position: simd_float3
    let category: BeaconCategory
    let roomId: String
    let timestamp: Date
    
    // Optional fields - editable later
    var description: String?
    var audioLandmark: String?
    var isAccessible: Bool
    var accessibilityNotes: String?
    var physicalProperties: PhysicalProperties?
    
    init(name: String, position: simd_float3, category: BeaconCategory = .destination,
         roomId: String, description: String? = nil, audioLandmark: String? = nil,
         isAccessible: Bool = true, accessibilityNotes: String? = nil,
         physicalProperties: PhysicalProperties? = nil) {
        self.id = UUID()
        self.name = name
        self.position = position
        self.category = category
        self.roomId = roomId
        self.timestamp = Date()
        self.description = description
        self.audioLandmark = audioLandmark
        self.isAccessible = isAccessible
        self.accessibilityNotes = accessibilityNotes
        self.physicalProperties = physicalProperties
    }
    
    func distance(to point: simd_float3) -> Float {
        return simd_distance(self.position, point)
    }
    
    func distance(to beacon: Beacon) -> Float {
        return distance(to: beacon.position)
    }
    
    var floorPosition: simd_float2 {
        return simd_float2(position.x, position.z)
    }
    
    var isObstacle: Bool {
        return physicalProperties?.isObstacle ?? false
    }
}

// MARK: - Physical Properties (for obstacle beacons)
struct PhysicalProperties: Codable, Equatable {
    let isObstacle: Bool
    let boundingBox: BoundingBox
    let avoidanceRadius: Float
    let canRouteAround: Bool
    let obstacleType: ObstacleType
    
    init(isObstacle: Bool = true, boundingBox: BoundingBox,
         avoidanceRadius: Float, canRouteAround: Bool = true,
         obstacleType: ObstacleType = .furniture) {
        self.isObstacle = isObstacle
        self.boundingBox = boundingBox
        self.avoidanceRadius = avoidanceRadius
        self.canRouteAround = canRouteAround
        self.obstacleType = obstacleType
    }
}

struct BoundingBox: Codable, Equatable {
    let width: Float
    let depth: Float
    let height: Float
}

enum ObstacleType: String, Codable {
    case furniture = "furniture"
    case equipment = "equipment"
    case fixture = "fixture"
    case temporary = "temporary"
}

// MARK: - Beacon Categories
enum BeaconCategory: String, CaseIterable, Codable {
    case destination = "destination"
    case landmark = "landmark"
    case furniture = "furniture"
    case appliance = "appliance"
    case fixture = "fixture"
    
    var displayName: String {
        switch self {
        case .destination: return "Destination"
        case .landmark: return "Landmark"
        case .furniture: return "Furniture"
        case .appliance: return "Appliance"
        case .fixture: return "Fixture"
        }
    }
    
    var color: (red: Float, green: Float, blue: Float) {
        switch self {
        case .destination: return (0.0, 0.8, 0.0)
        case .landmark: return (0.0, 0.5, 1.0)
        case .furniture: return (0.6, 0.4, 0.2)
        case .appliance: return (0.8, 0.8, 0.0)
        case .fixture: return (0.5, 0.5, 0.5)
        }
    }
}

// MARK: - Waypoint Model
struct Waypoint: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let coordinates: simd_float3
    let roomId: String
    let waypointType: WaypointType
    let isAccessible: Bool
    
    // Optional - editable later
    var description: String?
    var audioLandmark: String?
    
    init(name: String, coordinates: simd_float3, roomId: String,
         waypointType: WaypointType = .navigation, isAccessible: Bool = true,
         description: String? = nil, audioLandmark: String? = nil) {
        self.id = UUID()
        self.name = name
        self.coordinates = coordinates
        self.roomId = roomId
        self.waypointType = waypointType
        self.isAccessible = isAccessible
        self.description = description
        self.audioLandmark = audioLandmark
    }
    
    enum WaypointType: String, Codable {
        case navigation = "navigation"
        case safety = "safety"
        case accessibility = "accessibility"
    }
}
