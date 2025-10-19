//
//  Room.swift - SIMPLIFIED
//  No boundary coordinates needed
//

import Foundation

// MARK: - Room Model (Simplified)
struct Room: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: RoomType
    let floorSurface: FloorSurface
    let createdAt: Date
    /// NEW: human-authored description stored in map JSON
    var description: String?   // ✅ added

    init(name: String,
         type: RoomType = .general,
         floorSurface: FloorSurface = .carpet,
         description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.floorSurface = floorSurface
        self.createdAt = Date()
        self.description = description
    }
}

// MARK: - Room Type (Extended for Audio Customization)
enum RoomType: String, CaseIterable, Codable {
    case general = "general"
    case bedroom = "bedroom"
    case bathroom = "bathroom"
    case kitchen = "kitchen"
    case living_room = "living_room"
    case dining_room = "dining_room"
    case office = "office"
    case hallway = "hallway"
    case entrance = "entrance"
    case balcony = "balcony"
    case storage = "storage"
    case laundry = "laundry"
    case garage = "garage"
    
    var displayName: String {
        switch self {
        case .general: return "General Room"
        case .bedroom: return "Bedroom"
        case .bathroom: return "Bathroom/Washroom"
        case .kitchen: return "Kitchen"
        case .living_room: return "Living Room"
        case .dining_room: return "Dining Room"
        case .office: return "Office/Study"
        case .hallway: return "Hallway/Corridor"
        case .entrance: return "Entrance/Lobby"
        case .balcony: return "Balcony/Patio"
        case .storage: return "Storage/Closet"
        case .laundry: return "Laundry Room"
        case .garage: return "Garage"
        }
    }
    
    // Audio context hints for navigation
    var audioContext: String {
        switch self {
        case .general: return "room"
        case .bedroom: return "bedroom - listen for bed sounds"
        case .bathroom: return "bathroom - listen for water/tile echoes"
        case .kitchen: return "kitchen - listen for appliances"
        case .living_room: return "living room - open space"
        case .dining_room: return "dining area"
        case .office: return "office - quiet workspace"
        case .hallway: return "hallway - corridor passage"
        case .entrance: return "entrance - doorway area"
        case .balcony: return "balcony - outdoor space"
        case .storage: return "storage area"
        case .laundry: return "laundry room"
        case .garage: return "garage"
        }
    }
}

// MARK: - Floor Surface
enum FloorSurface: String, CaseIterable, Codable {
    case carpet = "carpet"
    case tile = "tile"
    case hardwood = "hardwood"
    case concrete = "concrete"
    case linoleum = "linoleum"
    case marble = "marble"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var surfaceModifier: Double {
        switch self {
        case .carpet: return 1.0
        case .tile: return 0.95
        case .hardwood: return 0.98
        case .concrete: return 1.05
        case .linoleum: return 0.97
        case .marble: return 0.93
        }
    }
    
    // Audio properties for surface type
    var echoLevel: String {
        switch self {
        case .carpet: return "low echo"
        case .tile, .marble: return "high echo"
        case .hardwood: return "medium echo"
        case .concrete: return "high echo"
        case .linoleum: return "low echo"
        }
    }
}
