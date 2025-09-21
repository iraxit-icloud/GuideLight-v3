//
//  IndoorMap.swift
//  Mapping v2
//
//  Created by Indraneel Rakshit on 9/20/25.
//


import Foundation
import simd

// MARK: - Indoor Map Model
struct IndoorMap: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let beacons: [Beacon]
    let doorways: [Doorway]
    let metadata: MapMetadata
    let createdAt: Date
    let updatedAt: Date
    
    init(name: String, description: String? = nil, beacons: [Beacon] = [], doorways: [Doorway] = []) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.beacons = beacons
        self.doorways = doorways
        self.metadata = MapMetadata()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Update map with new beacons/doorways
    func updated(beacons: [Beacon]? = nil, doorways: [Doorway]? = nil) -> IndoorMap {
        return IndoorMap(
            id: self.id,
            name: self.name,
            description: self.description,
            beacons: beacons ?? self.beacons,
            doorways: doorways ?? self.doorways,
            metadata: self.metadata.updated(),
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
    
    private init(id: UUID, name: String, description: String?, beacons: [Beacon], 
                doorways: [Doorway], metadata: MapMetadata, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.description = description
        self.beacons = beacons
        self.doorways = doorways
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Map bounds calculation
    var bounds: MapBounds {
        var minX: Float = 0, maxX: Float = 0
        var minZ: Float = 0, maxZ: Float = 0
        
        let allPoints = beacons.map { $0.position } + 
                       doorways.flatMap { [$0.startPoint, $0.endPoint] }
        
        if !allPoints.isEmpty {
            minX = allPoints.map { $0.x }.min() ?? 0
            maxX = allPoints.map { $0.x }.max() ?? 0
            minZ = allPoints.map { $0.z }.min() ?? 0
            maxZ = allPoints.map { $0.z }.max() ?? 0
        }
        
        return MapBounds(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ)
    }
    
    // Find beacon by name
    func beacon(named name: String) -> Beacon? {
        return beacons.first { $0.name.lowercased() == name.lowercased() }
    }
    
    // Find nearest beacon to a position
    func nearestBeacon(to position: simd_float3, maxDistance: Float = Float.infinity) -> Beacon? {
        return beacons
            .filter { $0.distance(to: position) <= maxDistance }
            .min { $0.distance(to: position) < $1.distance(to: position) }
    }
    
    // Find doorways near a position
    func nearbyDoorways(to position: simd_float3, threshold: Float = 1.0) -> [Doorway] {
        return doorways.filter { $0.isNearDoorway(position, threshold: threshold) }
    }
    
    // Calculate distance matrix between all beacons
    func distanceMatrix() -> [[Float]] {
        let count = beacons.count
        var matrix = Array(repeating: Array(repeating: Float.infinity, count: count), count: count)
        
        for i in 0..<count {
            matrix[i][i] = 0
            for j in (i+1)..<count {
                let distance = beacons[i].distance(to: beacons[j])
                matrix[i][j] = distance
                matrix[j][i] = distance
            }
        }
        
        return matrix
    }
}

// MARK: - Map Metadata
struct MapMetadata: Codable {
    let version: String
    let coordinateSystem: CoordinateSystem
    let units: String
    let calibrationData: CalibrationData?
    
    init(coordinateSystem: CoordinateSystem = .arkit, units: String = "meters") {
        self.version = "1.0"
        self.coordinateSystem = coordinateSystem
        self.units = units
        self.calibrationData = nil
    }
    
    func updated() -> MapMetadata {
        return MapMetadata(coordinateSystem: self.coordinateSystem, units: self.units)
    }
}

// MARK: - Coordinate System
enum CoordinateSystem: String, Codable {
    case arkit = "arkit"
    case local = "local"
    case utm = "utm"
}

// MARK: - Calibration Data
struct CalibrationData: Codable {
    let floorHeight: Float
    let magneticDeclination: Float?
    let referencePoints: [ReferencePoint]
}

struct ReferencePoint: Codable {
    let name: String
    let position: simd_float3
    let realWorldCoordinate: simd_float3?
}

// MARK: - Map Bounds
struct MapBounds {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
    
    var width: Float { return maxX - minX }
    var depth: Float { return maxZ - minZ }
    var center: simd_float2 { return simd_float2((minX + maxX) / 2, (minZ + maxZ) / 2) }
}

// MARK: - File Management Extensions
extension IndoorMap {
    // Generate filename for saving
    var filename: String {
        let cleanName = name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
        return "\(cleanName)_\(id.uuidString.prefix(8)).json"
    }
    
    // Convert to JSON data
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    // Create from JSON data
    static func fromJSONData(_ data: Data) throws -> IndoorMap {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(IndoorMap.self, from: data)
    }
}