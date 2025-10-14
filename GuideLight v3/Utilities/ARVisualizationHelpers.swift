//
//  ARVisualizationHelpers.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/12/25.
//


import Foundation
import ARKit
import SceneKit

// MARK: - AR Visualization Helpers
class ARVisualizationHelpers {
    
    // MARK: - Beacon Marker Creation
    
    /// Create pulsating AR marker for a beacon during calibration
    static func createBeaconMarker(beacon: Beacon, in sceneView: ARSCNView) -> SCNNode {
        let node = SCNNode()
        
        // 1. Pulsating sphere
        let sphere = SCNSphere(radius: 0.08)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        sphere.firstMaterial?.emission.contents = UIColor.cyan
        sphere.firstMaterial?.transparency = 0.9
        let sphereNode = SCNNode(geometry: sphere)
        node.addChildNode(sphereNode)
        
        // Pulsating animation
        let scaleUp = SCNAction.scale(to: 1.3, duration: 0.8)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.8)
        scaleDown.timingMode = .easeInEaseOut
        let pulse = SCNAction.sequence([scaleUp, scaleDown])
        sphereNode.runAction(SCNAction.repeatForever(pulse))
        
        // 2. Vertical line to floor (helps with depth perception)
        let lineHeight = beacon.position.y
        let line = SCNCylinder(radius: 0.01, height: CGFloat(abs(lineHeight)))
        line.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.5)
        let lineNode = SCNNode(geometry: line)
        lineNode.position = SCNVector3(0, -lineHeight / 2, 0)
        node.addChildNode(lineNode)
        
        // 3. Text label
        let textGeometry = SCNText(string: beacon.name, extrusionDepth: 0.01)
        textGeometry.font = UIFont.boldSystemFont(ofSize: 0.08)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        textGeometry.firstMaterial?.isDoubleSided = true
        let textNode = SCNNode(geometry: textGeometry)
        
        // Center text
        let (min, max) = textNode.boundingBox
        let textWidth = max.x - min.x
        textNode.position = SCNVector3(-textWidth / 2, 0.15, 0)
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        
        node.addChildNode(textNode)
        
        // 4. Distance label (will be updated)
        let distanceText = SCNText(string: "0.0m", extrusionDepth: 0.01)
        distanceText.font = UIFont.systemFont(ofSize: 0.06)
        distanceText.firstMaterial?.diffuse.contents = UIColor.white
        let distanceNode = SCNNode(geometry: distanceText)
        distanceNode.position = SCNVector3(-0.05, 0.22, 0)
        distanceNode.scale = SCNVector3(0.01, 0.01, 0.01)
        distanceNode.name = "distanceLabel"
        node.addChildNode(distanceNode)
        
        // Set position
        node.position = SCNVector3(beacon.position.x, beacon.position.y, beacon.position.z)
        
        return node
    }
    
    // MARK: - Waypoint Marker Creation
    
    /// Create AR marker for navigation waypoint
    static func createWaypointMarker(waypoint: NavigationWaypoint, isNext: Bool) -> SCNNode {
        let node = SCNNode()
        
        // Color based on type
        let color: UIColor
        switch waypoint.type {
        case .start:
            color = .green
        case .intermediate:
            color = .yellow
        case .doorway:
            color = .orange
        case .destination:
            color = .red
        }
        
        // Sphere marker
        let radius: CGFloat = isNext ? 0.12 : 0.08
        let sphere = SCNSphere(radius: radius)
        sphere.firstMaterial?.diffuse.contents = color
        sphere.firstMaterial?.emission.contents = color
        sphere.firstMaterial?.transparency = 0.8
        let sphereNode = SCNNode(geometry: sphere)
        node.addChildNode(sphereNode)
        
        // Pulsate only if it's the next waypoint
        if isNext {
            let scaleUp = SCNAction.scale(to: 1.4, duration: 0.6)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SCNAction.scale(to: 1.0, duration: 0.6)
            scaleDown.timingMode = .easeInEaseOut
            let pulse = SCNAction.sequence([scaleUp, scaleDown])
            sphereNode.runAction(SCNAction.repeatForever(pulse))
        }
        
        // Vertical line
        let lineHeight = waypoint.position.y
        let line = SCNCylinder(radius: 0.01, height: CGFloat(abs(lineHeight)))
        line.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.5)
        let lineNode = SCNNode(geometry: line)
        lineNode.position = SCNVector3(0, -lineHeight / 2, 0)
        node.addChildNode(lineNode)
        
        // Text label
        if isNext {
            let textGeometry = SCNText(string: waypoint.name, extrusionDepth: 0.01)
            textGeometry.font = UIFont.boldSystemFont(ofSize: 0.1)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white
            let textNode = SCNNode(geometry: textGeometry)
            
            let (min, max) = textNode.boundingBox
            let textWidth = max.x - min.x
            textNode.position = SCNVector3(-textWidth / 2, 0.2, 0)
            textNode.scale = SCNVector3(0.01, 0.01, 0.01)
            
            node.addChildNode(textNode)
        }
        
        node.position = SCNVector3(waypoint.position.x, waypoint.position.y, waypoint.position.z)
        
        return node
    }
    
    // MARK: - Crosshair Alignment
    
    /// Calculate how well the crosshair is aligned with a target node
    /// - Returns: Alignment value from 0.0 (poor) to 1.0 (perfect)
    static func calculateCrosshairAlignment(to targetNode: SCNNode, in sceneView: ARSCNView) -> Float {
        // Project 3D node position to 2D screen coordinates
        let screenPosition = sceneView.projectPoint(targetNode.position)
        
        // Get screen center (crosshair position)
        let screenCenter = CGPoint(
            x: sceneView.bounds.width / 2,
            y: sceneView.bounds.height / 2
        )
        
        // Calculate pixel distance
        let dx = screenPosition.x - Float(screenCenter.x)
        let dy = screenPosition.y - Float(screenCenter.y)
        let pixelDistance = sqrt(dx * dx + dy * dy)
        
        // Convert to alignment percentage
        // Perfect alignment (< 30 pixels) = 1.0
        // Poor alignment (> 150 pixels) = 0.0
        let maxDistance: Float = 150.0
        let minDistance: Float = 30.0
        
        if pixelDistance < minDistance {
            return 1.0
        } else if pixelDistance > maxDistance {
            return 0.0
        } else {
            return 1.0 - ((pixelDistance - minDistance) / (maxDistance - minDistance))
        }
    }
    
    /// Update marker appearance based on alignment
    static func updateMarkerAlignment(node: SCNNode, alignment: Float) {
        guard let sphereNode = node.childNodes.first,
              let sphere = sphereNode.geometry as? SCNSphere else {
            return
        }
        
        // Change color based on alignment
        let color: UIColor
        if alignment > 0.85 {
            color = .green  // Well aligned
        } else if alignment > 0.6 {
            color = .yellow  // Moderately aligned
        } else {
            color = .cyan  // Poorly aligned
        }
        
        sphere.firstMaterial?.diffuse.contents = color
        sphere.firstMaterial?.emission.contents = color
    }
    
    // MARK: - Distance Update
    
    /// Update distance label on a beacon marker
    static func updateDistanceLabel(on node: SCNNode, distance: Float) {
        guard let distanceNode = node.childNode(withName: "distanceLabel", recursively: true),
              let textGeometry = distanceNode.geometry as? SCNText else {
            return
        }
        
        let distanceString = String(format: "%.1fm", distance)
        textGeometry.string = distanceString
    }
    
    // MARK: - Billboard Effect
    
    /// Make node always face the camera (billboard effect)
    static func makeBillboard(node: SCNNode, camera: SCNNode) {
        node.constraints = [SCNBillboardConstraint()]
    }
}