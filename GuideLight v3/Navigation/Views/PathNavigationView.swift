//
//  PathNavigationView.swift (FIND MY STYLE)
//  Main Navigation UI with Apple Find My Experience
//  UPDATED: Shows red pulsating marker on NEXT waypoint
//

import SwiftUI
import ARKit
import SceneKit

// MARK: - Enhanced Path Navigation View with Find My Style
struct PathNavigationView: View {
    @StateObject private var viewModel = PathNavigationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingDestinationPicker = false
    @State private var showingSettings = false
    @State private var pulseScale: CGFloat = 1.0
    @AppStorage("showDebugOverlay") private var showDebugOverlay = false
    
    var body: some View {
        ZStack {
            // AR Camera View (Full Screen)
            ARNavigationViewContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top Bar
                topBar
                
                Spacer()
                
                // Relocalization UI
                if viewModel.navigationState == .loadingMap &&
                   !viewModel.isRelocalized &&
                   viewModel.relocalizationState != .notStarted {
                    RelocalizationView(
                        state: viewModel.relocalizationState,
                        onRetry: { viewModel.loadSelectedMap() },
                        onCancel: { dismiss() }
                    )
                    .transition(.opacity)
                }
                
                // FIND MY STYLE COMPASS (Center of screen when navigating)
                if viewModel.navigationState == .navigating {
                    findMyCompass
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Navigation Info Card (when navigating)
                if viewModel.navigationState == .navigating {
                    navigationInfoCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Path calculated banner
                if viewModel.navigationState == .pathCalculated {
                    pathCalculatedBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Destination reached
                if viewModel.showDestinationReached {
                    destinationReachedBanner
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Bottom Controls
                bottomControls
            }
            .padding()
            
            // Debug Overlay
            if showDebugOverlay {
                DebugOverlay(viewModel: viewModel)
            }
            
            // Loading Overlay
            if viewModel.navigationState == .loadingMap ||
               viewModel.navigationState == .calculatingPath {
                loadingOverlay
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDestinationPicker) {
            destinationPickerSheet
        }
        .sheet(isPresented: $showingSettings) {
            navigationSettingsSheet
        }
        .onAppear {
            viewModel.startARSession()
            viewModel.loadSelectedMap()
            startPulseAnimation()
        }
        .onDisappear {
            viewModel.pauseARSession()
        }
        .alert("Error", isPresented: .constant(isError)) {
            Button("OK") {
                if case .error = viewModel.navigationState {
                    dismiss()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - FIND MY STYLE COMPASS (NEW!)
    private var findMyCompass: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 220, height: 220)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            // Directional arrow/cone
            DirectionalArrowShape()
                .fill(
                    LinearGradient(
                        colors: [
                            viewModel.directionColor.opacity(0.95),
                            viewModel.directionColor.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 70, height: 140)
                .shadow(color: viewModel.directionColor.opacity(0.8), radius: 25)
                .rotationEffect(.degrees(viewModel.arrowRotation))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.arrowRotation)
            
            // Center pulsing dot (your position)
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(Color.blue.opacity(0.6), lineWidth: 3)
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulseScale)
                    .opacity(2.5 - pulseScale)
                
                // Inner solid dot
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, .blue],
                            center: .center,
                            startRadius: 0,
                            endRadius: 12
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
            }
            
            // Distance text at top of compass
            VStack {
                Text(viewModel.distanceText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                
                Text("to waypoint")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .offset(y: -140)
            
            // Alignment indicator
            if viewModel.isAligned {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                        Text("Keep Going")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.green)
                            .shadow(color: .green.opacity(0.6), radius: 8)
                    )
                }
                .offset(y: 140)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Back Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            // Relocalization Status
            if viewModel.isRelocalized || viewModel.navigationState == .loadingMap {
                CompactRelocalizationIndicator(mappingStatus: viewModel.worldMappingStatus)
                    .transition(.opacity)
            }
            
            Spacer()
            
            // Destination Button
            if viewModel.navigationState == .mapLoaded ||
               viewModel.navigationState == .selectingDestination ||
               viewModel.navigationState == .navigating {
                Button {
                    showingDestinationPicker = true
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                        Text(viewModel.selectedDestination?.name ?? "Select Destination")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            
            Spacer()
            
            // Settings & Reset
            HStack(spacing: 12) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.3))
                        .clipShape(Circle())
                }
                
                if viewModel.navigationState == .navigating ||
                   viewModel.navigationState == .pathCalculated {
                    Button {
                        viewModel.resetNavigation()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Info Card
    private var navigationInfoCard: some View {
        VStack(spacing: 12) {
            if let nextPoint = viewModel.getNextTarget() {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next Waypoint")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(nextPoint.name)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.currentDirection.icon)
                                .font(.caption)
                            Text(viewModel.currentDirection.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                if let stats = viewModel.statistics {
                    Divider()
                        .background(.white.opacity(0.3))
                    
                    HStack {
                        StatItem(label: "Step", value: "\(viewModel.currentPathIndex + 1)/\(viewModel.currentPath?.path.count ?? 0)")
                        Spacer()
                        StatItem(label: "Progress", value: "\(Int(stats.progressPercentage))%")
                        Spacer()
                        StatItem(label: "ETA", value: stats.formattedETA())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10)
    }
    
    // MARK: - Path Calculated Banner
    private var pathCalculatedBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Route Ready")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            if let path = viewModel.currentPath {
                Text("\(path.path.count) waypoints • \(String(format: "%.0fm", path.totalDistance))")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Button {
                viewModel.startNavigation()
            } label: {
                Text("Start Navigation")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .shadow(radius: 10)
    }
    
    // MARK: - Destination Reached Banner
    private var destinationReachedBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            Text("You've Arrived!")
                .font(.title.weight(.bold))
                .foregroundColor(.white)
            
            if let destination = viewModel.selectedDestination {
                Text(destination.name)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            if let stats = viewModel.statistics {
                VStack(spacing: 4) {
                    Text("Time: \(stats.formattedElapsedTime())")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Distance: \(String(format: "%.1fm", stats.totalDistance))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(30)
        .background(
            LinearGradient(
                colors: [.green, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 15)
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Turn instruction (when navigating and not straight)
            if viewModel.navigationState == .navigating && viewModel.turnInstruction != .straight {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.turnInstruction.icon)
                        .font(.title2)
                        .foregroundColor(.yellow)
                    
                    Text(viewModel.turnInstruction.description)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.7))
                )
            }
            
            // Calculate Path Button
            if viewModel.navigationState == .selectingDestination {
                Button {
                    viewModel.calculatePath()
                } label: {
                    HStack {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                        Text("Calculate Route")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Arrived button (when close to waypoint)
            if viewModel.navigationState == .navigating &&
               viewModel.distanceToNextPoint < 2.0 {
                Button {
                    // Mark current waypoint as reached
                    if let currentPos = viewModel.getCurrentCameraPosition(),
                       let target = viewModel.getNextTarget() {
                        let distance = currentPos.distance(to: target.position)
                        if distance < 2.0 {
                            // This will trigger the waypoint reached logic
                            viewModel.updateNavigation()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("I've Arrived")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.green)
                            .shadow(color: .green.opacity(0.5), radius: 10)
                    )
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(loadingMessage)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var loadingMessage: String {
        switch viewModel.navigationState {
        case .loadingMap: return "Loading Map..."
        case .calculatingPath: return "Calculating Route..."
        default: return "Loading..."
        }
    }
    
    // MARK: - Destination Picker Sheet
    private var destinationPickerSheet: some View {
        NavigationView {
            List {
                if viewModel.availableDestinations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No destinations available")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(viewModel.availableDestinations) { destination in
                        Button {
                            viewModel.selectDestination(destination)
                            showingDestinationPicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(destination.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if case .beacon(let category) = destination.nodeType {
                                        Text(category.capitalized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let currentPos = viewModel.getCurrentCameraPosition() {
                                        let distance = currentPos.distance(to: destination.position)
                                        Text(String(format: "%.1fm away", distance))
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                if viewModel.selectedDestination?.id == destination.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDestinationPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Sheet
    private var navigationSettingsSheet: some View {
        NavigationView {
            Form {
                Section("Audio") {
                    Toggle("Audio Guidance", isOn: $viewModel.enableAudioGuidance)
                }
                
                Section("Haptics") {
                    Toggle("Haptic Feedback", isOn: $viewModel.enableHapticFeedback)
                }
                
                Section("Debug") {
                    Toggle("Show Debug Overlay", isOn: $showDebugOverlay)
                }
                
                Section("Performance") {
                    HStack {
                        Text("FPS")
                        Spacer()
                        Text(String(format: "%.0f", viewModel.currentFPS))
                            .foregroundColor(viewModel.isPerformanceGood ? .green : .orange)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Animation
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseScale = 2.2
        }
    }
    
    // MARK: - Helper Properties
    private var isError: Bool {
        if case .error = viewModel.navigationState { return true }
        return false
    }
    
    private var errorMessage: String {
        if case .error(let message) = viewModel.navigationState { return message }
        return ""
    }
}

// MARK: - Directional Arrow Shape (Cone/Pointer)
struct DirectionalArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create a cone/arrow pointing up
        path.move(to: CGPoint(x: width / 2, y: 0)) // Top point
        path.addLine(to: CGPoint(x: width, y: height * 0.65)) // Right side
        path.addLine(to: CGPoint(x: width / 2, y: height)) // Bottom center
        path.addLine(to: CGPoint(x: 0, y: height * 0.65)) // Left side
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - AR Navigation View Container (UPDATED)
struct ARNavigationViewContainer: UIViewRepresentable {
    let viewModel: PathNavigationViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session = viewModel.session
        arView.scene = SCNScene()
        arView.automaticallyUpdatesLighting = true
        
        context.coordinator.visualizer = ARPathVisualizer(sceneView: arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.updateVisualization(viewModel: viewModel)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var visualizer: ARPathVisualizer?
        
        func updateVisualization(viewModel: PathNavigationViewModel) {
            guard let visualizer = visualizer else { return }
            
            Task { @MainActor in
                switch viewModel.navigationState {
                case .navigating:
                    // UPDATED: Show red marker on NEXT waypoint (not final destination)
                    if let nextWaypoint = viewModel.getNextTarget() {
                        visualizer.updateNextWaypointMarker(at: nextWaypoint.position)
                    }
                    
                case .pathCalculated:
                    // When path is calculated, show marker on first waypoint
                    if let firstWaypoint = viewModel.getNextTarget() {
                        visualizer.updateNextWaypointMarker(at: firstWaypoint.position)
                    }
                    visualizer.clearArrow()
                    
                default:
                    visualizer.clearAll()
                }
            }
        }
    }
}

#Preview {
    PathNavigationView()
}
