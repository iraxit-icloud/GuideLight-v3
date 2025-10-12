//
//  NavigationDebugView.swift
//  FIXED VERSION - Compatible with updated PathNavigationViewModel
//

import SwiftUI
import ARKit
import simd

struct NavigationDebugView: View {
    @ObservedObject var viewModel: PathNavigationViewModel
    @State private var showFullDebug = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact header
            compactHeader
            
            // Expandable debug info
            if showFullDebug {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        debugInfo
                    }
                    .padding()
                }
                .frame(maxHeight: 400)
                .background(Color.black.opacity(0.9))
                .transition(.move(edge: .top))
            }
        }
        .background(Color.black.opacity(0.95))
    }
    
    // MARK: - Compact Header
    
    private var compactHeader: some View {
        HStack {
            Image(systemName: "ant.fill")
                .foregroundColor(.green)
            
            Text("Debug Info")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
            
            Spacer()
            
            if viewModel.navigationState == .navigating {
                Text("\(Int(viewModel.currentFPS)) FPS")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(viewModel.isPerformanceGood ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            Button {
                withAnimation {
                    showFullDebug.toggle()
                }
            } label: {
                Image(systemName: showFullDebug ? "chevron.up" : "chevron.down")
                    .foregroundColor(.green)
                    .padding(8)
                    .background(Circle().fill(Color.green.opacity(0.2)))
            }
        }
        .padding()
        .background(Color.black.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(Color.green)
                .frame(height: 2),
            alignment: .bottom
        )
    }
    
    // MARK: - Debug Info
    
    private var debugInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            // State Info
            stateSection
            
            Divider().background(Color.gray)
            
            // Position Info
            if let position = viewModel.getCurrentCameraPosition() {
                positionSection(position: position)
            }
            
            Divider().background(Color.gray)
            
            // Navigation Info
            if viewModel.navigationState == .navigating {
                navigationSection
            }
            
            Divider().background(Color.gray)
            
            // Coordinate Transform Info
            coordinateTransformSection
            
            Divider().background(Color.gray)
            
            // Performance Info
            performanceSection
        }
    }
    
    // MARK: - State Section
    
    private var stateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("State")
            
            debugRow("Navigation", value: stateText)
            debugRow("Relocalized", value: viewModel.isRelocalized ? "✅ YES" : "❌ NO")
            debugRow("Mapping Status", value: mappingStatusText)
            
            if case .error(let message) = viewModel.navigationState {
                Text("Error: \(message)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var stateText: String {
        switch viewModel.navigationState {
        case .idle: return "Idle"
        case .loadingMap: return "Loading Map"
        case .mapLoaded: return "Map Loaded"
        case .selectingDestination: return "Selecting Destination"
        case .calculatingPath: return "Calculating Path"
        case .pathCalculated: return "Path Calculated"
        case .navigating: return "Navigating"
        case .destinationReached: return "Destination Reached"
        case .error: return "Error"
        }
    }
    
    private var mappingStatusText: String {
        switch viewModel.worldMappingStatus {
        case .notAvailable: return "Not Available"
        case .limited: return "Limited"
        case .extending: return "Extending"
        case .mapped: return "Mapped"
        @unknown default: return "Unknown"
        }
    }
    
    // MARK: - Position Section
    
    private func positionSection(position: simd_float3) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Position")
            
            debugRow("X", value: String(format: "%.2f m", position.x))
            debugRow("Y", value: String(format: "%.2f m", position.y))
            debugRow("Z", value: String(format: "%.2f m", position.z))
            
            if let direction = viewModel.getDirectionToNextTarget() {
                Divider().background(Color.gray.opacity(0.5))
                debugRow("Direction X", value: String(format: "%.3f", direction.x))
                debugRow("Direction Z", value: String(format: "%.3f", direction.z))
            }
        }
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Navigation")
            
            if let target = viewModel.getNextTarget() {
                debugRow("Current Target", value: target.name)
                debugRow("Distance", value: String(format: "%.2f m", viewModel.distanceToNextPoint))
            }
            
            if let destination = viewModel.getFinalDestination() {
                debugRow("Final Destination", value: destination.name)
            }
            
            debugRow("Waypoint", value: "\(viewModel.currentPathIndex + 1) / \(viewModel.currentPath?.path.count ?? 0)")
            
            Divider().background(Color.gray.opacity(0.5))
            
            debugRow("Arrow Rotation", value: String(format: "%.1f°", viewModel.arrowRotation))
            debugRow("Is Aligned", value: viewModel.isAligned ? "✅ YES" : "❌ NO")
            debugRow("Direction Color", value: colorName(viewModel.directionColor))
            debugRow("Turn Instruction", value: viewModel.turnInstruction.description)
            debugRow("Compass Direction", value: viewModel.currentDirection.rawValue)
            
            if let stats = viewModel.statistics {
                Divider().background(Color.gray.opacity(0.5))
                debugRow("Elapsed Time", value: stats.formattedElapsedTime())
                debugRow("Current Speed", value: String(format: "%.2f m/s", stats.currentSpeed))
                debugRow("Waypoints Reached", value: "\(stats.waypointsReached)")
            }
        }
    }
    
    // MARK: - Coordinate Transform Section
    
    private var coordinateTransformSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Coordinate Transform")
            
            HStack {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(viewModel.coordinateTransformMode.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            if viewModel.coordinateTransformMode != .none {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Coordinate transformation active")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Performance")
            
            debugRow("FPS", value: String(format: "%.1f", viewModel.currentFPS))
            debugRow("Performance", value: viewModel.isPerformanceGood ? "✅ Good" : "⚠️ Low")
            
            if let path = viewModel.currentPath {
                debugRow("Graph Nodes", value: "\(path.path.count)")
                debugRow("Total Distance", value: String(format: "%.1f m", path.totalDistance))
            }
            
            debugRow("Available Destinations", value: "\(viewModel.availableDestinations.count)")
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundColor(.green)
            .textCase(.uppercase)
    }
    
    private func debugRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundColor(.white)
        }
    }
    
    private func colorName(_ color: Color) -> String {
        switch color {
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .red: return "Red"
        case .gray: return "Gray"
        default: return "Unknown"
        }
    }
}

// MARK: - Preview
struct NavigationDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationDebugView(viewModel: PathNavigationViewModel())
            .preferredColorScheme(.dark)
    }
}
