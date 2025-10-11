//
//  MapPackage.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/9/25.
//


//
//  MapStorageManager.swift
//  ARWorldMap Storage and Retrieval
//
//  Handles saving and loading ARWorldMaps for coordinate frame alignment
//

import Foundation
import ARKit

// MARK: - Map Package Structure
struct MapPackage: Codable {
    let metadata: MapMetadata
    let jsonData: [String: Any]
    let worldMapFilename: String // Separate file for binary data
    
    struct MapMetadata: Codable {
        let name: String
        let createdAt: Date
        let version: String
        let hasWorldMap: Bool
    }
    
    enum CodingKeys: String, CodingKey {
        case metadata
        case worldMapFilename
    }
    
    // Custom encoding/decoding for jsonData
    init(metadata: MapMetadata, jsonData: [String: Any], worldMapFilename: String) {
        self.metadata = metadata
        self.jsonData = jsonData
        self.worldMapFilename = worldMapFilename
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decode(MapMetadata.self, forKey: .metadata)
        worldMapFilename = try container.decode(String.self, forKey: .worldMapFilename)
        
        // Load JSON data from companion file
        let jsonFilename = worldMapFilename.replacingOccurrences(of: ".worldmap", with: ".json")
        if let jsonURL = MapStorageManager.getDocumentsDirectory()?.appendingPathComponent(jsonFilename),
           let jsonDataRaw = try? Data(contentsOf: jsonURL),
           let json = try? JSONSerialization.jsonObject(with: jsonDataRaw) as? [String: Any] {
            jsonData = json
        } else {
            jsonData = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(worldMapFilename, forKey: .worldMapFilename)
    }
}

// MARK: - Map Storage Manager
class MapStorageManager {
    
    static let shared = MapStorageManager()
    private let logger = NavigationLogger.shared
    
    private init() {}
    
    // MARK: - Save Map Package
    /// Saves a complete map package including ARWorldMap and beacon data
    func saveMapPackage(
        name: String,
        jsonData: [String: Any],
        worldMap: ARWorldMap,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        logger.log("Saving map package: \(name)")
        
        Task {
            do {
                guard let documentsDir = Self.getDocumentsDirectory() else {
                    throw MapStorageError.invalidDirectory
                }
                
                // Create unique filenames
                let timestamp = Int(Date().timeIntervalSince1970)
                let worldMapFilename = "\(name)_\(timestamp).worldmap"
                let jsonFilename = "\(name)_\(timestamp).json"
                let metadataFilename = "\(name)_\(timestamp).metadata"
                
                let worldMapURL = documentsDir.appendingPathComponent(worldMapFilename)
                let jsonURL = documentsDir.appendingPathComponent(jsonFilename)
                let metadataURL = documentsDir.appendingPathComponent(metadataFilename)
                
                // 1. Save ARWorldMap (binary data)
                logger.log("Serializing ARWorldMap...")
                let worldMapData = try NSKeyedArchiver.archivedData(
                    withRootObject: worldMap,
                    requiringSecureCoding: true
                )
                try worldMapData.write(to: worldMapURL)
                logger.log("ARWorldMap saved: \(worldMapData.count) bytes")
                
                // 2. Save JSON data
                logger.log("Saving map JSON...")
                let jsonDataRaw = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
                try jsonDataRaw.write(to: jsonURL)
                logger.log("Map JSON saved")
                
                // 3. Save metadata
                let metadata = MapPackage.MapMetadata(
                    name: name,
                    createdAt: Date(),
                    version: "1.0",
                    hasWorldMap: true
                )
                
                let package = MapPackage(
                    metadata: metadata,
                    jsonData: jsonData,
                    worldMapFilename: worldMapFilename
                )
                
                let metadataData = try JSONEncoder().encode(package)
                try metadataData.write(to: metadataURL)
                logger.log("Metadata saved")
                
                logger.log("✅ Map package saved successfully at: \(metadataURL)")
                completion(.success(metadataURL))
                
            } catch {
                logger.error("Failed to save map package: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Load Map Package
    /// Loads a complete map package
    func loadMapPackage(from url: URL) -> Result<(jsonData: [String: Any], worldMap: ARWorldMap), Error> {
        logger.log("Loading map package from: \(url.lastPathComponent)")
        
        do {
            // 1. Load metadata
            let metadataData = try Data(contentsOf: url)
            let package = try JSONDecoder().decode(MapPackage.self, from: metadataData)
            
            guard let documentsDir = Self.getDocumentsDirectory() else {
                throw MapStorageError.invalidDirectory
            }
            
            // 2. Load ARWorldMap
            let worldMapURL = documentsDir.appendingPathComponent(package.worldMapFilename)
            logger.log("Loading ARWorldMap from: \(worldMapURL.lastPathComponent)")
            
            let worldMapData = try Data(contentsOf: worldMapURL)
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: worldMapData
            ) else {
                throw MapStorageError.invalidWorldMap
            }
            
            logger.log("✅ ARWorldMap loaded: \(worldMapData.count) bytes")
            logger.log("   Anchors: \(worldMap.anchors.count)")
            
            // 3. Return package data
            logger.log("✅ Map package loaded successfully")
            return .success((jsonData: package.jsonData, worldMap: worldMap))
            
        } catch {
            logger.error("Failed to load map package: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Get Current ARWorldMap
    /// Captures the current ARWorldMap from an AR session
    func getCurrentWorldMap(
        from session: ARSession,
        completion: @escaping (Result<ARWorldMap, Error>) -> Void
    ) {
        logger.log("Capturing current ARWorldMap...")
        
        session.getCurrentWorldMap { worldMap, error in
            if let error = error {
                self.logger.error("Failed to capture ARWorldMap: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let worldMap = worldMap else {
                self.logger.error("ARWorldMap is nil")
                completion(.failure(MapStorageError.invalidWorldMap))
                return
            }
            
            self.logger.log("✅ ARWorldMap captured successfully")
            self.logger.log("   Anchors: \(worldMap.anchors.count)")
            self.logger.log("   Raw feature points: \(worldMap.rawFeaturePoints.points.count)")
            
            completion(.success(worldMap))
        }
    }
    
    // MARK: - List Available Maps
    /// Lists all available map packages
    func listAvailableMaps() -> [MapPackage.MapMetadata] {
        guard let documentsDir = Self.getDocumentsDirectory() else {
            return []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            let metadataFiles = files.filter { $0.pathExtension == "metadata" }
            
            var maps: [MapPackage.MapMetadata] = []
            
            for file in metadataFiles {
                if let data = try? Data(contentsOf: file),
                   let package = try? JSONDecoder().decode(MapPackage.self, from: data) {
                    maps.append(package.metadata)
                }
            }
            
            return maps.sorted { $0.createdAt > $1.createdAt }
            
        } catch {
            logger.error("Failed to list maps: \(error)")
            return []
        }
    }
    
    // MARK: - Delete Map Package
    /// Deletes a map package and all associated files
    func deleteMapPackage(metadataURL: URL) throws {
        logger.log("Deleting map package: \(metadataURL.lastPathComponent)")
        
        // Load metadata to find associated files
        let metadataData = try Data(contentsOf: metadataURL)
        let package = try JSONDecoder().decode(MapPackage.self, from: metadataData)
        
        guard let documentsDir = Self.getDocumentsDirectory() else {
            throw MapStorageError.invalidDirectory
        }
        
        // Delete world map file
        let worldMapURL = documentsDir.appendingPathComponent(package.worldMapFilename)
        try? FileManager.default.removeItem(at: worldMapURL)
        
        // Delete JSON file
        let jsonFilename = package.worldMapFilename.replacingOccurrences(of: ".worldmap", with: ".json")
        let jsonURL = documentsDir.appendingPathComponent(jsonFilename)
        try? FileManager.default.removeItem(at: jsonURL)
        
        // Delete metadata file
        try FileManager.default.removeItem(at: metadataURL)
        
        logger.log("✅ Map package deleted")
    }
    
    // MARK: - Helper Methods
    static func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    func getMapPackageSize(metadataURL: URL) -> Int64 {
        do {
            let metadataData = try Data(contentsOf: metadataURL)
            let package = try JSONDecoder().decode(MapPackage.self, from: metadataData)
            
            guard let documentsDir = Self.getDocumentsDirectory() else {
                return 0
            }
            
            var totalSize: Int64 = 0
            
            // World map size
            let worldMapURL = documentsDir.appendingPathComponent(package.worldMapFilename)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: worldMapURL.path) {
                totalSize += attrs[.size] as? Int64 ?? 0
            }
            
            // JSON size
            let jsonFilename = package.worldMapFilename.replacingOccurrences(of: ".worldmap", with: ".json")
            let jsonURL = documentsDir.appendingPathComponent(jsonFilename)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: jsonURL.path) {
                totalSize += attrs[.size] as? Int64 ?? 0
            }
            
            // Metadata size
            if let attrs = try? FileManager.default.attributesOfItem(atPath: metadataURL.path) {
                totalSize += attrs[.size] as? Int64 ?? 0
            }
            
            return totalSize
            
        } catch {
            return 0
        }
    }
}

// MARK: - Errors
enum MapStorageError: LocalizedError {
    case invalidDirectory
    case invalidWorldMap
    case saveFailed(String)
    case loadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidDirectory:
            return "Could not access documents directory"
        case .invalidWorldMap:
            return "Invalid or corrupted ARWorldMap"
        case .saveFailed(let reason):
            return "Failed to save map: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load map: \(reason)"
        }
    }
}

// MARK: - File Size Formatter Extension
extension Int64 {
    func formattedFileSize() -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: self)
    }
}