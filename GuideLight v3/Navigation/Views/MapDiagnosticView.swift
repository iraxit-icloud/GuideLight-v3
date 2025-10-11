//
//  MapDiagnosticView.swift
//  Diagnostic tool to see exactly what's happening with maps
//

import SwiftUI

struct MapDiagnosticView: View {
    @ObservedObject private var mapManager = SimpleJSONMapManager.shared
    @State private var diagnosticInfo = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Status")
                            .font(.headline)
                        
                        statusRow(
                            label: "Maps in Manager",
                            value: "\(mapManager.maps.count)",
                            color: mapManager.maps.isEmpty ? .red : .green
                        )
                        
                        statusRow(
                            label: "Selected Map ID",
                            value: mapManager.selectedMapIdForNavigation?.uuidString ?? "None",
                            color: mapManager.selectedMapIdForNavigation != nil ? .green : .orange
                        )
                        
                        if let selectedMap = mapManager.getSelectedMapForNavigation() {
                            statusRow(
                                label: "Selected Map Name",
                                value: selectedMap.name,
                                color: .green
                            )
                            
                            statusRow(
                                label: "Has ARWorldMap",
                                value: selectedMap.hasARWorldMap ? "Yes ✅" : "No ❌",
                                color: selectedMap.hasARWorldMap ? .green : .orange
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Load Status Check
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Map Load Status")
                            .font(.headline)
                        
                        let loadStatus = mapManager.getMapLoadStatus()
                        
                        HStack {
                            Image(systemName: loadStatus.canNavigate ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(loadStatus.canNavigate ? .green : .red)
                                .font(.title)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(statusDescription(loadStatus))
                                    .font(.subheadline.bold())
                                
                                if let errorMsg = loadStatus.errorMessage {
                                    Text(errorMsg)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if case .mapSelectedAndReady(let mapName, let fileName) = loadStatus {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Map Name:")
                                    .font(.caption.bold())
                                Text(mapName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Text("ARWorldMap File:")
                                    .font(.caption.bold())
                                    .padding(.top, 4)
                                Text(fileName)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // All Maps
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Maps (\(mapManager.maps.count))")
                            .font(.headline)
                        
                        ForEach(mapManager.maps) { map in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if mapManager.selectedMapIdForNavigation == map.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text(map.name)
                                        .font(.subheadline.bold())
                                }
                                
                                HStack {
                                    Image(systemName: map.hasARWorldMap ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(map.hasARWorldMap ? .green : .orange)
                                    
                                    Text(map.hasARWorldMap ? "Has ARWorldMap" : "Old-style map (needs update)")
                                        .font(.caption)
                                        .foregroundColor(map.hasARWorldMap ? .green : .orange)
                                }
                                
                                if let fileName = map.arWorldMapFileName {
                                    Text("File: \(fileName)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                if let beacons = map.jsonData["beacons"] as? [Any],
                                   let doorways = map.jsonData["doorways"] as? [Any] {
                                    Text("Beacons: \(beacons.count), Doorways: \(doorways.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button("Run Full Diagnostic") {
                            runDiagnostic()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        
                        Button("Check for Maps Needing Migration") {
                            checkMigration()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Check ARWorldMap Storage") {
                            checkARWorldMapStorage()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Diagnostic Output
                    if !diagnosticInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Diagnostic Output")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button("Copy") {
                                    UIPasteboard.general.string = diagnosticInfo
                                }
                                .font(.caption)
                            }
                            
                            ScrollView {
                                Text(diagnosticInfo)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 300)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Map Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func statusRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
    
    private func statusDescription(_ status: MapLoadStatus) -> String {
        switch status {
        case .noMapSelected:
            return "No Map Selected"
        case .mapSelectedButNoARWorldMap(let name):
            return "'\(name)' - Old-Style Map"
        case .mapSelectedButFilesMissing(let name):
            return "'\(name)' - Files Missing"
        case .mapSelectedAndReady(let name, _):
            return "'\(name)' - Ready ✅"
        }
    }
    
    private func runDiagnostic() {
        var output = "🔍 MAP DIAGNOSTIC REPORT\n"
        output += "========================\n\n"
        output += "Generated: \(Date().formatted())\n\n"
        
        // Manager Status
        output += "MANAGER STATUS:\n"
        output += "  Total maps: \(mapManager.maps.count)\n"
        output += "  Selected ID: \(mapManager.selectedMapIdForNavigation?.uuidString ?? "None")\n"
        output += "  Maps with ARWorldMap: \(mapManager.maps.filter { $0.hasARWorldMap }.count)\n"
        output += "  Maps without ARWorldMap: \(mapManager.maps.filter { !$0.hasARWorldMap }.count)\n\n"
        
        // Selected Map
        if let selected = mapManager.getSelectedMapForNavigation() {
            output += "SELECTED MAP:\n"
            output += "  Name: \(selected.name)\n"
            output += "  ID: \(selected.id)\n"
            output += "  Has ARWorldMap: \(selected.hasARWorldMap ? "YES ✅" : "NO ❌")\n"
            if let fileName = selected.arWorldMapFileName {
                output += "  ARWorldMap File: \(fileName)\n"
            }
            if let beacons = selected.jsonData["beacons"] as? [Any],
               let doorways = selected.jsonData["doorways"] as? [Any] {
                output += "  Beacons: \(beacons.count)\n"
                output += "  Doorways: \(doorways.count)\n"
            }
            output += "\n"
        } else {
            output += "SELECTED MAP: None\n\n"
        }
        
        // Load Status
        let loadStatus = mapManager.getMapLoadStatus()
        output += "LOAD STATUS:\n"
        output += "  Can Navigate: \(loadStatus.canNavigate ? "YES ✅" : "NO ❌")\n"
        output += "  Status: \(statusDescription(loadStatus))\n"
        if let errorMsg = loadStatus.errorMessage {
            output += "  Error: \(errorMsg)\n"
        }
        output += "\n"
        
        // All Maps
        output += "ALL MAPS (\(mapManager.maps.count)):\n"
        output += "================================\n"
        for (index, map) in mapManager.maps.enumerated() {
            let isSelected = mapManager.selectedMapIdForNavigation == map.id
            
            output += "\n\(index + 1). \(map.name)\n"
            output += "   ID: \(map.id.uuidString)\n"
            output += "   Selected: \(isSelected ? "YES ✅" : "NO")\n"
            output += "   ARWorldMap: \(map.hasARWorldMap ? "YES ✅" : "NO ❌")\n"
            if let fileName = map.arWorldMapFileName {
                output += "   File: \(fileName)\n"
            }
            output += "   Created: \(map.createdDate.formatted())\n"
            if let beacons = map.jsonData["beacons"] as? [Any],
               let doorways = map.jsonData["doorways"] as? [Any] {
                output += "   Beacons: \(beacons.count), Doorways: \(doorways.count)\n"
            }
        }
        
        diagnosticInfo = output
        print(output)
    }
    
    private func checkMigration() {
        let mapsNeedingMigration = mapManager.checkForMigrationNeeded()
        
        var output = "🔄 MIGRATION CHECK\n"
        output += "=================\n\n"
        output += "Generated: \(Date().formatted())\n\n"
        
        if mapsNeedingMigration.isEmpty {
            output += "✅ All maps have ARWorldMap data!\n"
            output += "No migration needed.\n"
        } else {
            output += "⚠️ \(mapsNeedingMigration.count) map(s) need migration:\n\n"
            for (index, mapName) in mapsNeedingMigration.enumerated() {
                output += "\(index + 1). \(mapName)\n"
            }
            output += "\n"
            output += "WHAT THIS MEANS:\n"
            output += "These maps were created without ARWorldMap\n"
            output += "and need to be recreated to use for navigation.\n\n"
            output += "HOW TO FIX:\n"
            output += "1. Go to Build Map mode\n"
            output += "2. Recreate the map by adding beacons/doorways\n"
            output += "3. Save the map - it will include ARWorldMap\n"
        }
        
        diagnosticInfo = output
        print(output)
    }
    
    private func checkARWorldMapStorage() {
        let storageInfo = mapManager.getARWorldMapStorageInfo()
        
        var output = "💾 ARWorldMap STORAGE INFO\n"
        output += "==========================\n\n"
        output += "Generated: \(Date().formatted())\n\n"
        
        if let directory = storageInfo["directory"] as? String {
            output += "Storage Directory:\n\(directory)\n\n"
        }
        
        if let fileCount = storageInfo["fileCount"] as? Int {
            output += "Total Files: \(fileCount)\n"
        }
        
        if let totalSize = storageInfo["totalSize"] as? String {
            output += "Total Size: \(totalSize)\n\n"
        }
        
        if let files = storageInfo["files"] as? [[String: Any]] {
            output += "FILES:\n"
            for (index, file) in files.enumerated() {
                if let name = file["name"] as? String,
                   let size = file["size"] as? String {
                    output += "\(index + 1). \(name)\n"
                    output += "   Size: \(size)\n"
                }
            }
        }
        
        if let error = storageInfo["error"] as? String {
            output += "❌ ERROR: \(error)\n"
        }
        
        diagnosticInfo = output
        print(output)
    }
}

#Preview {
    MapDiagnosticView()
}
