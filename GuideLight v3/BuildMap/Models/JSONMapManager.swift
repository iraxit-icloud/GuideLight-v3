import SwiftUI
import Foundation

// MARK: - Data Models
struct JSONMap: Identifiable, Codable {
    let id: UUID
    let name: String
    let createdDate: Date
    let jsonData: [String: Any]
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdDate, description, jsonDataString
    }
    
    init(name: String, jsonData: [String: Any], description: String = "") {
        self.id = UUID()
        self.name = name
        self.jsonData = jsonData
        self.description = description
        self.createdDate = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        description = try container.decode(String.self, forKey: .description)
        
        // Decode jsonData from JSON string
        let jsonDataString = try container.decode(String.self, forKey: .jsonDataString)
        if let data = jsonDataString.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            jsonData = decoded
        } else {
            jsonData = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(description, forKey: .description)
        
        // Encode jsonData as JSON string
        do {
            let jsonDataEncoded = try JSONSerialization.data(withJSONObject: jsonData)
            let jsonDataString = String(data: jsonDataEncoded, encoding: .utf8) ?? "{}"
            try container.encode(jsonDataString, forKey: .jsonDataString)
        } catch {
            try container.encode("{}", forKey: .jsonDataString)
        }
    }
}

// MARK: - Simple JSON Map Manager
class SimpleJSONMapManager: ObservableObject {
    static let shared = SimpleJSONMapManager()
    
    @Published var maps: [JSONMap] = []
    @Published var currentBeacons: [[String: Any]] = []
    @Published var currentDoorways: [[String: Any]] = []
    
    private let userDefaults = UserDefaults.standard
    private let mapsKey = "saved_json_maps"
    
    private init() {
        loadMaps()
        setupNotifications()
        print("🗺️ SimpleJSONMapManager initialized with \(maps.count) maps")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBeaconAdded),
            name: NSNotification.Name("BeaconAdded"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDoorwayAdded),
            name: NSNotification.Name("DoorwayAdded"),
            object: nil
        )
    }
    
    @objc private func handleBeaconAdded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let name = userInfo["name"] as? String,
              let coordinates = userInfo["coordinates"] as? [String: Double] else {
            return
        }
        
        let beacon = [
            "id": UUID().uuidString,
            "name": name,
            "coordinates": coordinates,
            "category": userInfo["category"] as? String ?? "general",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        currentBeacons.append(beacon)
        print("🔸 BEACON ADDED: \(name) at (\(coordinates["x"] ?? 0), \(coordinates["y"] ?? 0), \(coordinates["z"] ?? 0))")
    }
    
    @objc private func handleDoorwayAdded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let name = userInfo["name"] as? String,
              let coordinates = userInfo["coordinates"] as? [String: Double] else {
            return
        }
        
        let doorway = [
            "id": UUID().uuidString,
            "name": name,
            "coordinates": coordinates,
            "startPoint": userInfo["startPoint"] as? [String: Double] ?? [:],
            "endPoint": userInfo["endPoint"] as? [String: Double] ?? [:],
            "doorwayType": userInfo["doorwayType"] as? String ?? "standard",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        currentDoorways.append(doorway)
        print("🚪 DOORWAY ADDED: \(name) at (\(coordinates["x"] ?? 0), \(coordinates["y"] ?? 0), \(coordinates["z"] ?? 0))")
    }
    
    func addMap(_ map: JSONMap) {
        maps.append(map)
        saveMaps()
        print("📝 Added map: \(map.name)")
    }
    
    func deleteMap(at index: Int) {
        guard index < maps.count else { return }
        maps.remove(at: index)
        saveMaps()
    }
    
    func saveCurrentSession(name: String? = nil) {
        guard !currentBeacons.isEmpty || !currentDoorways.isEmpty else {
            print("⚠️ No current session data to save")
            return
        }
        
        let mapName = name ?? "Map \(Date().formatted(.dateTime.day().month().year().hour().minute()))"
        let mapData = [
            "mapName": mapName,
            "beacons": currentBeacons,
            "doorways": currentDoorways,
            "metadata": [
                "createdDate": Date().timeIntervalSince1970,
                "version": "1.0"
            ]
        ] as [String: Any]
        
        let newMap = JSONMap(
            name: mapName,
            jsonData: mapData,
            description: "Saved from mapping session"
        )
        
        addMap(newMap)
        resetCurrentSession()
        print("💾 Saved current session as map: \(mapName)")
    }
    
    func resetCurrentSession() {
        currentBeacons.removeAll()
        currentDoorways.removeAll()
        print("🔄 Reset current session")
    }
    
    func getCurrentSessionAsJSON() -> String {
        let sessionData = [
            "mapName": "Current Session",
            "beacons": currentBeacons,
            "doorways": currentDoorways,
            "metadata": [
                "beaconCount": currentBeacons.count,
                "doorwayCount": currentDoorways.count,
                "timestamp": Date().timeIntervalSince1970
            ]
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return "Error: Unable to serialize session data"
        }
    }
    
    func exportMapAsJSON(_ map: JSONMap) -> String {
        print("📤 Exporting map: \(map.name)")
        print("   JSON data keys: \(map.jsonData.keys.joined(separator: ", "))")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: map.jsonData, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            print("   Export successful, length: \(jsonString.count)")
            return jsonString
        } catch {
            print("   Export failed: \(error)")
            return "Error: Unable to serialize JSON - \(error.localizedDescription)"
        }
    }
    
    func shareMap(_ map: JSONMap, completion: @escaping (URL?) -> Void) {
        let jsonString = exportMapAsJSON(map)
        let fileName = "\(map.name.replacingOccurrences(of: " ", with: "_")).json"
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(nil)
            return
        }
        
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            completion(fileURL)
        } catch {
            completion(nil)
        }
    }
    
    func shareCurrentSession(completion: @escaping (URL?) -> Void) {
        let jsonString = getCurrentSessionAsJSON()
        let fileName = "Current_Session_\(Date().formatted(.dateTime.day().month().hour().minute())).json"
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(nil)
            return
        }
        
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            completion(fileURL)
        } catch {
            completion(nil)
        }
    }
    
    private func saveMaps() {
        do {
            let encoded = try JSONEncoder().encode(maps)
            userDefaults.set(encoded, forKey: mapsKey)
            print("💾 Successfully saved \(maps.count) maps to UserDefaults")
            print("   Saved map names: \(maps.map { $0.name }.joined(separator: ", "))")
        } catch {
            print("❌ Failed to save maps: \(error)")
        }
    }
    
    private func loadMaps() {
        guard let data = userDefaults.data(forKey: mapsKey) else {
            print("📭 No saved maps data found in UserDefaults")
            return
        }
        
        print("📦 Found \(data.count) bytes of maps data in UserDefaults")
        
        do {
            maps = try JSONDecoder().decode([JSONMap].self, from: data)
            print("📚 Successfully loaded \(maps.count) maps from UserDefaults")
            
            // Debug: Print loaded map details
            for (index, map) in maps.enumerated() {
                print("   Map \(index + 1): \(map.name)")
                print("     Created: \(map.createdDate)")
                print("     JSON keys: \(map.jsonData.keys.joined(separator: ", "))")
                print("     JSON data size: \(map.jsonData.count) items")
            }
        } catch {
            print("❌ Failed to load maps: \(error)")
            print("   Error details: \(error.localizedDescription)")
            maps = []
        }
    }
    
    func clearAllMaps() {
        maps.removeAll()
        userDefaults.removeObject(forKey: mapsKey)
    }
    
    func reloadMaps() {
        loadMaps()
    }
}

// MARK: - Simple JSON Maps List View
struct SimpleJSONMapsListView: View {
    @ObservedObject private var mapManager = SimpleJSONMapManager.shared
    @State private var showingAddMap = false
    @State private var showingSessionJSON = false
    @State private var showingSessionShare = false
    @State private var sessionShareURL: URL?
    
    var body: some View {
        List {
            // Current Session Section
            if !mapManager.currentBeacons.isEmpty || !mapManager.currentDoorways.isEmpty {
                Section("Current Session") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Active Mapping Session")
                                .font(.headline)
                            Text("Beacons: \(mapManager.currentBeacons.count), Doorways: \(mapManager.currentDoorways.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Button("View JSON") {
                            showingSessionJSON = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Share JSON") {
                            shareCurrentSession()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Save as Map") {
                            mapManager.saveCurrentSession()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            // Debug Section
            Section("Debug Info") {
                HStack {
                    Text("Saved Maps:")
                    Spacer()
                    Text("\(mapManager.maps.count)")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Session Beacons:")
                    Spacer()
                    Text("\(mapManager.currentBeacons.count)")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Session Doorways:")
                    Spacer()
                    Text("\(mapManager.currentDoorways.count)")
                        .foregroundColor(.orange)
                }
                
                Button("Reset Session") {
                    mapManager.resetCurrentSession()
                }
                .foregroundColor(.orange)
            }
            
            // Saved Maps Section
            if mapManager.maps.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No Saved Maps")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Use 'Save as Map' to save your current session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section("Saved Maps") {
                    ForEach(mapManager.maps) { map in
                        NavigationLink(destination: SimpleJSONMapDetailView(map: map)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(map.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("Created: \(map.createdDate.formatted(.dateTime.day().month().year()))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        if !map.description.isEmpty {
                                            Text(map.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        // Show beacon and doorway counts
                                        HStack {
                                            if let beacons = map.jsonData["beacons"] as? [Any] {
                                                Text("Beacons: \(beacons.count)")
                                                    .font(.caption2)
                                                    .foregroundColor(.green)
                                            }
                                            
                                            if let doorways = map.jsonData["doorways"] as? [Any] {
                                                Text("Doorways: \(doorways.count)")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .onDelete(perform: deleteMap)
                }
            }
        }
        .navigationTitle("JSON Maps")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    showingAddMap = true
                }
            }
        }
        .sheet(isPresented: $showingAddMap) {
            SimpleJSONMapAddView()
        }
        .sheet(isPresented: $showingSessionJSON) {
            SimpleSessionJSONView()
        }
        .sheet(isPresented: $showingSessionShare) {
            if let url = sessionShareURL {
                SimpleJSONMapShareSheet(activityItems: [url])
            }
        }
    }
    
    private func deleteMap(at offsets: IndexSet) {
        for index in offsets {
            mapManager.deleteMap(at: index)
        }
    }
    
    private func shareCurrentSession() {
        mapManager.shareCurrentSession { url in
            sessionShareURL = url
            showingSessionShare = url != nil
        }
    }
}

// MARK: - Simple Session JSON View
struct SimpleSessionJSONView: View {
    @ObservedObject private var mapManager = SimpleJSONMapManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Session Data")
                            .font(.headline)
                        
                        HStack {
                            Text("Beacons: \(mapManager.currentBeacons.count)")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Text("Doorways: \(mapManager.currentDoorways.count)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JSON Content")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(mapManager.getCurrentSessionAsJSON())
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Button("Copy JSON") {
                            UIPasteboard.general.string = mapManager.getCurrentSessionAsJSON()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Save as Map") {
                            mapManager.saveCurrentSession()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Current Session")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Simple JSON Map Detail View
struct SimpleJSONMapDetailView: View {
    let map: JSONMap
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var jsonContent = ""
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Map Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Map Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Name:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Text(map.name)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("Created:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Text(map.createdDate.formatted(.dateTime.day().month().year()))
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("Description:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Text(map.description.isEmpty ? "No description" : map.description)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("Data Keys:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Text(map.jsonData.keys.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            if let beacons = map.jsonData["beacons"] as? [Any] {
                                HStack {
                                    Text("Beacons:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    Text("\(beacons.count)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if let doorways = map.jsonData["doorways"] as? [Any] {
                                HStack {
                                    Text("Doorways:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    Text("\(doorways.count)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // JSON Content
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
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    Text("Loading JSON content...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                )
                                .cornerRadius(8)
                        } else if jsonContent.isEmpty {
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
                        } else {
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
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
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
                        
                        // Debug button
                        Button("Debug Map Data") {
                            print("🐛 DEBUG MAP DATA:")
                            print("   Map ID: \(map.id)")
                            print("   Map Name: \(map.name)")
                            print("   Created: \(map.createdDate)")
                            print("   Description: \(map.description)")
                            print("   JSON Data Keys: \(map.jsonData.keys)")
                            print("   JSON Data: \(map.jsonData)")
                            print("   Exported JSON: \(jsonContent)")
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.orange)
                    }
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
        .onAppear {
            print("🔍 SimpleJSONMapDetailView appeared for: \(map.name)")
            print("   Map JSON keys: \(map.jsonData.keys.joined(separator: ", "))")
            loadJSONContent()
        }
    }
    
    private func loadJSONContent() {
        print("📖 Loading JSON content for map: \(map.name)")
        isLoading = true
        
        // Add a small delay to show loading state
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
}

// MARK: - Simple JSON Map Add View
struct SimpleJSONMapAddView: View {
    @ObservedObject private var mapManager = SimpleJSONMapManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var jsonText = """
{
  "mapName": "Sample Map",
  "beacons": [],
  "doorways": []
}
"""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Map Details") {
                    TextField("Map Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section("JSON Content") {
                    TextEditor(text: $jsonText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
                }
                
                Section("Quick Actions") {
                    if !mapManager.currentBeacons.isEmpty || !mapManager.currentDoorways.isEmpty {
                        Button("Use Current Session Data") {
                            jsonText = mapManager.getCurrentSessionAsJSON()
                            if name.isEmpty {
                                name = "Map from Session"
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Add New Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMap()
                    }
                    .disabled(name.isEmpty || jsonText.isEmpty)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveMap() {
        guard let jsonData = try? JSONSerialization.jsonObject(with: jsonText.data(using: .utf8) ?? Data()) as? [String: Any] else {
            errorMessage = "Invalid JSON format"
            showingError = true
            return
        }
        
        let newMap = JSONMap(name: name, jsonData: jsonData, description: description)
        mapManager.addMap(newMap)
        dismiss()
    }
}

// MARK: - Simple JSON Map Share Sheet
struct SimpleJSONMapShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
