//
//  Beacon.swift
//  Mapping v2
//
//  Created by Indraneel Rakshit on 9/20/25.
//


import Foundation
import simd

// MARK: - Beacon Model
struct Beacon: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String?
    let position: simd_float3  // X, Y, Z coordinates
    let category: BeaconCategory
    let createdAt: Date
    
    init(name: String, description: String? = nil, position: simd_float3, category: BeaconCategory = .general) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.position = position
        self.category = category
        self.createdAt = Date()
    }
    
    // Distance calculation to another point
    func distance(to point: simd_float3) -> Float {
        return simd_distance(self.position, point)
    }
    
    // Distance to another beacon
    func distance(to beacon: Beacon) -> Float {
        return distance(to: beacon.position)
    }
    
    // Floor-level position (Y=0 for 2D mapping)
    var floorPosition: simd_float2 {
        return simd_float2(position.x, position.z)
    }
}

// MARK: - Beacon Categories
enum BeaconCategory: String, CaseIterable, Codable {
    case general = "general"
    case bathroom = "bathroom"
    case kitchen = "kitchen"
    case bedroom = "bedroom"
    case living = "living"
    case office = "office"
    case entrance = "entrance"
    case exit = "exit"
    case stairs = "stairs"
    case elevator = "elevator"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .bathroom: return "Bathroom"
        case .kitchen: return "Kitchen"
        case .bedroom: return "Bedroom"
        case .living: return "Living Room"
        case .office: return "Office/Study"
        case .entrance: return "Entrance"
        case .exit: return "Exit"
        case .stairs: return "Stairs"
        case .elevator: return "Elevator"
        }
    }
    
    var color: (red: Float, green: Float, blue: Float) {
        switch self {
        case .general: return (0.5, 0.5, 0.5)     // Gray
        case .bathroom: return (0.0, 0.5, 1.0)   // Blue
        case .kitchen: return (1.0, 0.5, 0.0)    // Orange
        case .bedroom: return (0.5, 0.0, 1.0)    // Purple
        case .living: return (0.0, 0.8, 0.0)     // Green
        case .office: return (0.8, 0.8, 0.0)     // Yellow
        case .entrance: return (0.0, 0.8, 0.8)   // Cyan
        case .exit: return (1.0, 0.0, 0.0)       // Red
        case .stairs: return (0.6, 0.3, 0.0)     // Brown
        case .elevator: return (0.4, 0.4, 0.4)   // Dark Gray
        }
    }
}