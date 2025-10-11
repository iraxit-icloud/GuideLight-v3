//
//  SimpleJSONMapManager+Navigation.swift
//  Extension with detailed map status checking
//

import Foundation
import ARKit

// MARK: - Map Load Status
enum MapLoadStatus {
    case noMapSelected
    case mapSelectedButNoARWorldMap(mapName: String)
    case mapSelectedAndReady(mapName: String, fileName: String)
    case mapSelectedButFilesMissing(mapName: String)
    
    var canNavigate: Bool {
        if case .mapSelectedAndReady = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        switch self {
        case .noMapSelected:
            return "No map selected. Please select a map in Settings."
        case .mapSelectedButNoARWorldMap(let mapName):
            return "The map '\(mapName)' is an old-style map without spatial data.\n\nPlease recreate this map to use it for navigation."
        case .mapSelectedButFilesMissing(let mapName):
            return "The map '\(mapName)' files are missing or corrupted.\n\nPlease recreate this map."
        case .mapSelectedAndReady:
            return nil
        }
    }
}

extension SimpleJSONMapManager {
    
    // MARK: - Get Map Load Status (PRIMARY METHOD)
    /// Returns detailed status about whether the selected map can be used for navigation
    func getMapLoadStatus() -> MapLoadStatus {
        // Check if any map is selected
        guard let selectedMap = getSelectedMapForNavigation() else {
            print("❌ MAP LOAD STATUS: No map selected")
            return .noMapSelected
        }
        
        let mapName = selectedMap.name
        print("📍 MAP LOAD STATUS: Map selected = \(mapName)")
        
        // Check if the map has ARWorldMap
        if let fileName = selectedMap.arWorldMapFileName {
            print("✅ MAP LOAD STATUS: ARWorldMap file found: \(fileName)")
            
            // Verify the file actually exists
            if let fileURL = getARWorldMapURL(fileName: fileName),
               FileManager.default.fileExists(atPath: fileURL.path) {
                print("✅ MAP LOAD STATUS: ARWorldMap file verified on disk")
                return .mapSelectedAndReady(mapName: mapName, fileName: fileName)
            } else {
                print("❌ MAP LOAD STATUS: ARWorldMap file missing from disk")
                return .mapSelectedButFilesMissing(mapName: mapName)
            }
        } else {
            print("⚠️ MAP LOAD STATUS: No ARWorldMap metadata found")
            print("   This is an old-style map that needs to be recreated")
            return .mapSelectedButNoARWorldMap(mapName: mapName)
        }
    }
    
    // MARK: - Get Selected Map for Navigation (CONVENIENCE)
    /// Returns the selected map and its ARWorldMap fileName if available
    func getSelectedMapInfoForNavigation() -> (map: JSONMap, fileName: String)? {
        let status = getMapLoadStatus()
        
        switch status {
        case .mapSelectedAndReady(let mapName, let fileName):
            if let map = maps.first(where: { $0.name == mapName }) {
                return (map, fileName)
            }
            return nil
        default:
            return nil
        }
    }
    
    // MARK: - Check Map Status (SIMPLE VERSION)
    /// Returns detailed status about the selected map
    func getSelectedMapStatus() -> (hasMap: Bool, hasARWorldMap: Bool, mapName: String?) {
        guard let selectedMap = getSelectedMapForNavigation() else {
            return (false, false, nil)
        }
        
        let hasARWorldMap = selectedMap.hasARWorldMap
        return (true, hasARWorldMap, selectedMap.name)
    }
    
    // MARK: - Migration Helper
    /// Returns list of maps that don't have ARWorldMap data
    func checkForMigrationNeeded() -> [String] {
        var mapsNeedingMigration: [String] = []
        
        print("🔍 Checking maps for ARWorldMap migration...")
        
        for map in maps {
            if !map.hasARWorldMap {
                print("   ⚠️ Map needs migration: \(map.name)")
                mapsNeedingMigration.append(map.name)
            } else {
                print("   ✅ Map OK: \(map.name)")
            }
        }
        
        if mapsNeedingMigration.isEmpty {
            print("✅ All maps have ARWorldMap data")
        } else {
            print("⚠️ \(mapsNeedingMigration.count) maps need migration")
        }
        
        return mapsNeedingMigration
    }
    
    // MARK: - Helper to Get ARWorldMap URL (Expose Private Method)
    /// Gets the file URL for an ARWorldMap file
    /// This is a public wrapper for the private method in the main class
    private func getARWorldMapURL(fileName: String) -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent("ARWorldMaps").appendingPathComponent(fileName)
    }
    
    // MARK: - Load Map for Navigation (CONVENIENCE)
    /// Loads the selected map's ARWorldMap for navigation
    /// This is a convenience method that combines selection check + load
    func loadSelectedMapForNavigation(completion: @escaping (Result<(map: JSONMap, worldMap: ARWorldMap), ARWorldMapError>) -> Void) {
        let status = getMapLoadStatus()
        
        switch status {
        case .mapSelectedAndReady:  // We don't need the associated values here
            guard let selectedMap = getSelectedMapForNavigation() else {
                completion(.failure(.fileNotFound))
                return
            }
            
            guard let fileName = selectedMap.arWorldMapFileName else {
                completion(.failure(.fileNotFound))
                return
            }
            
            // Use the correct method name that exists in JSONMapManager
            loadARWorldMap(fileName: fileName) { result in
                switch result {
                case .success(let worldMap):
                    completion(.success((selectedMap, worldMap)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        case .noMapSelected:
            print("❌ Cannot load: No map selected")
            completion(.failure(.fileNotFound))
            
        case .mapSelectedButNoARWorldMap(let mapName):
            print("❌ Cannot load: '\(mapName)' has no ARWorldMap")
            completion(.failure(.fileNotFound))
            
        case .mapSelectedButFilesMissing(let mapName):
            print("❌ Cannot load: '\(mapName)' files are missing")
            completion(.failure(.fileNotFound))
        }
    }
}
