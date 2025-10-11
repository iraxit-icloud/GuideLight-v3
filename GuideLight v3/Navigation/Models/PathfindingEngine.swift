//
//  PathResult.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/9/25.
//


//
//  PathfindingEngine.swift
//  A* Pathfinding Algorithm (UPDATED with Virtual Start Node Support)
//

import Foundation
import simd

// MARK: - Path Result
struct PathResult {
    let path: [NavigationNode]
    let totalDistance: Float
    let pathJSON: [String: Any]
    
    var isEmpty: Bool {
        return path.isEmpty
    }
}

// MARK: - Priority Queue for A*
private struct PriorityQueueElement<T>: Comparable {
    let priority: Float
    let element: T
    
    static func < (lhs: PriorityQueueElement<T>, rhs: PriorityQueueElement<T>) -> Bool {
        return lhs.priority < rhs.priority
    }
    
    static func == (lhs: PriorityQueueElement<T>, rhs: PriorityQueueElement<T>) -> Bool {
        return lhs.priority == rhs.priority
    }
}

private class PriorityQueue<T> {
    private var heap: [PriorityQueueElement<T>] = []
    
    var isEmpty: Bool {
        return heap.isEmpty
    }
    
    var count: Int {
        return heap.count
    }
    
    func enqueue(element: T, priority: Float) {
        let queueElement = PriorityQueueElement(priority: priority, element: element)
        heap.append(queueElement)
        heapifyUp(from: heap.count - 1)
    }
    
    func dequeue() -> (element: T, priority: Float)? {
        guard !heap.isEmpty else { return nil }
        
        if heap.count == 1 {
            let element = heap.removeFirst()
            return (element.element, element.priority)
        }
        
        let result = heap[0]
        heap[0] = heap.removeLast()
        heapifyDown(from: 0)
        
        return (result.element, result.priority)
    }
    
    private func heapifyUp(from index: Int) {
        var childIndex = index
        let child = heap[childIndex]
        var parentIndex = (childIndex - 1) / 2
        
        while childIndex > 0 && child < heap[parentIndex] {
            heap[childIndex] = heap[parentIndex]
            childIndex = parentIndex
            parentIndex = (childIndex - 1) / 2
        }
        
        heap[childIndex] = child
    }
    
    private func heapifyDown(from index: Int) {
        let count = heap.count
        let element = heap[index]
        var parentIndex = index
        
        while true {
            let leftChildIndex = 2 * parentIndex + 1
            let rightChildIndex = 2 * parentIndex + 2
            var minIndex = parentIndex
            
            if leftChildIndex < count && heap[leftChildIndex] < heap[minIndex] {
                minIndex = leftChildIndex
            }
            
            if rightChildIndex < count && heap[rightChildIndex] < heap[minIndex] {
                minIndex = rightChildIndex
            }
            
            if minIndex == parentIndex {
                break
            }
            
            heap[parentIndex] = heap[minIndex]
            parentIndex = minIndex
        }
        
        heap[parentIndex] = element
    }
}

// MARK: - Pathfinding Engine
class PathfindingEngine {
    private let graph: NavigationGraph
    
    init(graph: NavigationGraph) {
        self.graph = graph
    }
    
    // MARK: - A* Algorithm with Virtual Start Node
    func findPath(from startPosition: simd_float3, to destinationId: UUID) -> PathResult? {
        print("🔍 Starting A* pathfinding with virtual start node...")
        print("   Destination: \(graph.getNode(id: destinationId)?.name ?? "Unknown")")
        print("   Start position: \(startPosition.debugDescription)")
        
        guard graph.getNode(id: destinationId) != nil else {
            print("❌ Destination node not found")
            return nil
        }
        
        // STEP 1: Create virtual start node at user's actual position
        let virtualStartId = graph.addVirtualStartNode(at: startPosition)
        
        // Ensure cleanup happens even if pathfinding fails
        defer {
            graph.removeVirtualStartNode()
        }
        
        print("   Virtual start node created: \(virtualStartId)")
        
        // STEP 2: Run A* from virtual start node to destination
        guard let pathFromVirtual = runAStar(from: virtualStartId, to: destinationId) else {
            print("❌ No path found from virtual start node")
            return nil
        }
        
        print("✅ Path found!")
        print("   Path length: \(pathFromVirtual.count) nodes")
        
        // STEP 3: The path already includes the virtual start node with user's actual position
        let totalDistance = calculatePathDistance(pathFromVirtual)
        print("   Total distance: \(String(format: "%.2f", totalDistance))m")
        
        // Generate path JSON
        let pathJSON = generatePathJSON(path: pathFromVirtual, totalDistance: totalDistance)
        
        return PathResult(path: pathFromVirtual, totalDistance: totalDistance, pathJSON: pathJSON)
    }
    
    // MARK: - A* Core Algorithm (extracted for clarity)
    private func runAStar(from startId: UUID, to destinationId: UUID) -> [NavigationNode]? {
        guard let startNode = graph.getNode(id: startId),
              let destinationNode = graph.getNode(id: destinationId) else {
            return nil
        }
        
        // A* data structures
        let openSet = PriorityQueue<UUID>()
        var cameFrom: [UUID: UUID] = [:]
        var gScore: [UUID: Float] = [:]
        var fScore: [UUID: Float] = [:]
        var closedSet: Set<UUID> = []
        
        // Initialize scores
        gScore[startId] = 0
        fScore[startId] = heuristic(from: startNode.position, to: destinationNode.position)
        openSet.enqueue(element: startId, priority: fScore[startId]!)
        
        var nodesExplored = 0
        
        while !openSet.isEmpty {
            guard let (currentId, _) = openSet.dequeue() else { break }
            
            if closedSet.contains(currentId) {
                continue
            }
            
            closedSet.insert(currentId)
            nodesExplored += 1
            
            // Check if we reached the destination
            if currentId == destinationId {
                print("   Nodes explored: \(nodesExplored)")
                return reconstructPath(cameFrom: cameFrom, current: currentId)
            }
            
            // Explore neighbors
            let neighbors = graph.getNeighbors(of: currentId)
            
            for (neighbor, edgeWeight) in neighbors {
                if closedSet.contains(neighbor.id) {
                    continue
                }
                
                let tentativeGScore = (gScore[currentId] ?? .infinity) + edgeWeight
                
                if tentativeGScore < (gScore[neighbor.id] ?? .infinity) {
                    cameFrom[neighbor.id] = currentId
                    gScore[neighbor.id] = tentativeGScore
                    let h = heuristic(from: neighbor.position, to: destinationNode.position)
                    fScore[neighbor.id] = tentativeGScore + h
                    
                    openSet.enqueue(element: neighbor.id, priority: fScore[neighbor.id]!)
                }
            }
        }
        
        print("❌ No path found after exploring \(nodesExplored) nodes")
        return nil
    }
    
    // MARK: - Heuristic (Euclidean Distance)
    private func heuristic(from: simd_float3, to: simd_float3) -> Float {
        return simd_distance(from, to)
    }
    
    // MARK: - Reconstruct Path
    private func reconstructPath(cameFrom: [UUID: UUID], current: UUID) -> [NavigationNode] {
        var path: [NavigationNode] = []
        var currentId = current
        
        // Build path from destination to start
        while let node = graph.getNode(id: currentId) {
            path.insert(node, at: 0)
            
            if let previous = cameFrom[currentId] {
                currentId = previous
            } else {
                break
            }
        }
        
        return path
    }
    
    // MARK: - Calculate Path Distance
    private func calculatePathDistance(_ path: [NavigationNode]) -> Float {
        guard path.count > 1 else { return 0 }
        
        var totalDistance: Float = 0
        for i in 0..<(path.count - 1) {
            totalDistance += simd_distance(path[i].position, path[i + 1].position)
        }
        
        return totalDistance
    }
    
    // MARK: - Generate Path JSON
    private func generatePathJSON(path: [NavigationNode], totalDistance: Float) -> [String: Any] {
        let pathSteps = path.enumerated().map { index, node -> [String: Any] in
            var step: [String: Any] = [
                "step": index + 1,
                "nodeId": node.id.uuidString,
                "nodeName": node.name,
                "nodeType": nodeTypeString(node.nodeType),
                "roomId": node.roomId,
                "position": [
                    "x": Double(node.position.x),
                    "y": Double(node.position.y),
                    "z": Double(node.position.z)
                ]
            ]
            
            // Add distance to next node
            if index < path.count - 1 {
                let nextNode = path[index + 1]
                let distance = simd_distance(node.position, nextNode.position)
                step["distanceToNext"] = Double(distance)
            }
            
            return step
        }
        
        return [
            "pathCalculated": Date().timeIntervalSince1970,
            "totalSteps": path.count,
            "totalDistance": Double(totalDistance),
            "path": pathSteps,
            "startNode": path.first?.name ?? "Unknown",
            "endNode": path.last?.name ?? "Unknown"
        ]
    }
    
    private func nodeTypeString(_ nodeType: NavigationNode.NodeType) -> String {
        switch nodeType {
        case .beacon(let category):
            return "beacon_\(category)"
        case .waypoint:
            return "waypoint"
        case .doorway:
            return "doorway"
        }
    }
}

// MARK: - Path JSON Printer
extension PathResult {
    func printJSON() {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: pathJSON, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\n🗺️ PATH JSON:")
                print("╔════════════════════════════════════════════════╗")
                print(jsonString)
                print("╚════════════════════════════════════════════════╝\n")
            }
        } catch {
            print("❌ Failed to print path JSON: \(error)")
        }
    }
}
