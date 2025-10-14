//
//  NavigationARView.swift
//  GuideLight v3
//
//  Complete file with current waypoint marker display
//

import SwiftUI
import ARKit
import SceneKit

// MARK: - Navigation AR View Container
struct NavigationARView: UIViewRepresentable {
    @ObservedObject var viewModel: NavigationViewModel
    let session: ARSession
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session = session
        arView.scene = SCNScene()
        
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true
        
        if session.configuration == nil {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            session.run(configuration)
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.updateWaypointMarkers(in: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, ARSCNViewDelegate {
        let viewModel: NavigationViewModel
        private var currentWaypointNode: SCNNode?
        private var destinationNode: SCNNode?
        private var lastUpdateTime: Date?
        
        init(viewModel: NavigationViewModel) {
            self.viewModel = viewModel
        }
        
        /// Show both current waypoint and final destination
        func updateWaypointMarkers(in sceneView: ARSCNView) {
            Task { @MainActor in
                guard let currentWaypoint = viewModel.currentWaypoint,
                      let destination = viewModel.destinationBeacon else {
                    // Clear markers if no waypoint
                    currentWaypointNode?.removeFromParentNode()
                    currentWaypointNode = nil
                    destinationNode?.removeFromParentNode()
                    destinationNode = nil
                    return
                }
                
                // Update or create current waypoint marker
                if currentWaypointNode == nil ||
                   currentWaypointNode?.position != SCNVector3(currentWaypoint.position.x,
                                                               currentWaypoint.position.y,
                                                               currentWaypoint.position.z) {
                    currentWaypointNode?.removeFromParentNode()
                    let node = createWaypointMarker(for: currentWaypoint)
                    sceneView.scene.rootNode.addChildNode(node)
                    currentWaypointNode = node
                    
                    print("🎯 Updated current waypoint marker: \(currentWaypoint.name)")
                }
                
                // Show destination marker only if not at final waypoint
                let isAtFinalWaypoint = (viewModel.currentWaypointIndex >=
                                        (viewModel.currentPath?.waypoints.count ?? 0) - 1)
                
                if !isAtFinalWaypoint {
                    // Show faded destination marker in background
                    if destinationNode == nil {
                        let node = createDestinationMarker(for: destination)
                        sceneView.scene.rootNode.addChildNode(node)
                        destinationNode = node
                    }
                } else {
                    // At final waypoint - remove separate destination marker
                    destinationNode?.removeFromParentNode()
                    destinationNode = nil
                }
                
                await viewModel.updateNavigationProgress()
            }
        }
        
        /// Create visual marker for current waypoint (bright, prominent)
        private func createWaypointMarker(for waypoint: NavigationWaypoint) -> SCNNode {
            let node = SCNNode()
            node.position = SCNVector3(
                waypoint.position.x,
                waypoint.position.y,
                waypoint.position.z
            )
            
            // Color based on waypoint type
            let color: UIColor
            
            switch waypoint.type {
            case .doorway:
                color = .systemOrange
            case .destination:
                color = .systemGreen
            default:
                color = .systemBlue
            }
            
            // Create pole
            let poleGeometry = SCNCylinder(radius: 0.03, height: 0.6)
            poleGeometry.firstMaterial?.diffuse.contents = color
            let poleNode = SCNNode(geometry: poleGeometry)
            poleNode.position = SCNVector3(0, 0.3, 0)
            node.addChildNode(poleNode)
            
            // Create glowing sphere at top
            let sphereGeometry = SCNSphere(radius: 0.15)
            sphereGeometry.firstMaterial?.diffuse.contents = color
            sphereGeometry.firstMaterial?.emission.contents = color
            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.position = SCNVector3(0, 0.7, 0)
            node.addChildNode(sphereNode)
            
            // Add pulsing animation
            let scaleUp = SCNAction.scale(to: 1.3, duration: 0.8)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SCNAction.scale(to: 1.0, duration: 0.8)
            scaleDown.timingMode = .easeInEaseOut
            let pulse = SCNAction.sequence([scaleUp, scaleDown])
            sphereNode.runAction(SCNAction.repeatForever(pulse))
            
            // Create label with waypoint name
            let textGeometry = SCNText(string: waypoint.name, extrusionDepth: 0.02)
            textGeometry.font = UIFont.boldSystemFont(ofSize: 0.12)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white
            textGeometry.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.5)
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = SCNVector3(-0.15, 0.9, 0)
            textNode.scale = SCNVector3(0.01, 0.01, 0.01)
            node.addChildNode(textNode)
            
            // Add "NEXT" badge
            let badgeGeometry = SCNText(string: "NEXT", extrusionDepth: 0.01)
            badgeGeometry.font = UIFont.boldSystemFont(ofSize: 0.08)
            badgeGeometry.firstMaterial?.diffuse.contents = UIColor.yellow
            badgeGeometry.firstMaterial?.emission.contents = UIColor.yellow
            let badgeNode = SCNNode(geometry: badgeGeometry)
            badgeNode.position = SCNVector3(-0.1, 1.1, 0)
            badgeNode.scale = SCNVector3(0.01, 0.01, 0.01)
            node.addChildNode(badgeNode)
            
            return node
        }
        
        /// Create visual marker for final destination (subtle, background)
        private func createDestinationMarker(for beacon: Beacon) -> SCNNode {
            let node = SCNNode()
            node.position = SCNVector3(
                beacon.position.x,
                beacon.position.y,
                beacon.position.z
            )
            
            // Subtle pole (semi-transparent)
            let poleGeometry = SCNCylinder(radius: 0.02, height: 0.4)
            poleGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.4)
            let poleNode = SCNNode(geometry: poleGeometry)
            poleNode.position = SCNVector3(0, 0.2, 0)
            node.addChildNode(poleNode)
            
            // Small sphere at top (semi-transparent)
            let sphereGeometry = SCNSphere(radius: 0.08)
            sphereGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.4)
            sphereGeometry.firstMaterial?.emission.contents = UIColor.systemGreen.withAlphaComponent(0.3)
            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.position = SCNVector3(0, 0.45, 0)
            node.addChildNode(sphereNode)
            
            // Small label (semi-transparent)
            let textGeometry = SCNText(string: beacon.name, extrusionDepth: 0.01)
            textGeometry.font = UIFont.systemFont(ofSize: 0.08)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = SCNVector3(-0.1, 0.55, 0)
            textNode.scale = SCNVector3(0.01, 0.01, 0.01)
            node.addChildNode(textNode)
            
            return node
        }
        
        // MARK: - ARSCNViewDelegate
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let lastUpdate = lastUpdateTime,
                  Date().timeIntervalSince(lastUpdate) < 0.1 else {
                lastUpdateTime = Date()
                return
            }
            
            guard let sceneView = renderer as? ARSCNView else { return }
            
            DispatchQueue.main.async {
                self.updateWaypointMarkers(in: sceneView)
            }
        }
        
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            switch camera.trackingState {
            case .normal:
                break
            case .limited(let reason):
                print("⚠️ AR tracking limited: \(reason)")
            case .notAvailable:
                print("❌ AR tracking not available")
            @unknown default:
                break
            }
        }
        
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("❌ AR Session error: \(error.localizedDescription)")
        }
    }
}
