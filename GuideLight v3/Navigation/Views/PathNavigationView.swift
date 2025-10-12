//
//  PathNavigationView.swift
//  Complete Drop-in Ready Version with Integrated Diagnostics
//

import SwiftUI
import ARKit
import RealityKit

struct PathNavigationView: View {
    @StateObject private var viewModel = PathNavigationViewModel()
    @State private var showDestinationPicker = false
    @State private var showDiagnostics = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // AR Camera View
            NavigationARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Main Navigation UI
            VStack(spacing: 0) {
                // Diagnostic Panel (toggleable)
                if showDiagnostics {
                    CoordinateDiagnosticView(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
                
                Spacer()
                
                // Bottom Navigation Controls
                bottomNavigationControls
            }
            
            // Overlays
            if viewModel.navigationState == .loadingMap {
                loadingOverlay
            }
            
            if !viewModel.isRelocalized && viewModel.relocalizationState != .notStarted {
                relocalizationOverlay
            }
            
            if showDestinationPicker {
                destinationPickerOverlay
            }
            
            if viewModel.showDestinationReached {
                destinationReachedOverlay
            }
        }
        .onAppear {
            viewModel.startARSession()
            viewModel.loadSelectedMap()
        }
        .onDisappear {
            viewModel.pauseARSession()
        }
    }
    
    // MARK: - Bottom Navigation Controls
    
    private var bottomNavigationControls: some View {
        VStack(spacing: 0) {
            // Navigation Info Card (when navigating)
            if viewModel.navigationState == .navigating {
                navigationInfoCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Control Panel
            controlPanel
        }
    }
    
    // MARK: - Navigation Info Card
    
    private var navigationInfoCard: some View {
        VStack(spacing: 12) {
            // Current Waypoint & Final Destination
            if let currentTarget = viewModel.getNextTarget(),
               let finalDestination = viewModel.getFinalDestination() {
                VStack(spacing: 4) {
                    // Show current waypoint we're heading to
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Next: \(currentTarget.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    
                    // Show final destination
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text("Final: \(finalDestination.name)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("(\(viewModel.currentPathIndex + 1)/\(viewModel.currentPath?.path.count ?? 0))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Distance & Direction
            HStack(spacing: 20) {
                // Directional Arrow
                ZStack {
                    Circle()
                        .fill(viewModel.directionColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(viewModel.directionColor, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(viewModel.directionColor)
                        .rotationEffect(.degrees(viewModel.arrowRotation))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.arrowRotation)
                }
                
                // Distance & Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.distanceText)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.directionColor)
                    
                    Text(viewModel.turnInstruction.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    
                    Text(viewModel.currentDirection.rawValue)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Alignment Indicator
            if viewModel.isAligned {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Aligned with destination")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Statistics (if available)
            if let stats = viewModel.statistics {
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 4)
                
                HStack(spacing: 20) {
                    statItem(
                        icon: "clock",
                        label: "Time",
                        value: stats.formattedElapsedTime()
                    )
                    
                    statItem(
                        icon: "gauge",
                        label: "Speed",
                        value: String(format: "%.1f m/s", stats.currentSpeed)
                    )
                    
                    statItem(
                        icon: "flag.checkered",
                        label: "Progress",
                        value: "\(stats.waypointsReached)/\(stats.pathLength)"
                    )
                }
                .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.85))
                .shadow(color: viewModel.directionColor.opacity(0.3), radius: 10)
        )
        .padding(.horizontal)
    }
    
    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Status Bar
            statusBar
            
            // Action Buttons
            actionButtons
            
            // Diagnostic Toggle (during navigation or map loaded)
            if viewModel.navigationState == .navigating ||
               viewModel.navigationState == .mapLoaded ||
               viewModel.navigationState == .pathCalculated {
                diagnosticToggleButton
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .shadow(radius: 10)
        )
        .padding()
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack {
            // Tracking Status
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // FPS Monitor (optional)
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
        }
    }
    
    private var statusColor: Color {
        if viewModel.isRelocalized {
            return .green
        } else if viewModel.relocalizationState == .scanning {
            return .yellow
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if viewModel.isRelocalized {
            return "Tracking"
        } else {
            switch viewModel.relocalizationState {
            case .notStarted:
                return "Starting..."
            case .scanning:
                return "Scanning environment..."
            case .limited:
                return "Limited tracking"
            case .mapped:
                return "Mapped"
            case .failed:
                return "Tracking lost"
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        Group {
            switch viewModel.navigationState {
            case .idle, .loadingMap:
                EmptyView()
                
            case .mapLoaded:
                // Select Destination
                Button {
                    showDestinationPicker = true
                } label: {
                    Label("Select Destination", systemImage: "mappin.and.ellipse")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
            case .selectingDestination:
                EmptyView()
                
            case .calculatingPath:
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Calculating path...")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            case .pathCalculated:
                VStack(spacing: 8) {
                    // Path Info
                    if let path = viewModel.currentPath {
                        HStack {
                            Label("\(path.path.count) waypoints", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Label(String(format: "%.1f meters", path.totalDistance), systemImage: "ruler")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Start Navigation Button
                    Button {
                        viewModel.startNavigation()
                    } label: {
                        Label("Start Navigation", systemImage: "location.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .green.opacity(0.3), radius: 8)
                    }
                }
                
            case .navigating:
                HStack(spacing: 12) {
                    // Stop Navigation
                    Button {
                        viewModel.resetNavigation()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Skip Waypoint (if close)
                    if viewModel.distanceToNextPoint < 2.0 {
                        Button {
                            viewModel.updateNavigation()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                        .transition(.scale)
                    }
                }
                
            case .destinationReached:
                Button {
                    viewModel.resetNavigation()
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
            case .error(let message):
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Button {
                        viewModel.clearAll()
                        viewModel.loadSelectedMap()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .animation(.spring(response: 0.3), value: viewModel.navigationState)
    }
    
    // MARK: - Diagnostic Toggle Button
    
    private var diagnosticToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showDiagnostics.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showDiagnostics ? "xmark.circle.fill" : "wrench.and.screwdriver.fill")
                    .font(.caption)
                
                Text(showDiagnostics ? "Hide Diagnostics" : "Fix Navigation Issues")
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(showDiagnostics ? Color.orange : Color.gray.opacity(0.6))
                    .overlay(
                        Capsule()
                            .stroke(showDiagnostics ? Color.orange : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
    
    // MARK: - Destination Picker Overlay
    
    private var destinationPickerOverlay: some View {
        ZStack {
            // Background Blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showDestinationPicker = false
                    }
                }
            
            // Picker Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Destination")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("\(viewModel.availableDestinations.count) locations available")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            showDestinationPicker = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                
                // Destination List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.availableDestinations) { destination in
                            destinationRow(destination)
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: 450, maxHeight: 600)
            .background(Color.black.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
            .padding()
        }
        .transition(.opacity)
    }
    
    private func destinationRow(_ destination: NavigationNode) -> some View {
        Button {
            withAnimation {
                viewModel.selectDestination(destination)
                viewModel.calculatePath()
                showDestinationPicker = false
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                iconForDestination(destination)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if case .beacon(let category) = destination.nodeType {
                        Text(category.capitalized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Distance from current position
                    if let currentPos = viewModel.getCurrentCameraPosition() {
                        let distance = simd_distance(currentPos, destination.position)
                        Text(String(format: "%.1f meters away", distance))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconForDestination(_ destination: NavigationNode) -> Image {
        if case .beacon(let category) = destination.nodeType {
            switch category.lowercased() {
            case "furniture":
                return Image(systemName: "sofa")
            case "landmark":
                return Image(systemName: "mappin")
            case "entrance", "door":
                return Image(systemName: "door.left.hand.open")
            default:
                return Image(systemName: "mappin.circle.fill")
            }
        }
        return Image(systemName: "mappin.circle.fill")
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Loading Map...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Please wait")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
            )
        }
    }
    
    // MARK: - Relocalization Overlay
    
    private var relocalizationOverlay: some View {
        RelocalizationProgressView(
            mappingStatus: viewModel.worldMappingStatus,
            onCancel: {
                viewModel.clearAll()
                dismiss()
            }
        )
    }
    
    // MARK: - Destination Reached Overlay
    
    private var destinationReachedOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Success Animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                }
                
                Text("Destination Reached!")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                if let destination = viewModel.getFinalDestination() {
                    Text(destination.name)
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                // Statistics
                if let stats = viewModel.statistics {
                    VStack(spacing: 8) {
                        statRow(icon: "clock", label: "Time", value: stats.formattedElapsedTime())
                        statRow(icon: "ruler", label: "Distance", value: String(format: "%.1f m", stats.totalDistance))
                        if stats.averageSpeed > 0 {
                            statRow(icon: "gauge", label: "Avg Speed", value: String(format: "%.1f m/s", stats.averageSpeed))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }
                
                // Done Button
                Button {
                    withAnimation {
                        viewModel.showDestinationReached = false
                        viewModel.resetNavigation()
                    }
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.95))
            )
            .padding()
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview
struct PathNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        PathNavigationView()
            .preferredColorScheme(.dark)
    }
}
