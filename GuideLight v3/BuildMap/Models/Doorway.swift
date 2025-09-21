//
//  Doorway.swift
//  Mapping v2
//
//  Created by Indraneel Rakshit on 9/20/25.
//


import Foundation
import simd

// MARK: - Doorway Model
struct Doorway: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let startPoint: simd_float3  // First corner of doorway
    let endPoint: simd_float3    // Second corner of doorway
    let fromRoom: String?        // Room name on entry side
    let toRoom: String?          // Room name on exit side
    let doorwayType: DoorwayType
    let createdAt: Date
    
    init(name: String, startPoint: simd_float3, endPoint: simd_float3, 
         fromRoom: String? = nil, toRoom: String? = nil, 
         doorwayType: DoorwayType = .standard) {
        self.id = UUID()
        self.name = name
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.fromRoom = fromRoom
        self.toRoom = toRoom
        self.doorwayType = doorwayType
        self.createdAt = Date()
    }
    
    // Calculated properties
    var width: Float {
        return simd_distance(startPoint, endPoint)
    }
    
    var centerPoint: simd_float3 {
        return (startPoint + endPoint) / 2.0
    }
    
    var floorCenterPoint: simd_float2 {
        let center = centerPoint
        return simd_float2(center.x, center.z)
    }
    
    var floorStartPoint: simd_float2 {
        return simd_float2(startPoint.x, startPoint.z)
    }
    
    var floorEndPoint: simd_float2 {
        return simd_float2(endPoint.x, endPoint.z)
    }
    
    // Direction vector of the doorway (normalized)
    var direction: simd_float3 {
        let diff = endPoint - startPoint
        return simd_normalize(diff)
    }
    
    // Perpendicular direction (for crossing detection)
    var normalDirection: simd_float2 {
        let dir2D = simd_float2(direction.x, direction.z)
        return simd_float2(-dir2D.y, dir2D.x) // 90-degree rotation
    }
    
    // Check if a point is near the doorway line
    func isNearDoorway(_ point: simd_float3, threshold: Float = 0.5) -> Bool {
        let pointOnFloor = simd_float2(point.x, point.z)
        return distanceToLine(pointOnFloor) <= threshold
    }
    
    // Distance from a 2D point to the doorway line
    func distanceToLine(_ point: simd_float2) -> Float {
        let start2D = floorStartPoint
        let end2D = floorEndPoint
        let line = end2D - start2D
        let pointToStart = point - start2D
        
        let lineLength = simd_length(line)
        if lineLength < 0.001 { return simd_distance(point, start2D) }
        
        let projection = simd_dot(pointToStart, line) / (lineLength * lineLength)
        let clampedProjection = max(0, min(1, projection))
        let closestPoint = start2D + clampedProjection * line
        
        return simd_distance(point, closestPoint)
    }
}

// MARK: - Doorway Types
enum DoorwayType: String, CaseIterable, Codable {
    case standard = "standard"
    case wide = "wide"
    case narrow = "narrow"
    case archway = "archway"
    case gate = "gate"
    case sliding = "sliding"
    
    var displayName: String {
        switch self {
        case .standard: return "Standard Door"
        case .wide: return "Wide Opening"
        case .narrow: return "Narrow Passage"
        case .archway: return "Archway"
        case .gate: return "Gate"
        case .sliding: return "Sliding Door"
        }
    }
    
    var color: (red: Float, green: Float, blue: Float) {
        switch self {
        case .standard: return (0.0, 0.8, 1.0)   // Cyan
        case .wide: return (0.0, 1.0, 0.0)       // Green
        case .narrow: return (1.0, 0.5, 0.0)     // Orange
        case .archway: return (0.8, 0.0, 0.8)    // Magenta
        case .gate: return (0.6, 0.6, 0.6)       // Gray
        case .sliding: return (0.0, 0.6, 1.0)    // Light Blue
        }
    }
}