import SwiftUI
import ARKit
import SceneKit

// MARK: - Build Map View
struct BuildMapView: View {
    @StateObject private var viewModel = BuildMapViewModel()
    @StateObject private var mapManager = MapManagerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingMapNameDialog = false
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // AR Camera View
                ARViewContainer(viewModel: viewModel)
                    .ignoresSafeArea()
                
                // Overlay UI
                VStack {
                    // Top Controls
                    topControlsView
                    
                    Spacer()
                    
                    // Crosshair
                    crosshairView
                    
                    Spacer()
                    
                    // Bottom Controls
                    bottomControlsView
                }
                .padding()
                
                // AR Session Status
                if viewModel.arSessionState != .running {
                    arSessionStatusView
                }
            }
            .navigationTitle("Build Map")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if viewModel.currentMap.name == "New Map" {
                            showingMapNameDialog = true
                        } else {
                            saveMap()
                        }
                    }
                    .disabled(viewModel.currentMap.beacons.isEmpty && viewModel.currentMap.doorways.isEmpty)
                }
            }
        }
        .alert("Name Your Map", isPresented: $showingMapNameDialog) {
            TextField("Map Name", text: $viewModel.tempItemName)
            Button("Cancel", role: .cancel) {
                viewModel.tempItemName = ""
            }
            Button("Save") {
                viewModel.updateMapName(viewModel.tempItemName)
                saveMap()
            }
        } message: {
            Text("Enter a name for your map")
        }
        .alert("Item Name", isPresented: $viewModel.showingNameDialog) {
            TextField(viewModel.placementMode == .beacon ? "Beacon Name" : "Doorway Name",
                     text: $viewModel.tempItemName)
            Button("Cancel", role: .cancel) {
                viewModel.cancelPlacement()
            }
            Button("Place") {
                if viewModel.placementMode == .beacon {
                    viewModel.confirmBeaconPlacement()
                } else {
                    viewModel.confirmDoorwayPlacement()
                }
            }
        } message: {
            Text("Enter a name for this \(viewModel.placementMode.displayName.lowercased())")
        }
        .alert("Map Saved", isPresented: $showingSaveConfirmation) {
            Button("Continue Editing") { }
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Your map has been saved successfully!")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.startARSession()
        }
        .onDisappear {
            viewModel.pauseARSession()
        }
    }
    
    // MARK: - Top Controls
    private var topControlsView: some View {
        HStack {
            // Map Info
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentMap.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(viewModel.currentMap.beacons.count) beacons, \(viewModel.currentMap.doorways.count) doorways")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Reset Button
            Button {
                viewModel.resetARSession()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Crosshair
    private var crosshairView: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 30, height: 30)
            
            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
            
            // Crosshair lines
            Rectangle()
                .fill(Color.white)
                .frame(width: 20, height: 1)
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 1, height: 20)
        }
        .shadow(color: .black, radius: 2)
    }
    
    // MARK: - Bottom Controls
    private var bottomControlsView: some View {
        VStack(spacing: 16) {
            // Placement Mode Selector
            placementModeSelector
            
            // Category/Type Selector
            if viewModel.placementMode == .beacon {
                beaconCategorySelector
            } else {
                doorwayTypeSelector
            }
            
            // Placement Instructions
            placementInstructions
            
            // Action Buttons
            HStack(spacing: 20) {
                // Clear Map
                Button {
                    viewModel.clearMap()
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                        .padding(12)
                        .background(.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .disabled(viewModel.currentMap.beacons.isEmpty && viewModel.currentMap.doorways.isEmpty)
                
                Spacer()
                
                // Cancel Doorway (if in progress)
                if viewModel.isPlacingDoorway {
                    Button("Cancel Doorway") {
                        viewModel.cancelPlacement()
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Placement Mode Selector
    private var placementModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(PlacementMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.setPlacementMode(mode)
                } label: {
                    HStack {
                        Image(systemName: mode.icon)
                        Text(mode.displayName)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(viewModel.placementMode == mode ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(viewModel.placementMode == mode ? .white : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(4)
        .background(.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Beacon Category Selector
    private var beaconCategorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BeaconCategory.allCases, id: \.self) { category in
                    Button {
                        viewModel.selectedBeaconCategory = category
                    } label: {
                        Text(category.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(viewModel.selectedBeaconCategory == category ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedBeaconCategory == category ? .white : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Doorway Type Selector
    private var doorwayTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DoorwayType.allCases, id: \.self) { type in
                    Button {
                        viewModel.selectedDoorwayType = type
                    } label: {
                        Text(type.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(viewModel.selectedDoorwayType == type ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedDoorwayType == type ? .white : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Placement Instructions
    private var placementInstructions: some View {
        VStack(spacing: 4) {
            if viewModel.placementMode == .beacon {
                Text("Tap to place beacon")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
                Text("Point at the floor and tap to place a \(viewModel.selectedBeaconCategory.displayName.lowercased()) beacon")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            } else {
                if viewModel.isPlacingDoorway {
                    Text("Tap second corner")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.orange)
                    
                    Text("Tap the other side of the doorway to complete")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.8))
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap first corner")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    
                    Text("Tap one side of the doorway opening")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    // MARK: - AR Session Status
    private var arSessionStatusView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text(viewModel.arSessionState.displayName)
                .font(.headline)
                .foregroundColor(.white)
            
            if case .starting = viewModel.arSessionState {
                Text("Move your device around to detect the floor")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Save Map
    private func saveMap() {
        Task {
            let success = await mapManager.saveMap(viewModel.currentMap)
            if success {
                showingSaveConfirmation = true
            }
        }
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    let viewModel: BuildMapViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session = viewModel.session
        arView.scene = SCNScene()
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.updateScene(uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
}

// MARK: - AR View Coordinator
extension ARViewContainer {
    class Coordinator: NSObject, ARSCNViewDelegate {
        let viewModel: BuildMapViewModel
        private var beaconNodes: [UUID: SCNNode] = [:]
        private var doorwayNodes: [UUID: SCNNode] = [:]
        private var previewNode: SCNNode?
        
        init(viewModel: BuildMapViewModel) {
            self.viewModel = viewModel
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = gesture.view as? ARSCNView else { return }
            let location = gesture.location(in: sceneView)
            
            Task { @MainActor in
                viewModel.handleTap(at: location, in: sceneView)
            }
        }
        
        func updateScene(_ sceneView: ARSCNView) {
            Task { @MainActor in
                // Update beacon nodes
                await updateBeaconNodes(sceneView)
                
                // Update doorway nodes
                await updateDoorwayNodes(sceneView)
                
                // Update preview for doorway placement
                await updateDoorwayPreview(sceneView)
            }
        }
        
        @MainActor
        private func updateBeaconNodes(_ sceneView: ARSCNView) async {
            // Remove nodes for deleted beacons
            let currentBeaconIds = Set(viewModel.currentMap.beacons.map { $0.id })
            for (id, node) in beaconNodes {
                if !currentBeaconIds.contains(id) {
                    node.removeFromParentNode()
                    beaconNodes.removeValue(forKey: id)
                }
            }
            
            // Add nodes for new beacons
            for beacon in viewModel.currentMap.beacons {
                if beaconNodes[beacon.id] == nil {
                    let node = createBeaconNode(for: beacon)
                    sceneView.scene.rootNode.addChildNode(node)
                    beaconNodes[beacon.id] = node
                }
            }
        }
        
        @MainActor
        private func updateDoorwayNodes(_ sceneView: ARSCNView) async {
            // Remove nodes for deleted doorways
            let currentDoorwayIds = Set(viewModel.currentMap.doorways.map { $0.id })
            for (id, node) in doorwayNodes {
                if !currentDoorwayIds.contains(id) {
                    node.removeFromParentNode()
                    doorwayNodes.removeValue(forKey: id)
                }
            }
            
            // Add nodes for new doorways
            for doorway in viewModel.currentMap.doorways {
                if doorwayNodes[doorway.id] == nil {
                    let node = createDoorwayNode(for: doorway)
                    sceneView.scene.rootNode.addChildNode(node)
                    doorwayNodes[doorway.id] = node
                }
            }
        }
        
        @MainActor
        private func updateDoorwayPreview(_ sceneView: ARSCNView) async {
            // Remove existing preview
            previewNode?.removeFromParentNode()
            previewNode = nil
            
            // Show preview line if placing doorway and have first point
            if viewModel.isPlacingDoorway, let firstPoint = viewModel.firstDoorwayPoint {
                // Create a preview line from first point to center of screen
                let centerPoint = sceneView.center
                if let raycastResult = sceneView.raycastQuery(from: centerPoint, allowing: .estimatedPlane, alignment: .horizontal) {
                    let results = sceneView.session.raycast(raycastResult)
                    if let result = results.first {
                        let secondPoint = result.worldTransform.translation
                        let previewLineNode = createPreviewDoorwayNode(from: firstPoint, to: secondPoint)
                        sceneView.scene.rootNode.addChildNode(previewLineNode)
                        previewNode = previewLineNode
                    }
                }
            }
        }
        
        private func createBeaconNode(for beacon: Beacon) -> SCNNode {
            let node = SCNNode()
            
            // Create flag pole
            let poleGeometry = SCNCylinder(radius: 0.01, height: 0.3)
            poleGeometry.firstMaterial?.diffuse.contents = UIColor.darkGray
            let poleNode = SCNNode(geometry: poleGeometry)
            poleNode.position = SCNVector3(0, 0.15, 0)
            node.addChildNode(poleNode)
            
            // Create flag
            let flagGeometry = SCNPlane(width: 0.15, height: 0.1)
            let color = beacon.category.color
            flagGeometry.firstMaterial?.diffuse.contents = UIColor(red: CGFloat(color.red),
                                                                  green: CGFloat(color.green),
                                                                  blue: CGFloat(color.blue),
                                                                  alpha: 0.8)
            let flagNode = SCNNode(geometry: flagGeometry)
            flagNode.position = SCNVector3(0.075, 0.25, 0)
            node.addChildNode(flagNode)
            
            // Add text label
            let textGeometry = SCNText(string: beacon.name, extrusionDepth: 0.01)
            textGeometry.font = UIFont.systemFont(ofSize: 0.05)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = SCNVector3(-0.05, 0.35, 0)
            textNode.scale = SCNVector3(0.002, 0.002, 0.002)
            node.addChildNode(textNode)
            
            // Set position
            node.position = SCNVector3(beacon.position.x, beacon.position.y, beacon.position.z)
            
            return node
        }
        
        private func createDoorwayNode(for doorway: Doorway) -> SCNNode {
            let node = SCNNode()
            
            // Create line geometry
            let start = doorway.startPoint
            let end = doorway.endPoint
            
            let lineGeometry = createLineGeometry(from: start, to: end)
            let color = doorway.doorwayType.color
            lineGeometry.firstMaterial?.diffuse.contents = UIColor(red: CGFloat(color.red),
                                                                  green: CGFloat(color.green),
                                                                  blue: CGFloat(color.blue),
                                                                  alpha: 0.9)
            
            let lineNode = SCNNode(geometry: lineGeometry)
            node.addChildNode(lineNode)
            
            // Add endpoint markers
            let startMarker = createEndpointMarker()
            startMarker.position = SCNVector3(start.x, start.y + 0.05, start.z)
            node.addChildNode(startMarker)
            
            let endMarker = createEndpointMarker()
            endMarker.position = SCNVector3(end.x, end.y + 0.05, end.z)
            node.addChildNode(endMarker)
            
            return node
        }
        
        private func createPreviewDoorwayNode(from start: simd_float3, to end: simd_float3) -> SCNNode {
            let node = SCNNode()
            
            let lineGeometry = createLineGeometry(from: start, to: end)
            lineGeometry.firstMaterial?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.7)
            
            let lineNode = SCNNode(geometry: lineGeometry)
            node.addChildNode(lineNode)
            
            return node
        }
        
        private func createLineGeometry(from start: simd_float3, to end: simd_float3) -> SCNGeometry {
            let vector = end - start
            let length = simd_length(vector)
            
            let cylinder = SCNCylinder(radius: 0.01, height: CGFloat(length))
            let node = SCNNode(geometry: cylinder)
            
            // Position and rotate the cylinder to form a line
            let midpoint = (start + end) / 2
            node.position = SCNVector3(midpoint.x, midpoint.y, midpoint.z)
            
            // Calculate rotation to align with line direction
            let direction = simd_normalize(vector)
            let up = simd_float3(0, 1, 0)
            let angle = acos(simd_dot(up, direction))
            let axis = simd_cross(up, direction)
            
            if simd_length(axis) > 0.001 {
                let normalizedAxis = simd_normalize(axis)
                node.rotation = SCNVector4(normalizedAxis.x, normalizedAxis.y, normalizedAxis.z, angle)
            }
            
            return cylinder
        }
        
        private func createEndpointMarker() -> SCNNode {
            let sphere = SCNSphere(radius: 0.02)
            sphere.firstMaterial?.diffuse.contents = UIColor.white
            return SCNNode(geometry: sphere)
        }
    }
}

#Preview {
    BuildMapView()
}
