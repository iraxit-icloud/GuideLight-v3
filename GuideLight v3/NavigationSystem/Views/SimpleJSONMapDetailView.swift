//
//  SimpleJSONMapDetailView.swift
//  GuideLight v3
//
//  Clean version with no duplicate navigation sections
//

import SwiftUI

// MARK: - Simple JSON Map Detail View
struct SimpleJSONMapDetailView: View {
    let map: JSONMap
    @ObservedObject private var mapManager = SimpleJSONMapManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var jsonContent = ""
    @State private var isLoading = true
    @State private var showingDeleteConfirmation = false
    
    var isSelectedForNavigation: Bool {
        mapManager.selectedMapIdForNavigation == map.id
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // SINGLE Navigation Status Section
                    navigationStatusSection
                    
                    // ARWorldMap Status
                    if map.hasARWorldMap {
                        arWorldMapStatusSection
                    }
                    
                    // Map Information
                    mapInformationSection
                    
                    // JSON Content
                    jsonContentSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle(map.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                SimpleJSONMapShareSheet(activityItems: [url])
            }
        }
        .alert("Delete Map", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMap()
            }
        } message: {
            Text("Are you sure you want to delete '\(map.name)'? This action cannot be undone.")
        }
        .onAppear {
            print("📖 SimpleJSONMapDetailView appeared for: \(map.name)")
            print("   Map JSON keys: \(map.jsonData.keys.joined(separator: ", "))")
            loadJSONContent()
        }
    }
    
    // MARK: - Navigation Status Section (SINGLE)
    private var navigationStatusSection: some View {
        Group {
            if isSelectedForNavigation {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Currently Selected for Navigation")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - ARWorldMap Status Section
    private var arWorldMapStatusSection: some View {
        HStack {
            Image(systemName: "cube.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("ARWorldMap Available")
                    .font(.headline)
                    .foregroundColor(.blue)
                if let fileName = map.arWorldMapFileName {
                    Text(fileName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Map Information Section
    private var mapInformationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Map Information")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                infoRow(label: "Name:", value: map.name)
                infoRow(label: "Created:", value: map.createdDate.formatted(.dateTime.day().month().year()))
                infoRow(label: "Description:", value: map.description.isEmpty ? "No description" : map.description)
                infoRow(label: "Has ARWorldMap:", value: map.hasARWorldMap ? "Yes" : "No", valueColor: map.hasARWorldMap ? .blue : .gray)
                infoRow(label: "Data Keys:", value: map.jsonData.keys.joined(separator: ", "), valueColor: .blue)
                
                if let beacons = map.jsonData["beacons"] as? [Any] {
                    infoRow(label: "Beacons:", value: "\(beacons.count)", valueColor: .green)
                }
                
                if let doorways = map.jsonData["doorways"] as? [Any] {
                    infoRow(label: "Doorways:", value: "\(doorways.count)", valueColor: .orange)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Info Row Helper
    private func infoRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - JSON Content Section
    private var jsonContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("JSON Content")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(jsonContent.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isLoading {
                loadingPlaceholder
            } else if jsonContent.isEmpty {
                errorPlaceholder
            } else {
                jsonScrollView
            }
        }
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 200)
            .overlay(
                Text("Loading JSON content...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
            .cornerRadius(8)
    }
    
    private var errorPlaceholder: some View {
        Rectangle()
            .fill(Color.red.opacity(0.1))
            .frame(height: 200)
            .overlay(
                VStack {
                    Text("Failed to load JSON content")
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Retry") {
                        loadJSONContent()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            )
            .cornerRadius(8)
    }
    
    private var jsonScrollView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(jsonContent)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
        .frame(minHeight: 200)
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Navigation Selection Button
            if isSelectedForNavigation {
                Button {
                    mapManager.selectMapForNavigation(nil)
                } label: {
                    Label("Remove from Navigation", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else {
                Button {
                    mapManager.selectMapForNavigation(map.id)
                } label: {
                    Label("Use for Navigation", systemImage: "location.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            Button("Share Map") {
                shareMap()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(jsonContent.isEmpty)
            
            Button("Copy JSON") {
                UIPasteboard.general.string = jsonContent
                print("📋 Copied JSON to clipboard (\(jsonContent.count) characters)")
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(jsonContent.isEmpty)
            
            Button("Delete Map") {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .foregroundColor(.red)
            
            Button("Debug Map Data") {
                debugMapData()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .foregroundColor(.orange)
        }
    }
    
    // MARK: - Helper Methods
    private func loadJSONContent() {
        print("📖 Loading JSON content for map: \(map.name)")
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: map.jsonData, options: .prettyPrinted)
                jsonContent = String(data: jsonData, encoding: .utf8) ?? ""
                print("   ✅ Loaded JSON content length: \(jsonContent.count)")
                if jsonContent.isEmpty {
                    print("   ⚠️ JSON content is empty!")
                }
            } catch {
                print("   ❌ Failed to serialize JSON: \(error)")
                jsonContent = "Error serializing JSON: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func shareMap() {
        print("📤 Sharing map: \(map.name)")
        
        let jsonString = jsonContent.isEmpty ? SimpleJSONMapManager.shared.exportMapAsJSON(map) : jsonContent
        let fileName = "\(map.name.replacingOccurrences(of: " ", with: "_")).json"
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get documents directory")
            return
        }
        
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            shareURL = fileURL
            showingShareSheet = true
            print("✅ Share file created: \(fileURL)")
        } catch {
            print("❌ Failed to create share file: \(error)")
        }
    }
    
    private func deleteMap() {
        print("🗑️ Deleting map: \(map.name)")
        
        if let index = mapManager.maps.firstIndex(where: { $0.id == map.id }) {
            mapManager.deleteMap(at: index)
            print("✅ Map deleted successfully")
            dismiss()
        } else {
            print("❌ Failed to find map to delete")
        }
    }
    
    private func debugMapData() {
        print("🛠 DEBUG MAP DATA:")
        print("   Map ID: \(map.id)")
        print("   Map Name: \(map.name)")
        print("   Created: \(map.createdDate)")
        print("   Description: \(map.description)")
        print("   Has ARWorldMap: \(map.hasARWorldMap)")
        if let fileName = map.arWorldMapFileName {
            print("   ARWorldMap file: \(fileName)")
        }
        print("   JSON Data Keys: \(map.jsonData.keys)")
        print("   JSON Data: \(map.jsonData)")
    }
}
