//
//  ARPathVisualization.swift
//  AR Arrow and Destination Rendering
//  UPDATED: Shows pulsating red marker on NEXT waypoint
//

import ARKit
import SceneKit
import simd

// MARK: - AR Path Visualizer
class ARPathVisualizer {
    
    private weak var sceneView: ARSCNView?
    private var arrowNode: SCNNode?
    private var waypointMarkerNode: SCNNode? // Changed from destinationNode
    private var pathLineNodes: [SCNNode] = []
    
    // Colors
    private let arrowColor = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.9) // Bright green
    private let waypointMarkerColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.95) // Bright red
    
    init(sceneView: ARSCNView) {
        self.sceneView = sceneView
    }
    
    // MARK: - Update Arrow
    func updateArrow(at position: simd_float3, pointingTo direction: simd_float3, distance: Float) {
        guard let sceneView = sceneView else { return }
        
        // Remove old arrow
        arrowNode?.removeFromParentNode()
        
        // Create new arrow
        let arrow = createArrow(color: arrowColor)
        
        // Position arrow on ground, slightly offset from user
        let arrowPosition = position + direction * 0.5 // 0.5m ahead
        arrow.position = SCNVector3(arrowPosition.x, position.y - 0.3, arrowPosition.z) // Lower to ground
        
        // Calculate rotation to point in direction
        let angle = atan2(direction.x, direction.z)
        arrow.eulerAngles = SCNVector3(0, -angle, 0)
        
        // Add pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "scale")
        pulseAnimation.fromValue = SCNVector3(1.0, 1.0, 1.0)
        pulseAnimation.toValue = SCNVector3(1.2, 1.2, 1.2)
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        arrow.addAnimation(pulseAnimation, forKey: "pulse")
        
        sceneView.scene.rootNode.addChildNode(arrow)
        arrowNode = arrow
        
        // Add distance text above arrow
        if distance > 0 {
            let textNode = createDistanceText(distance: distance)
            textNode.position = SCNVector3(0, 0.3, 0) // Above arrow
            arrow.addChildNode(textNode)
        }
    }
    
    // MARK: - Update Next Waypoint Marker (RED PULSATING DROP)
    /// Shows a pulsating red marker at the NEXT waypoint position
    func updateNextWaypointMarker(at position: simd_float3) {
        guard let sceneView = sceneView else { return }
        
        // Remove old marker
        waypointMarkerNode?.removeFromParentNode()
        
        // Create red pulsating drop/circle marker
        let marker = createWaypointMarker(color: waypointMarkerColor)
        marker.position = SCNVector3(position.x, position.y, position.z)
        
        // Add STRONG pulsing animation (more pronounced)
        let pulseAnimation = CABasicAnimation(keyPath: "scale")
        pulseAnimation.fromValue = SCNVector3(0.8, 0.8, 0.8)
        pulseAnimation.toValue = SCNVector3(1.3, 1.3, 1.3)
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        marker.addAnimation(pulseAnimation, forKey: "pulse")
        
        // Add glow/opacity pulsing
        let glowAnimation = CABasicAnimation(keyPath: "opacity")
        glowAnimation.fromValue = 0.7
        glowAnimation.toValue = 1.0
        glowAnimation.duration = 0.8
        glowAnimation.autoreverses = true
        glowAnimation.repeatCount = .infinity
        marker.addAnimation(glowAnimation, forKey: "glow")
        
        sceneView.scene.rootNode.addChildNode(marker)
        waypointMarkerNode = marker
    }
    
    // MARK: - Clear Visualizations
    func clearArrow() {
        arrowNode?.removeFromParentNode()
        arrowNode = nil
    }
    
    func clearWaypointMarker() {
        waypointMarkerNode?.removeFromParentNode()
        waypointMarkerNode = nil
    }
    
    func clearAll() {
        clearArrow()
        clearWaypointMarker()
        clearPathLines()
    }
    
    func clearPathLines() {
        pathLineNodes.forEach { $0.removeFromParentNode() }
        pathLineNodes.removeAll()
    }
    
    // MARK: - Create Arrow Geometry
    private func createArrow(color: UIColor) -> SCNNode {
        let arrowNode = SCNNode()
        
        // Arrow shaft (cylinder)
        let shaftGeometry = SCNCylinder(radius: 0.03, height: 0.4)
        shaftGeometry.firstMaterial?.diffuse.contents = color
        shaftGeometry.firstMaterial?.emission.contents = color.withAlphaComponent(0.3)
        let shaftNode = SCNNode(geometry: shaftGeometry)
        shaftNode.position = SCNVector3(0, 0.2, 0)
        shaftNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0) // Point up
        arrowNode.addChildNode(shaftNode)
        
        // Arrow head (cone)
        let headGeometry = SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.2)
        headGeometry.firstMaterial?.diffuse.contents = color
        headGeometry.firstMaterial?.emission.contents = color.withAlphaComponent(0.3)
        let headNode = SCNNode(geometry: headGeometry)
        headNode.position = SCNVector3(0, 0.5, 0)
        headNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        arrowNode.addChildNode(headNode)
        
        // Add base circle for better visibility
        let baseGeometry = SCNCylinder(radius: 0.08, height: 0.02)
        baseGeometry.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.5)
        let baseNode = SCNNode(geometry: baseGeometry)
        baseNode.position = SCNVector3(0, 0.01, 0)
        arrowNode.addChildNode(baseNode)
        
        return arrowNode
    }
    
    // MARK: - Create Waypoint Marker (RED DROP/CIRCLE)
    private func createWaypointMarker(color: UIColor) -> SCNNode {
        let markerNode = SCNNode()
        
        // Main drop shape (sphere slightly elongated)
        let dropGeometry = SCNSphere(radius: 0.2)
        dropGeometry.firstMaterial?.diffuse.contents = color
        dropGeometry.firstMaterial?.emission.contents = color.withAlphaComponent(0.6)
        dropGeometry.firstMaterial?.transparency = 0.95
        
        let dropNode = SCNNode(geometry: dropGeometry)
        dropNode.scale = SCNVector3(1.0, 1.2, 1.0) // Slightly elongate for drop shape
        markerNode.addChildNode(dropNode)
        
        // Outer glow ring (larger, more transparent)
        let glowGeometry = SCNSphere(radius: 0.35)
        glowGeometry.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.3)
        glowGeometry.firstMaterial?.emission.contents = color.withAlphaComponent(0.4)
        
        let glowNode = SCNNode(geometry: glowGeometry)
        markerNode.addChildNode(glowNode)
        
        // Inner bright core
        let coreGeometry = SCNSphere(radius: 0.1)
        coreGeometry.firstMaterial?.diffuse.contents = UIColor.white
        coreGeometry.firstMaterial?.emission.contents = color
        
        let coreNode = SCNNode(geometry: coreGeometry)
        markerNode.addChildNode(coreNode)
        
        // Add rotating ring around the marker
        let ringGeometry = SCNTorus(ringRadius: 0.25, pipeRadius: 0.03)
        ringGeometry.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.8)
        ringGeometry.firstMaterial?.emission.contents = color.withAlphaComponent(0.5)
        
        let ringNode = SCNNode(geometry: ringGeometry)
        ringNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        markerNode.addChildNode(ringNode)
        
        // Rotate ring continuously
        let rotateAnimation = CABasicAnimation(keyPath: "rotation")
        rotateAnimation.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Float.pi * 2))
        rotateAnimation.duration = 2.0
        rotateAnimation.repeatCount = .infinity
        ringNode.addAnimation(rotateAnimation, forKey: "rotate")
        
        return markerNode
    }
    
    // MARK: - Create Distance Text
    private func createDistanceText(distance: Float) -> SCNNode {
        let text = SCNText(string: String(format: "%.1fm", distance), extrusionDepth: 0.01)
        text.font = UIFont.systemFont(ofSize: 0.1, weight: .bold)
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.8)
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        
        let textNode = SCNNode(geometry: text)
        
        // Center the text
        let (min, max) = textNode.boundingBox
        let width = max.x - min.x
        textNode.pivot = SCNMatrix4MakeTranslation(width / 2, 0, 0)
        
        // Scale down
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)
        
        return textNode
    }
    
    // MARK: - Draw Full Path (Optional - for debugging)
    func drawFullPath(_ path: [NavigationNode]) {
        clearPathLines()
        
        guard let sceneView = sceneView, path.count > 1 else { return }
        
        for i in 0..<(path.count - 1) {
            let start = path[i].position
            let end = path[i + 1].position
            
            let lineNode = createLine(from: start, to: end, color: UIColor.cyan.withAlphaComponent(0.5))
            sceneView.scene.rootNode.addChildNode(lineNode)
            pathLineNodes.append(lineNode)
        }
    }
    
    private func createLine(from start: simd_float3, to end: simd_float3, color: UIColor) -> SCNNode {
        let vector = end - start
        let distance = simd_length(vector)
        
        let cylinder = SCNCylinder(radius: 0.01, height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = color
        
        let lineNode = SCNNode(geometry: cylinder)
        lineNode.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        
        // Calculate rotation
        let direction = simd_normalize(vector)
        let up = simd_float3(0, 1, 0)
        let cross = simd_cross(up, direction)
        let dot = simd_dot(up, direction)
        let angle = acos(dot)
        
        if simd_length(cross) > 0.001 {
            let axis = simd_normalize(cross)
            lineNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }
        
        return lineNode
    }
}
