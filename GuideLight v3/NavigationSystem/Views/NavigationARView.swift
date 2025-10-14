//
//  NavigationARView.swift
//  GuideLight v3
//
//  Final-destination pluck + yellow recolor + sparkle burst (one-shot, robust)
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
        
        // Ensure we are running a configuration
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
        
        private var lastUpdateTime: TimeInterval = 0
        private var didPlayArrivalEffect = false  // ✅ one-shot
        
        init(viewModel: NavigationViewModel) {
            self.viewModel = viewModel
        }
        
        // MARK: - Public: Update Markers
        func updateWaypointMarkers(in sceneView: ARSCNView) {
            DispatchQueue.main.async {
                
                // === Handle final ARRIVED first (so guard below doesn't remove nodes prematurely) ===
                if case .arrived = self.viewModel.navigationState {
                    // Reset separate destination node (we're done navigating)
                    self.destinationNode?.removeFromParentNode()
                    self.destinationNode = nil
                    
                    // Try to use the last waypoint node; if missing, create a temp node at destination
                    var hostNode = self.currentWaypointNode
                    if hostNode == nil, let dest = self.viewModel.destinationBeacon {
                        let temp = SCNNode()
                        temp.position = SCNVector3(dest.position.x, dest.position.y, dest.position.z)
                        sceneView.scene.rootNode.addChildNode(temp)
                        self.currentWaypointNode = temp
                        hostNode = temp
                    }
                    
                    // Run the one-shot effect if we haven’t yet
                    if !self.didPlayArrivalEffect, let node = hostNode {
                        self.didPlayArrivalEffect = true
                        self.runArrivalEffects(on: node)
                        
                        // Remove marker a bit later to leave time for the effect
                        let wait = SCNAction.wait(duration: 1.2)
                        let remove = SCNAction.run { _ in
                            node.removeFromParentNode()
                            self.currentWaypointNode = nil
                        }
                        node.runAction(SCNAction.sequence([wait, remove]))
                    }
                    
                    // Nothing else to update once arrived
                    return
                } else {
                    // Reset flag when not in arrived state
                    self.didPlayArrivalEffect = false
                }
                
                // === Normal update path (not arrived) ===
                guard let currentWaypoint = self.viewModel.currentWaypoint else {
                    // No current waypoint while not arrived: clear markers
                    self.currentWaypointNode?.removeFromParentNode()
                    self.currentWaypointNode = nil
                    self.destinationNode?.removeFromParentNode()
                    self.destinationNode = nil
                    return
                }
                
                // --- Update/Place Current Waypoint Node ---
                let wpTargetPos = SCNVector3(currentWaypoint.position.x,
                                             currentWaypoint.position.y,
                                             currentWaypoint.position.z)
                
                if self.currentWaypointNode == nil ||
                    !self.isSamePosition(self.currentWaypointNode!, wpTargetPos) {
                    self.currentWaypointNode?.removeFromParentNode()
                    let node = self.createWaypointMarker(for: currentWaypoint)
                    sceneView.scene.rootNode.addChildNode(node)
                    self.currentWaypointNode = node
                }
                
                // --- Destination Node (only show when not yet at final waypoint) ---
                if let path = self.viewModel.currentPath,
                   self.viewModel.currentWaypointIndex < path.waypoints.count - 1,
                   let dest = self.viewModel.destinationBeacon {
                    
                    if self.destinationNode == nil {
                        let node = self.createDestinationMarker(for: dest)
                        sceneView.scene.rootNode.addChildNode(node)
                        self.destinationNode = node
                    }
                } else {
                    // At final waypoint: remove separate destination marker
                    self.destinationNode?.removeFromParentNode()
                    self.destinationNode = nil
                }
            }
        }
        
        // MARK: - Run Arrival FX (pluck + recolor + sparkle)
        private func runArrivalEffects(on node: SCNNode) {
            // Recolor any sphere child to yellow
            if let sphereNode = node.childNodes.first(where: { $0.geometry is SCNSphere }),
               let sphere = sphereNode.geometry as? SCNSphere {
                let done = UIColor.systemYellow
                sphere.firstMaterial?.diffuse.contents = done
                sphere.firstMaterial?.emission.contents = done
            }
            
            // Pluck (scale pop)
            let popUp = SCNAction.scale(to: 1.5, duration: 0.18)
            popUp.timingMode = .easeOut
            let settle = SCNAction.scale(to: 1.0, duration: 0.22)
            settle.timingMode = .easeInEaseOut
            node.runAction(SCNAction.sequence([popUp, settle]))
            
            // ✨ Sparkle burst
            let sparkle = makeSparkleEmitter(color: .systemYellow)
            // Try to place near the top sphere if any, else slightly above origin
            if let top = node.childNodes.first(where: { $0.geometry is SCNSphere }) {
                sparkle.position = top.position
            } else {
                sparkle.position = SCNVector3(0, 0.7, 0)
            }
            node.addChildNode(sparkle)
            
            // Auto-remove the emitter after it finishes
            let wait = SCNAction.wait(duration: 1.0)
            let remove = SCNAction.run { _ in sparkle.removeFromParentNode() }
            sparkle.runAction(SCNAction.sequence([wait, remove]))
        }
        
        // MARK: - Helpers
        
        /// Position comparison with a small tolerance to avoid SCNVector3 Equatable issues
        private func isSamePosition(_ node: SCNNode, _ pos: SCNVector3, tol: Float = 0.001) -> Bool {
            let dx = node.position.x - pos.x
            let dy = node.position.y - pos.y
            let dz = node.position.z - pos.z
            return (dx*dx + dy*dy + dz*dz) <= (tol * tol)
        }
        
        /// Create visual marker for current waypoint (bright, prominent)
        private func createWaypointMarker(for waypoint: NavigationWaypoint) -> SCNNode {
            let node = SCNNode()
            node.position = SCNVector3(waypoint.position.x, waypoint.position.y, waypoint.position.z)
            
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
            
            // Pole
            let poleGeometry = SCNCylinder(radius: 0.03, height: 0.6)
            poleGeometry.firstMaterial?.diffuse.contents = color
            let poleNode = SCNNode(geometry: poleGeometry)
            poleNode.position = SCNVector3(0, 0.3, 0)
            node.addChildNode(poleNode)
            
            // Glowing sphere at top
            let sphereGeometry = SCNSphere(radius: 0.15)
            sphereGeometry.firstMaterial?.diffuse.contents = color
            sphereGeometry.firstMaterial?.emission.contents = color
            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.position = SCNVector3(0, 0.7, 0)
            node.addChildNode(sphereNode)
            
            // Pulse animation
            let scaleUp = SCNAction.scale(to: 1.3, duration: 0.8)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SCNAction.scale(to: 1.0, duration: 0.8)
            scaleDown.timingMode = .easeInEaseOut
            let pulse = SCNAction.sequence([scaleUp, scaleDown])
            sphereNode.runAction(SCNAction.repeatForever(pulse))
            
            // Label (waypoint name)
            let textNode = makeTextNode(string: waypoint.name,
                                        fontSize: 0.12,
                                        color: .white,
                                        emission: UIColor.white.withAlphaComponent(0.5))
            textNode.position = SCNVector3(-0.15, 0.9, 0)
            textNode.scale = SCNVector3(0.01, 0.01, 0.01)
            node.addChildNode(textNode)
            
            // "NEXT" badge
            let badgeNode = makeTextNode(string: "NEXT",
                                         fontSize: 0.10,
                                         color: .yellow,
                                         emission: .yellow)
            badgeNode.position = SCNVector3(-0.1, 1.1, 0)
            badgeNode.scale = SCNVector3(0.01, 0.01, 0.01)
            node.addChildNode(badgeNode)
            
            return node
        }
        
        /// Create visual marker for final destination (subtle, background)
        private func createDestinationMarker(for beacon: Beacon) -> SCNNode {
            let node = SCNNode()
            node.position = SCNVector3(beacon.position.x, beacon.position.y, beacon.position.z)
            
            // Subtle pole
            let poleGeometry = SCNCylinder(radius: 0.02, height: 0.4)
            poleGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.4)
            let poleNode = SCNNode(geometry: poleGeometry)
            poleNode.position = SCNVector3(0, 0.2, 0)
            node.addChildNode(poleNode)
            
            // Small sphere at top
            let sphereGeometry = SCNSphere(radius: 0.08)
            sphereGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.4)
            sphereGeometry.firstMaterial?.emission.contents = UIColor.systemGreen.withAlphaComponent(0.3)
            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.position = SCNVector3(0, 0.45, 0)
            node.addChildNode(sphereNode)
            
            // Label
            let textNode = makeTextNode(string: beacon.name,
                                        fontSize: 0.08,
                                        color: UIColor.white.withAlphaComponent(0.5),
                                        emission: UIColor.white.withAlphaComponent(0.0))
            textNode.position = SCNVector3(-0.1, 0.55, 0)
            textNode.scale = SCNVector3(0.01, 0.01, 0.01)
            node.addChildNode(textNode)
            
            return node
        }
        
        // MARK: - Text Helper
        private func makeTextNode(string: String,
                                  fontSize: CGFloat,
                                  color: UIColor,
                                  emission: UIColor) -> SCNNode {
            let textGeometry = SCNText(string: string, extrusionDepth: 0.02)
            textGeometry.font = UIFont.boldSystemFont(ofSize: fontSize)
            textGeometry.firstMaterial?.diffuse.contents = color
            textGeometry.firstMaterial?.emission.contents = emission
            let textNode = SCNNode(geometry: textGeometry)
            // Center text baseline roughly
            let (min, max) = textNode.boundingBox
            let dx = (max.x - min.x) * 0.5 + min.x
            textNode.pivot = SCNMatrix4MakeTranslation(dx, min.y, 0)
            return textNode
        }
        
        // MARK: - Sparkle Emitter (arrival effect)
        private func makeSparkleEmitter(color: UIColor = .systemYellow) -> SCNNode {
            let ps = SCNParticleSystem()
            ps.loops = false
            ps.emissionDuration = 0.25
            ps.birthRate = 1200
            ps.particleLifeSpan = 0.6
            ps.particleLifeSpanVariation = 0.25
            ps.particleSize = 0.008
            ps.particleSizeVariation = 0.004
            ps.particleColor = color
            ps.particleColorVariation = SCNVector4(0.1, 0.1, 0.1, 0.0)
            ps.blendMode = .additive
            ps.isAffectedByGravity = false
            ps.spreadingAngle = 180           // burst in all directions
            ps.birthLocation = .surface
            ps.birthDirection = .random
            ps.particleVelocity = 0.8
            ps.particleVelocityVariation = 0.4
            ps.acceleration = SCNVector3(0, 0.8, 0) // slight upward drift
            
            #if canImport(UIKit)
            if let img = UIImage(systemName: "sparkles",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .regular)) {
                ps.particleImage = img
            } else {
                ps.particleImage = UIImage() // default white quad
            }
            #endif
            
            ps.emitterShape = SCNSphere(radius: 0.05)
            
            let node = SCNNode()
            node.addParticleSystem(ps)
            return node
        }
        
        // MARK: - ARSCNViewDelegate
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // Throttle to ~10 Hz
            if time - lastUpdateTime < 0.1 { return }
            lastUpdateTime = time
            
            guard let sceneView = renderer as? ARSCNView else { return }
            updateWaypointMarkers(in: sceneView)
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
