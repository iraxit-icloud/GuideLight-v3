//
//  NavigationDebugView.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/9/25.
//


//
//  NavigationDebugView.swift
//  Debug and Testing Interface
//

import SwiftUI
import ARKit

// MARK: - Navigation Debug View
struct NavigationDebugView: View {
    @ObservedObject var viewModel: PathNavigationViewModel
    @State private var showingGraphViewer = false
    @State private var showingPerformanceStats = false
    @State private var showingLogs = false
    @State private var autoRefresh = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Navigation Debug")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    autoRefresh.toggle()
                } label: {
                    Image(systemName: autoRefresh ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.blue)
            
            ScrollView {
                VStack(spacing: 12) {
                    // State Section
                    stateSection
                    
                    // Position Section
                    positionSection
                    
                    // Path Section
                    if viewModel.currentPath != nil {
                        pathSection
                    }
                    
                    // Navigation Section
                    if viewModel.navigationState == .navigating {
                        navigationSection
                    }
                    
                    // Graph Section
                    graphSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingGraphViewer) {
            GraphViewerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingLogs) {
            LogsViewerSheet()
        }
    }
    
    // MARK: - State Section
    private var stateSection: some View {
        DebugCard(title: "State", icon: "info.circle.fill", color: .blue) {
            VStack(alignment: .leading, spacing: 8) {
                DebugRow(label: "Navigation State", value: "\(viewModel.navigationState)")
                DebugRow(label: "AR Session", value: viewModel.session.currentFrame != nil ? "Running" : "Not Running")
                
                if let destination = viewModel.selectedDestination {
                    DebugRow(label: "Destination", value: destination.name)
                }
            }
        }
    }
    
    // MARK: - Position Section
    private var positionSection: some View {
        DebugCard(title: "Position", icon: "location.circle.fill", color: .green) {
            VStack(alignment: .leading, spacing: 8) {
                if let position = viewModel.getCurrentCameraPosition() {
                    DebugRow(label: "X", value: String(format: "%.2f m", position.x))
                    DebugRow(label: "Y", value: String(format: "%.2f m", position.y))
                    DebugRow(label: "Z", value: String(format: "%.2f m", position.z))
                    
                    if let direction = viewModel.getDirectionToNextTarget() {
                        let angle = atan2(direction.x, direction.z) * 180 / .pi
                        DebugRow(label: "Heading", value: String(format: "%.0f°", angle))
                    }
                } else {
                    Text("Position not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Path Section
    private var pathSection: some View {
        DebugCard(title: "Path", icon: "map.fill", color: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                if let path = viewModel.currentPath {
                    DebugRow(label: "Total Steps", value: "\(path.path.count)")
                    DebugRow(label: "Current Step", value: "\(viewModel.currentPathIndex + 1)")
                    DebugRow(label: "Distance", value: String(format: "%.2f m", path.totalDistance))
                    DebugRow(label: "Remaining", value: "\(path.path.count - viewModel.currentPathIndex)")
                    
                    Divider()
                    
                    Text("Waypoints:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(path.path.enumerated()), id: \.offset) { index, node in
                        HStack {
                            Image(systemName: index == viewModel.currentPathIndex ? "location.fill" : 
                                              index < viewModel.currentPathIndex ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(index == viewModel.currentPathIndex ? .blue :
                                               index < viewModel.currentPathIndex ? .green : .gray)
                                .font(.caption)
                            
                            Text("\(index + 1). \(node.name)")
                                .font(.caption)
                                .foregroundColor(index == viewModel.currentPathIndex ? .primary : .secondary)
                            
                            Spacer()
                            
                            if index < path.path.count - 1 {
                                let nextNode = path.path[index + 1]
                                let distance = node.position.distance(to: nextNode.position)
                                Text(String(format: "%.1fm", distance))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Section
    private var navigationSection: some View {
        DebugCard(title: "Navigation", icon: "arrow.triangle.turn.up.right.circle.fill", color: .purple) {
            VStack(alignment: .leading, spacing: 8) {
                if let target = viewModel.getNextTarget() {
                    DebugRow(label: "Next Target", value: target.name)
                    DebugRow(label: "Distance", value: String(format: "%.2f m", viewModel.distanceToNextPoint))
                    
                    if let direction = viewModel.getDirectionToNextTarget() {
                        let angle = atan2(direction.x, direction.z)
                        let compassDir = CompassDirection.from(angle: angle)
                        DebugRow(label: "Direction", value: compassDir.rawValue)
                    }
                }
                
                if let finalDest = viewModel.getFinalDestination(),
                   let currentPos = viewModel.getCurrentCameraPosition() {
                    let totalRemaining = currentPos.distance(to: finalDest.position)
                    DebugRow(label: "To Destination", value: String(format: "%.2f m", totalRemaining))
                }
            }
        }
    }
    
    // MARK: - Graph Section
    private var graphSection: some View {
        DebugCard(title: "Graph", icon: "network", color: .indigo) {
            VStack(alignment: .leading, spacing: 8) {
                DebugRow(label: "Destinations", value: "\(viewModel.availableDestinations.count)")
                
                Button {
                    showingGraphViewer = true
                } label: {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("View Graph Details")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        DebugCard(title: "Actions", icon: "wrench.fill", color: .gray) {
            VStack(spacing: 8) {
                Button {
                    showingLogs = true
                } label: {
                    Label("View Logs", systemImage: "doc.text.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    exportDebugData()
                } label: {
                    Label("Export Debug Data", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if viewModel.currentPath != nil {
                    Button {
                        printPathJSON()
                    } label: {
                        Label("Print Path JSON", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func exportDebugData() {
        var debugData = """
        === NAVIGATION DEBUG DATA ===
        Timestamp: \(Date().formatted())
        
        STATE:
        - Navigation State: \(viewModel.navigationState)
        - Selected Destination: \(viewModel.selectedDestination?.name ?? "None")
        
        """
        
        if let position = viewModel.getCurrentCameraPosition() {
            debugData += """
            POSITION:
            - X: \(position.x) m
            - Y: \(position.y) m
            - Z: \(position.z) m
            
            """
        }
        
        if let path = viewModel.currentPath {
            debugData += """
            PATH:
            - Total Steps: \(path.path.count)
            - Current Step: \(viewModel.currentPathIndex + 1)
            - Total Distance: \(path.totalDistance) m
            
            WAYPOINTS:
            """
            for (index, node) in path.path.enumerated() {
                let status = index < viewModel.currentPathIndex ? "✓" :
                           index == viewModel.currentPathIndex ? "→" : "○"
                debugData += "\n\(status) \(index + 1). \(node.name) at \(node.position.debugDescription)"
            }
        }
        
        print("\n" + debugData + "\n")
        UIPasteboard.general.string = debugData
        NavigationLogger.shared.log("Debug data exported to clipboard")
    }
    
    private func printPathJSON() {
        viewModel.currentPath?.printJSON()
    }
}

// MARK: - Debug Card
struct DebugCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Debug Row
struct DebugRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Graph Viewer Sheet
struct GraphViewerSheet: View {
    @ObservedObject var viewModel: PathNavigationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Available Destinations") {
                    ForEach(viewModel.availableDestinations) { node in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(node.name)
                                .font(.headline)
                            
                            Text("Position: \(node.position.debugDescription)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if case .beacon(let category) = node.nodeType {
                                Text("Category: \(category)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Graph Details")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Logs Viewer Sheet
struct LogsViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Navigation Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        NavigationLogger.shared.clearLogs()
                        logs = "Logs cleared"
                    } label: {
                        Text("Clear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            logs = NavigationLogger.shared.exportLogs()
        }
    }
}

// MARK: - Debug Overlay for PathNavigationView
struct DebugOverlay: View {
    @ObservedObject var viewModel: PathNavigationViewModel
    @State private var showingDebugPanel = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button {
                    showingDebugPanel.toggle()
                } label: {
                    Image(systemName: "ladybug.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.red.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(.trailing, 8)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .sheet(isPresented: $showingDebugPanel) {
            NavigationDebugView(viewModel: viewModel)
        }
    }
}