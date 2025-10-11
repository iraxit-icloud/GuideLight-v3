//
//  NavigationGraph.swift
//  Pathfinding Graph Construction (OPTIMIZED with Smart Virtual Node Support)
//  FIXED: Virtual node now respects room boundaries and MUST use doorways
//

import Foundation
import simd

// MARK: - Navigation Node
struct NavigationNode: Identifiable, Hashable, Equatable {
    let id: UUID
    let position: simd_float3
    let nodeType: NodeType
    let name: String
    let roomId: String
    
    enum NodeType: Equatable {
        case beacon(category: String)
        case waypoint
        case doorway(connectsRooms: (String, String))
        
        static func == (lhs: NodeType, rhs: NodeType) -> Bool {
            switch (lhs, rhs) {
            case (.beacon(let lhsCat), .beacon(let rhsCat)):
                return lhsCat == rhsCat
            case (.waypoint, .waypoint):
                return true
            case (.doorway(let lhsRooms), .doorway(let rhsRooms)):
                return lhsRooms.0 == rhsRooms.0 && lhsRooms.1 == rhsRooms.1
            default:
                return false
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NavigationNode, rhs: NavigationNode) -> Bool {
        return lhs.id == rhs.id
    }
    
    var isDestinationBeacon: Bool {
        if case .beacon = nodeType {
            return true
        }
        return false
    }
}

// MARK: - Navigation Edge
struct NavigationEdge {
    let from: UUID
    let to: UUID
    let weight: Float
    let edgeType: EdgeType
    
    enum EdgeType {
        case withinRoom
        case throughDoorway
        case toWaypoint
    }
}

// MARK: - Navigation Graph
class NavigationGraph {
    private(set) var nodes: [UUID: NavigationNode] = [:]
    private(set) var adjacencyList: [UUID: [NavigationEdge]] = [:]
    private(set) var roomNodes: [String: [UUID]] = [:]
    
    // Virtual node tracking
    private var virtualNodeId: UUID?
    private let virtualNodeMaxRadius: Float = 6.0 // Search up to 6 meters
    private let virtualNodeMaxConnections: Int = 3 // Connect to top 3 strategic nodes
    
    // MARK: - Build Graph from Map JSON
    func buildFromMapJSON(_ jsonData: [String: Any]) {
        print("🗺️ Building navigation graph from map JSON...")
        
        // Clear existing data
        nodes.removeAll()
        adjacencyList.removeAll()
        roomNodes.removeAll()
        
        // Extract data from JSON
        guard let beaconsData = jsonData["beacons"] as? [[String: Any]],
              let doorwaysData = jsonData["doorways"] as? [[String: Any]],
              let waypointsData = jsonData["waypoints"] as? [[String: Any]] else {
            print("❌ Failed to extract map data from JSON")
            return
        }
        
        // Add beacon nodes
        for beaconData in beaconsData {
            if let beaconNode = createBeaconNode(from: beaconData) {
                addNode(beaconNode)
            }
        }
        
        // Add waypoint nodes
        for waypointData in waypointsData {
            if let waypointNode = createWaypointNode(from: waypointData) {
                addNode(waypointNode)
            }
        }
        
        // Add doorway nodes
        for doorwayData in doorwaysData {
            if let doorwayNode = createDoorwayNode(from: doorwayData) {
                addNode(doorwayNode)
            }
        }
        
        // Build edges
        buildEdges()
        
        print("✅ Graph built successfully:")
        print("   Nodes: \(nodes.count)")
        print("   Edges: \(adjacencyList.values.map { $0.count }.reduce(0, +))")
        print("   Rooms: \(roomNodes.count)")
    }
    
    // MARK: - Create Nodes from JSON
    private func createBeaconNode(from data: [String: Any]) -> NavigationNode? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let roomId = data["roomId"] as? String,
              let category = data["category"] as? String,
              let coordinates = data["coordinates"] as? [String: Double] else {
            return nil
        }
        
        let position = simd_float3(
            Float(coordinates["x"] ?? 0),
            Float(coordinates["y"] ?? 0),
            Float(coordinates["z"] ?? 0)
        )
        
        return NavigationNode(
            id: id,
            position: position,
            nodeType: .beacon(category: category),
            name: name,
            roomId: roomId
        )
    }
    
    private func createWaypointNode(from data: [String: Any]) -> NavigationNode? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let roomId = data["roomId"] as? String,
              let coordinates = data["coordinates"] as? [String: Double] else {
            return nil
        }
        
        let position = simd_float3(
            Float(coordinates["x"] ?? 0),
            Float(coordinates["y"] ?? 0),
            Float(coordinates["z"] ?? 0)
        )
        
        return NavigationNode(
            id: id,
            position: position,
            nodeType: .waypoint,
            name: name,
            roomId: roomId
        )
    }
    
    private func createDoorwayNode(from data: [String: Any]) -> NavigationNode? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let position = data["position"] as? [String: Double],
              let connectsRooms = data["connectsRooms"] as? [String: String],
              let roomA = connectsRooms["roomA"],
              let roomB = connectsRooms["roomB"] else {
            return nil
        }
        
        let pos = simd_float3(
            Float(position["x"] ?? 0),
            Float(position["y"] ?? 0),
            Float(position["z"] ?? 0)
        )
        
        // Use roomA as primary room for doorway
        return NavigationNode(
            id: id,
            position: pos,
            nodeType: .doorway(connectsRooms: (roomA, roomB)),
            name: name,
            roomId: roomA
        )
    }
    
    // MARK: - Add Node
    private func addNode(_ node: NavigationNode) {
        nodes[node.id] = node
        adjacencyList[node.id] = []
        
        // Track nodes by room
        if roomNodes[node.roomId] == nil {
            roomNodes[node.roomId] = []
        }
        roomNodes[node.roomId]?.append(node.id)
    }
    
    // MARK: - Build Edges
    private func buildEdges() {
        // Connect nodes within the same room
        connectNodesWithinRooms()
        
        // Connect rooms via doorways
        connectRoomsViaDoorways()
    }
    
    private func connectNodesWithinRooms() {
        for (roomId, nodeIds) in roomNodes {
            let roomNodesList = nodeIds.compactMap { nodes[$0] }
            
            // Connect all nodes within the room to each other
            for i in 0..<roomNodesList.count {
                for j in (i+1)..<roomNodesList.count {
                    let nodeA = roomNodesList[i]
                    let nodeB = roomNodesList[j]
                    
                    // Skip if one is a doorway connecting to another room
                    if case .doorway = nodeA.nodeType, nodeA.roomId != roomId {
                        continue
                    }
                    if case .doorway = nodeB.nodeType, nodeB.roomId != roomId {
                        continue
                    }
                    
                    let distance = simd_distance(nodeA.position, nodeB.position)
                    
                    // Add bidirectional edges
                    addEdge(from: nodeA.id, to: nodeB.id, weight: distance, type: .withinRoom)
                    addEdge(from: nodeB.id, to: nodeA.id, weight: distance, type: .withinRoom)
                }
            }
        }
    }
    
    private func connectRoomsViaDoorways() {
        // Find all doorway nodes
        let doorwayNodes = nodes.values.filter {
            if case .doorway = $0.nodeType {
                return true
            }
            return false
        }
        
        for doorwayNode in doorwayNodes {
            guard case .doorway(let connectsRooms) = doorwayNode.nodeType else { continue }
            
            let (roomA, roomB) = connectsRooms
            
            // Connect doorway to all nodes in roomA
            if let roomANodes = roomNodes[roomA] {
                for nodeId in roomANodes {
                    guard let node = nodes[nodeId], nodeId != doorwayNode.id else { continue }
                    
                    let distance = simd_distance(doorwayNode.position, node.position)
                    let weight = distance * 1.2 // Slightly higher weight for doorway transitions
                    
                    addEdge(from: doorwayNode.id, to: nodeId, weight: weight, type: .throughDoorway)
                    addEdge(from: nodeId, to: doorwayNode.id, weight: weight, type: .throughDoorway)
                }
            }
            
            // Connect doorway to all nodes in roomB
            if let roomBNodes = roomNodes[roomB] {
                for nodeId in roomBNodes {
                    guard let node = nodes[nodeId], nodeId != doorwayNode.id else { continue }
                    
                    let distance = simd_distance(doorwayNode.position, node.position)
                    let weight = distance * 1.2
                    
                    addEdge(from: doorwayNode.id, to: nodeId, weight: weight, type: .throughDoorway)
                    addEdge(from: nodeId, to: doorwayNode.id, weight: weight, type: .throughDoorway)
                }
            }
        }
    }
    
    private func addEdge(from: UUID, to: UUID, weight: Float, type: NavigationEdge.EdgeType) {
        let edge = NavigationEdge(from: from, to: to, weight: weight, edgeType: type)
        adjacencyList[from, default: []].append(edge)
    }
    
    // MARK: - Query Methods
    func getNode(id: UUID) -> NavigationNode? {
        return nodes[id]
    }
    
    func getNeighbors(of nodeId: UUID) -> [(node: NavigationNode, weight: Float)] {
        guard let edges = adjacencyList[nodeId] else { return [] }
        
        return edges.compactMap { edge in
            guard let node = nodes[edge.to] else { return nil }
            return (node, edge.weight)
        }
    }
    
    func getAllBeaconNodes() -> [NavigationNode] {
        return nodes.values.filter { $0.isDestinationBeacon }.sorted { $0.name < $1.name }
    }
    
    func findNearestNode(to position: simd_float3) -> NavigationNode? {
        var nearest: NavigationNode?
        var minDistance: Float = .infinity
        
        for node in nodes.values {
            let distance = simd_distance(position, node.position)
            if distance < minDistance {
                minDistance = distance
                nearest = node
            }
        }
        
        return nearest
    }
    
    func distance(from: UUID, to: UUID) -> Float {
        guard let nodeA = nodes[from], let nodeB = nodes[to] else {
            return .infinity
        }
        return simd_distance(nodeA.position, nodeB.position)
    }
    
    // MARK: - Virtual Node Management (FIXED)
    
    /// Creates a temporary virtual node at the given position and connects it to nearby nodes
    /// FIXED: Now respects room boundaries - only connects to same-room nodes or doorways
    /// Returns the ID of the virtual node
    func addVirtualStartNode(at position: simd_float3) -> UUID {
        // Remove any existing virtual node first
        removeVirtualStartNode()
        
        print("🎯 Creating virtual start node at \(position.debugDescription)")
        
        // Determine which room the virtual node is in
        let startRoom = findNearestRoom(to: position) ?? "unknown"
        print("   Detected start room: \(startRoom)")
        
        // Create virtual node
        let virtualId = UUID()
        let virtualNode = NavigationNode(
            id: virtualId,
            position: position,
            nodeType: .waypoint, // Treat as waypoint
            name: "Start Position",
            roomId: startRoom
        )
        
        // Add to graph
        nodes[virtualId] = virtualNode
        adjacencyList[virtualId] = []
        virtualNodeId = virtualId
        
        // FIXED: Connect with room boundary enforcement
        connectVirtualNodeWithRoomBoundaries(virtualId: virtualId, position: position, startRoom: startRoom)
        
        print("✅ Virtual start node created and connected")
        return virtualId
    }
    
    /// Removes the virtual start node from the graph
    func removeVirtualStartNode() {
        guard let virtualId = virtualNodeId else { return }
        
        print("🗑️ Removing virtual start node")
        
        // Remove from nodes
        nodes.removeValue(forKey: virtualId)
        
        // Remove from adjacency list
        adjacencyList.removeValue(forKey: virtualId)
        
        // Remove edges pointing to this virtual node from other nodes
        for nodeId in adjacencyList.keys {
            adjacencyList[nodeId]?.removeAll { edge in
                edge.to == virtualId
            }
        }
        
        virtualNodeId = nil
        print("✅ Virtual start node removed")
    }
    
    // MARK: - FIXED: Virtual Node Connection with Room Boundary Enforcement
    
    /// Connects the virtual node ONLY to nodes in the same room OR doorways leading out
    /// This ensures paths MUST go through doorways to reach other rooms
    private func connectVirtualNodeWithRoomBoundaries(virtualId: UUID, position: simd_float3, startRoom: String) {
        
        print("   🔍 Searching for connection candidates with room boundary enforcement...")
        
        // Separate candidates into two categories
        var sameRoomCandidates: [(node: NavigationNode, distance: Float, score: Float)] = []
        var doorwayCandidates: [(node: NavigationNode, distance: Float, score: Float)] = []
        
        for (nodeId, node) in nodes {
            // Skip self
            if nodeId == virtualId { continue }
            
            let distance = simd_distance(position, node.position)
            
            // Only consider nodes within max radius
            guard distance <= virtualNodeMaxRadius else { continue }
            
            // Check node type and room
            if case .doorway(let connectsRooms) = node.nodeType {
                // DOORWAYS: Only include if they connect FROM our start room
                let (roomA, roomB) = connectsRooms
                
                if roomA == startRoom || roomB == startRoom {
                    let score = calculateDoorwayScore(distance: distance, sameRoom: roomA == startRoom)
                    doorwayCandidates.append((node: node, distance: distance, score: score))
                    print("      Found doorway: \(node.name) at \(String(format: "%.2fm", distance)) (connects \(roomA) ↔ \(roomB))")
                }
            } else {
                // NON-DOORWAYS: Only include if in SAME room as start
                if node.roomId == startRoom {
                    let score = calculateSameRoomScore(node: node, distance: distance)
                    sameRoomCandidates.append((node: node, distance: distance, score: score))
                    
                    let nodeType = nodeTypeDescription(node.nodeType)
                    print("      Found same-room node: \(node.name) (\(nodeType)) at \(String(format: "%.2fm", distance))")
                } else {
                    // CRITICAL: Skip nodes in OTHER rooms (no cross-room connections!)
                    print("      ⏭️  Skipping \(node.name) (different room: \(node.roomId))")
                }
            }
        }
        
        print("   📊 Candidates found: \(sameRoomCandidates.count) same-room, \(doorwayCandidates.count) doorways")
        
        // Combine and sort by score
        var allCandidates = sameRoomCandidates + doorwayCandidates
        allCandidates.sort { $0.score > $1.score }
        
        // Connect to top N candidates
        let connectionsToMake = min(virtualNodeMaxConnections, allCandidates.count)
        
        if connectionsToMake > 0 {
            print("   ✅ Connecting to \(connectionsToMake) strategic nodes:")
            
            for i in 0..<connectionsToMake {
                let candidate = allCandidates[i]
                let nodeType = nodeTypeDescription(candidate.node.nodeType)
                
                // Add bidirectional edges
                addEdge(from: virtualId, to: candidate.node.id, weight: candidate.distance, type: .toWaypoint)
                addEdge(from: candidate.node.id, to: virtualId, weight: candidate.distance, type: .toWaypoint)
                
                print("      \(i+1). \(candidate.node.name) (\(nodeType)): \(String(format: "%.2fm", candidate.distance)) [score: \(String(format: "%.0f", candidate.score))]")
            }
        } else {
            // Fallback: connect to absolute nearest node (emergency only)
            print("   ⚠️ No candidates within radius, connecting to nearest node (fallback)")
            if let nearestNode = findNearestNode(to: position) {
                let distance = simd_distance(position, nearestNode.position)
                addEdge(from: virtualId, to: nearestNode.id, weight: distance, type: .toWaypoint)
                addEdge(from: nearestNode.id, to: virtualId, weight: distance, type: .toWaypoint)
                print("   Connected to: \(nearestNode.name) at \(String(format: "%.2f", distance))m")
            }
        }
    }
    
    /// Calculate score for same-room nodes (non-doorways)
    private func calculateSameRoomScore(node: NavigationNode, distance: Float) -> Float {
        var score: Float = 0
        
        // 1. Base distance penalty (closer is better)
        let distanceScore = max(0, 100 - (distance * 15))
        score += distanceScore
        
        // 2. Node type priority (same room only, so no doorway here)
        switch node.nodeType {
        case .waypoint:
            score += 150 // High priority for waypoints
            
        case .beacon(let category):
            if category == "destination" {
                score += 100 // Destination beacons
            } else if category == "furniture" || category == "obstacle" {
                // Discourage furniture unless very close
                if distance > 2.0 {
                    score -= 100
                } else {
                    score += 20
                }
            } else {
                score += 50 // Other beacon types
            }
            
        case .doorway:
            // Should not happen in same-room candidates
            score += 0
        }
        
        return score
    }
    
    /// Calculate score for doorways
    private func calculateDoorwayScore(distance: Float, sameRoom: Bool) -> Float {
        var score: Float = 0
        
        // 1. Base distance penalty
        let distanceScore = max(0, 100 - (distance * 15))
        score += distanceScore
        
        // 2. VERY HIGH priority for doorways (they are exits from the room)
        score += 400
        
        // 3. Extra bonus if it's the primary room for this doorway
        if sameRoom {
            score += 100 // Total: 500+ for doorways in our room
        }
        
        return score
    }
    
    /// Helper to get readable node type description
    private func nodeTypeDescription(_ nodeType: NavigationNode.NodeType) -> String {
        switch nodeType {
        case .doorway:
            return "Doorway"
        case .waypoint:
            return "Waypoint"
        case .beacon(let category):
            return "Beacon (\(category))"
        }
    }
    
    /// Finds the nearest room to a position (for virtual node room assignment)
    private func findNearestRoom(to position: simd_float3) -> String? {
        var nearestRoom: String?
        var minDistance: Float = .infinity
        
        for (roomId, nodeIds) in roomNodes {
            for nodeId in nodeIds {
                guard let node = nodes[nodeId] else { continue }
                let distance = simd_distance(position, node.position)
                
                if distance < minDistance {
                    minDistance = distance
                    nearestRoom = roomId
                }
            }
        }
        
        return nearestRoom
    }
    
    /// Check if a node is the virtual start node
    func isVirtualNode(_ nodeId: UUID) -> Bool {
        return nodeId == virtualNodeId
    }
}
