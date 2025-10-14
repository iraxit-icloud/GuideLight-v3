//
//  PathfindingEngine.swift - FIXED: Better debugging and doorway routing
//  GuideLight v3
//

import Foundation
import simd

// MARK: - Pathfinding Engine (A* Algorithm)
class PathfindingEngine {
    
    private let map: IndoorMap
    
    init(map: IndoorMap) {
        self.map = map
        print("🗺️ PathfindingEngine initialized")
        print("   Rooms: \(map.rooms.count)")
        print("   Beacons: \(map.beacons.count)")
        print("   Doorways: \(map.doorways.count)")
    }
    
    // MARK: - Main Pathfinding Method
    
    func findPath(
        from startPosition: simd_float3,
        to destinationBeacon: Beacon
    ) -> NavigationPath? {
        
        print("\n🎯 === PATHFINDING START ===")
        print("   From: \(formatPosition(startPosition))")
        print("   To: \(destinationBeacon.name) at \(formatPosition(destinationBeacon.position))")
        
        // Determine rooms
        let startRoom = determineRoom(for: startPosition)
        let destRoom = destinationBeacon.roomId
        
        print("   Start room: \(startRoom != nil ? (map.room(withId: startRoom!)?.name ?? startRoom!) : "UNKNOWN")")
        print("   Dest room: \(map.room(withId: destRoom)?.name ?? destRoom)")
        
        // If in same room, create direct path
        if let startRoom = startRoom, startRoom == destRoom {
            print("✅ Same room - creating direct path")
            return createDirectPath(from: startPosition, to: destinationBeacon)
        }
        
        // Different rooms - need to go through doorways
        guard let startRoom = startRoom else {
            print("❌ Cannot determine starting room")
            print("   Available rooms: \(map.rooms.map { $0.name }.joined(separator: ", "))")
            return nil
        }
        
        print("🚪 Searching for doorway path...")
        
        // Find doorway path between rooms
        guard let doorwayPath = findDoorwayPath(from: startRoom, to: destRoom) else {
            print("❌ No doorway path found between rooms")
            print("   Available doorways:")
            for doorway in map.doorways {
                let roomAName = map.room(withId: doorway.connectsRooms.roomA)?.name ?? doorway.connectsRooms.roomA
                let roomBName = map.room(withId: doorway.connectsRooms.roomB)?.name ?? doorway.connectsRooms.roomB
                print("     - \(doorway.name): \(roomAName) ↔ \(roomBName)")
            }
            return nil
        }
        
        print("✅ Found doorway path with \(doorwayPath.count) doorways")
        
        // Build complete path with waypoints
        return buildCompletePath(
            from: startPosition,
            to: destinationBeacon,
            via: doorwayPath
        )
    }
    
    // MARK: - Room-Based A* Search
    
    private func findDoorwayPath(from startRoom: String, to destRoom: String) -> [Doorway]? {
        print("   Building room connectivity graph...")
        
        // Build room connectivity graph
        var roomGraph: [String: [(doorway: Doorway, toRoom: String)]] = [:]
        
        for doorway in map.doorways {
            // Only use accessible doorways
            guard doorway.isAccessible else { continue }
            
            // Add edge from roomA to roomB
            if roomGraph[doorway.connectsRooms.roomA] == nil {
                roomGraph[doorway.connectsRooms.roomA] = []
            }
            roomGraph[doorway.connectsRooms.roomA]?.append((doorway, doorway.connectsRooms.roomB))
            
            // Add edge from roomB to roomA
            if roomGraph[doorway.connectsRooms.roomB] == nil {
                roomGraph[doorway.connectsRooms.roomB] = []
            }
            roomGraph[doorway.connectsRooms.roomB]?.append((doorway, doorway.connectsRooms.roomA))
            
            let roomAName = map.room(withId: doorway.connectsRooms.roomA)?.name ?? doorway.connectsRooms.roomA
            let roomBName = map.room(withId: doorway.connectsRooms.roomB)?.name ?? doorway.connectsRooms.roomB
            print("     Added: \(roomAName) ↔ \(roomBName) via \(doorway.name)")
        }
        
        // Check if start and destination are in the graph
        guard roomGraph[startRoom] != nil else {
            print("❌ Start room not in graph")
            return nil
        }
        
        guard roomGraph[destRoom] != nil || destRoom == startRoom else {
            print("❌ Destination room not in graph")
            return nil
        }
        
        print("   Starting A* search from \(map.room(withId: startRoom)?.name ?? startRoom)...")
        
        // A* search through room graph
        var openSet: Set<String> = [startRoom]
        var cameFrom: [String: (doorway: Doorway, fromRoom: String)] = [:]
        var gScore: [String: Float] = [startRoom: 0]
        var fScore: [String: Float] = [startRoom: estimateDistance(from: startRoom, to: destRoom)]
        
        var iterations = 0
        let maxIterations = 100
        
        while !openSet.isEmpty && iterations < maxIterations {
            iterations += 1
            
            // Get room with lowest fScore
            guard let current = openSet.min(by: { fScore[$0] ?? Float.infinity < fScore[$1] ?? Float.infinity }) else {
                break
            }
            
            print("     Iteration \(iterations): Exploring \(map.room(withId: current)?.name ?? current)")
            
            if current == destRoom {
                print("✅ Found path to destination!")
                // Reconstruct path
                return reconstructDoorwayPath(from: cameFrom, startRoom: startRoom, destRoom: destRoom)
            }
            
            openSet.remove(current)
            
            // Check neighbors
            guard let neighbors = roomGraph[current] else {
                print("       No neighbors found")
                continue
            }
            
            print("       Found \(neighbors.count) neighbors")
            
            for (doorway, neighbor) in neighbors {
                let tentativeGScore = (gScore[current] ?? Float.infinity) + doorway.width
                
                if tentativeGScore < (gScore[neighbor] ?? Float.infinity) {
                    let neighborName = map.room(withId: neighbor)?.name ?? neighbor
                    print("         Better path to \(neighborName) via \(doorway.name)")
                    
                    cameFrom[neighbor] = (doorway, current)
                    gScore[neighbor] = tentativeGScore
                    fScore[neighbor] = tentativeGScore + estimateDistance(from: neighbor, to: destRoom)
                    openSet.insert(neighbor)
                }
            }
        }
        
        if iterations >= maxIterations {
            print("❌ A* search exceeded max iterations")
        } else {
            print("❌ A* search exhausted without finding path")
        }
        
        return nil
    }
    
    private func reconstructDoorwayPath(
        from cameFrom: [String: (doorway: Doorway, fromRoom: String)],
        startRoom: String,
        destRoom: String
    ) -> [Doorway] {
        var path: [Doorway] = []
        var current = destRoom
        
        print("   Reconstructing path...")
        
        while current != startRoom {
            guard let prev = cameFrom[current] else {
                print("❌ Path reconstruction failed at \(current)")
                break
            }
            path.insert(prev.doorway, at: 0)
            print("     <- \(prev.doorway.name)")
            current = prev.fromRoom
        }
        
        print("   Final doorway path: \(path.map { $0.name }.joined(separator: " → "))")
        return path
    }
    
    // MARK: - Path Building
    
    private func createDirectPath(from start: simd_float3, to beacon: Beacon) -> NavigationPath {
        let waypoints = [
            NavigationWaypoint(
                position: start,
                type: .start,
                name: "Start",
                roomId: beacon.roomId
            ),
            NavigationWaypoint(
                position: beacon.position,
                type: .destination,
                name: beacon.name,
                roomId: beacon.roomId,
                audioInstruction: "You have arrived at \(beacon.name)"
            )
        ]
        
        let distance = simd_distance(start, beacon.position)
        let time = TimeInterval(distance / 1.2)
        
        print("✅ Direct path created: \(String(format: "%.1fm", distance))")
        return NavigationPath(
            waypoints: waypoints,
            totalDistance: distance,
            estimatedTime: time,
            roomsTraversed: [beacon.roomId]
        )
    }
    
    private func buildCompletePath(
        from start: simd_float3,
        to destination: Beacon,
        via doorways: [Doorway]
    ) -> NavigationPath? {
        
        print("   Building complete path...")
        
        var waypoints: [NavigationWaypoint] = []
        var totalDistance: Float = 0
        var roomsTraversed: [String] = []
        
        // Start waypoint
        let startRoom = determineRoom(for: start) ?? doorways.first?.connectsRooms.roomA ?? ""
        waypoints.append(NavigationWaypoint(
            position: start,
            type: .start,
            name: "Start Position",
            roomId: startRoom
        ))
        roomsTraversed.append(startRoom)
        
        print("     1. Start at \(formatPosition(start))")
        
        // Add doorway waypoints
        var currentPos = start
        var currentRoom = startRoom
        var step = 2
        
        for doorway in doorways {
            // Add waypoint at doorway
            let nextRoom = doorway.connectsRooms.otherRoom(from: currentRoom) ?? currentRoom
            let doorwayWaypoint = NavigationWaypoint(
                position: doorway.position,
                type: .doorway,
                name: doorway.name,
                roomId: currentRoom,
                doorwayId: doorway.id.uuidString,
                audioInstruction: doorway.navigationGuidance(from: currentRoom, to: nextRoom)
            )
            waypoints.append(doorwayWaypoint)
            
            // Update distance
            let segmentDistance = simd_distance(currentPos, doorway.position)
            totalDistance += segmentDistance
            print("     \(step). \(doorway.name) - \(String(format: "%.1fm", segmentDistance))")
            step += 1
            
            currentPos = doorway.position
            currentRoom = nextRoom
            
            if !roomsTraversed.contains(currentRoom) {
                roomsTraversed.append(currentRoom)
            }
        }
        
        // Destination waypoint
        let finalDistance = simd_distance(currentPos, destination.position)
        waypoints.append(NavigationWaypoint(
            position: destination.position,
            type: .destination,
            name: destination.name,
            roomId: destination.roomId,
            audioInstruction: "You have arrived at \(destination.name)"
        ))
        totalDistance += finalDistance
        print("     \(step). \(destination.name) - \(String(format: "%.1fm", finalDistance))")
        
        let estimatedTime = TimeInterval(totalDistance / 1.2)
        
        print("\n✅ === PATH COMPLETE ===")
        print("   Waypoints: \(waypoints.count)")
        print("   Total distance: \(String(format: "%.1fm", totalDistance))")
        print("   Estimated time: \(Int(estimatedTime))s")
        print("   Rooms: \(roomsTraversed.compactMap { map.room(withId: $0)?.name }.joined(separator: " → "))")
        
        return NavigationPath(
            waypoints: waypoints,
            totalDistance: totalDistance,
            estimatedTime: estimatedTime,
            roomsTraversed: roomsTraversed
        )
    }
    
    // MARK: - Helper Methods
    
    private func determineRoom(for position: simd_float3) -> String? {
        var closestBeacon: Beacon?
        var minDistance: Float = Float.infinity
        
        for beacon in map.beacons {
            let distance = simd_distance(
                simd_float2(position.x, position.z),
                simd_float2(beacon.position.x, beacon.position.z)
            )
            if distance < minDistance {
                minDistance = distance
                closestBeacon = beacon
            }
        }
        
        return closestBeacon?.roomId
    }
    
    private func estimateDistance(from roomA: String, to roomB: String) -> Float {
        let beaconsA = map.beacons.filter { $0.roomId == roomA }
        let beaconsB = map.beacons.filter { $0.roomId == roomB }
        
        guard !beaconsA.isEmpty && !beaconsB.isEmpty else { return 10.0 }
        
        let avgPosA = beaconsA.reduce(simd_float2(0, 0)) { result, beacon in
            result + simd_float2(beacon.position.x, beacon.position.z)
        } / Float(beaconsA.count)
        
        let avgPosB = beaconsB.reduce(simd_float2(0, 0)) { result, beacon in
            result + simd_float2(beacon.position.x, beacon.position.z)
        } / Float(beaconsB.count)
        
        return simd_distance(avgPosA, avgPosB)
    }
    
    private func formatPosition(_ pos: simd_float3) -> String {
        return "(\(String(format: "%.1f", pos.x)), \(String(format: "%.1f", pos.z)))"
    }
}
