//
//  NavigationUtilities.swift
//  Helper Extensions and Utilities (HORIZONTAL PLANE NAVIGATION - X,Z ONLY)
//  FIXED: Now uses X,Z horizontal plane (ignoring Y vertical height)
//

import Foundation
import simd
import ARKit

// MARK: - SIMD Extensions (HORIZONTAL PLANE NAVIGATION - X,Z)
extension simd_float3 {
    /// Distance between two points (HORIZONTAL PLANE - X,Z only, ignores Y height)
    func distance(to other: simd_float3) -> Float {
        let dx = other.x - self.x
        let dz = other.z - self.z
        return sqrt(dx * dx + dz * dz)
    }
    
    /// Direction vector from self to other (normalized, horizontal X,Z plane only)
    func direction(to other: simd_float3) -> simd_float3 {
        let dx = other.x - self.x
        let dz = other.z - self.z
        let length = sqrt(dx * dx + dz * dz)
        
        if length > 0.001 {
            return simd_float3(dx / length, 0, dz / length)
        }
        return simd_float3(0, 0, 1) // Default forward in Z direction
    }
    
    /// Horizontal distance (X,Z plane only, ignoring Y height)
    func horizontalDistance(to other: simd_float3) -> Float {
        return distance(to: other)
    }
    
    /// Horizontal direction (X,Z plane only)
    func horizontalDirection(to other: simd_float3) -> simd_float3 {
        return direction(to: other)
    }
    
    /// Angle in radians to another point (on horizontal X,Z plane)
    func angle(to other: simd_float3) -> Float {
        let direction = self.horizontalDirection(to: other)
        return atan2(direction.x, direction.z)
    }
    
    /// Create from coordinates dictionary
    static func from(dict: [String: Double]) -> simd_float3 {
        return simd_float3(
            Float(dict["x"] ?? 0),
            Float(dict["y"] ?? 0),
            Float(dict["z"] ?? 0)
        )
    }
    
    /// Convert to dictionary
    func toDictionary() -> [String: Double] {
        return [
            "x": Double(self.x),
            "y": Double(self.y),
            "z": Double(self.z)
        ]
    }
    
    /// Pretty print for debugging (horizontal plane - X,Z only)
    var debugDescription: String {
        return String(format: "(X: %.2f, Z: %.2f)", x, z)
    }
    
    /// Pretty print with Y for full coordinates
    var fullDebugDescription: String {
        return String(format: "(X: %.2f, Y: %.2f, Z: %.2f)", x, y, z)
    }
    
    /// Get horizontal coordinates only (X, Z)
    var xz: simd_float2 {
        return simd_float2(x, z)
    }
}

// MARK: - ARCamera Extensions
extension ARCamera {
    /// Get camera position as simd_float3
    var position: simd_float3 {
        let transform = self.transform
        return simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    /// Get camera forward direction (horizontal X,Z plane only)
    var forward: simd_float3 {
        let transform = self.transform
        let forward3D = -simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        // Project to horizontal plane (X,Z)
        let length = sqrt(forward3D.x * forward3D.x + forward3D.z * forward3D.z)
        if length > 0.001 {
            return simd_float3(forward3D.x / length, 0, forward3D.z / length)
        }
        return simd_float3(0, 0, 1) // Default forward in Z direction
    }
    
    /// Get camera right direction (positive X)
    var right: simd_float3 {
        let transform = self.transform
        return simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
    }
    
    /// Get camera up direction (positive Y)
    var up: simd_float3 {
        let transform = self.transform
        return simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
    }
}

// MARK: - Navigation Statistics
struct NavigationStatistics {
    let startTime: Date
    var endTime: Date?
    let totalDistance: Float
    let pathLength: Int
    var waypointsReached: Int = 0
    var currentSpeed: Float = 0
    var averageSpeed: Float = 0
    var estimatedTimeRemaining: TimeInterval = 0
    
    var elapsedTime: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var progressPercentage: Float {
        guard pathLength > 0 else { return 0 }
        return Float(waypointsReached) / Float(pathLength) * 100
    }
    
    mutating func updateSpeed(currentPosition: simd_float3, lastPosition: simd_float3, deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        
        let distance = currentPosition.distance(to: lastPosition)
        currentSpeed = distance / Float(deltaTime)
        
        // Calculate average speed
        if waypointsReached > 0 {
            averageSpeed = totalDistance / Float(elapsedTime)
        }
    }
    
    mutating func updateETA(remainingDistance: Float) {
        guard averageSpeed > 0 else {
            estimatedTimeRemaining = 0
            return
        }
        estimatedTimeRemaining = TimeInterval(remainingDistance / averageSpeed)
    }
    
    func formattedElapsedTime() -> String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func formattedETA() -> String {
        guard estimatedTimeRemaining > 0 else { return "--:--" }
        let minutes = Int(estimatedTimeRemaining) / 60
        let seconds = Int(estimatedTimeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Direction Helper
enum CompassDirection: String {
    case north = "North"
    case northeast = "Northeast"
    case east = "East"
    case southeast = "Southeast"
    case south = "South"
    case southwest = "Southwest"
    case west = "West"
    case northwest = "Northwest"
    
    static func from(angle: Float) -> CompassDirection {
        // Normalize angle to 0-360
        var normalizedAngle = angle * 180 / .pi
        if normalizedAngle < 0 {
            normalizedAngle += 360
        }
        
        switch normalizedAngle {
        case 0..<22.5, 337.5..<360:
            return .north
        case 22.5..<67.5:
            return .northeast
        case 67.5..<112.5:
            return .east
        case 112.5..<157.5:
            return .southeast
        case 157.5..<202.5:
            return .south
        case 202.5..<247.5:
            return .southwest
        case 247.5..<292.5:
            return .west
        case 292.5..<337.5:
            return .northwest
        default:
            return .north
        }
    }
    
    var icon: String {
        switch self {
        case .north: return "arrow.up"
        case .northeast: return "arrow.up.right"
        case .east: return "arrow.right"
        case .southeast: return "arrow.down.right"
        case .south: return "arrow.down"
        case .southwest: return "arrow.down.left"
        case .west: return "arrow.left"
        case .northwest: return "arrow.up.left"
        }
    }
}

// MARK: - Turn Instruction (FIXED for X,Z horizontal plane)
enum TurnInstruction: Equatable {
    case straight
    case slightLeft(degrees: Int)
    case left(degrees: Int)
    case sharpLeft(degrees: Int)
    case slightRight(degrees: Int)
    case right(degrees: Int)
    case sharpRight(degrees: Int)
    case uTurn(degrees: Int)
    
    /// Calculate turn instruction with hysteresis (horizontal plane X,Z navigation)
    /// - Parameters:
    ///   - currentDirection: Current camera forward direction (normalized, horizontal X,Z)
    ///   - targetDirection: Direction to target (normalized, horizontal X,Z)
    ///   - previousInstruction: Previous turn instruction for hysteresis
    /// - Returns: New turn instruction
    static func from(
        currentDirection: simd_float3,
        targetDirection: simd_float3,
        previousInstruction: TurnInstruction? = nil
    ) -> TurnInstruction {
        // Use only X,Z components for horizontal plane navigation
        let current2D = simd_float2(currentDirection.x, currentDirection.z)
        let target2D = simd_float2(targetDirection.x, targetDirection.z)
        
        // Normalize 2D vectors
        let currentNorm = simd_normalize(current2D)
        let targetNorm = simd_normalize(target2D)
        
        // Calculate angle using 2D vectors (horizontal plane)
        let dot = simd_dot(currentNorm, targetNorm)
        let cross = currentNorm.x * targetNorm.y - currentNorm.y * targetNorm.x
        let angle = atan2(abs(cross), dot)
        let angleDegrees = angle * 180 / .pi
        let angleInt = Int(round(angleDegrees))
        
        // Determine left or right turn (2D cross product)
        let isRight = cross > 0
        
        // HYSTERESIS: Add buffer zones around thresholds
        let hysteresis: Float = 5.0 // 5-degree buffer
        
        // Calculate new instruction based on angle
        let newInstruction: TurnInstruction
        
        switch angleDegrees {
        case 0..<25:
            newInstruction = .straight
        case 25..<50:
            newInstruction = isRight ? .slightRight(degrees: angleInt) : .slightLeft(degrees: angleInt)
        case 50..<130:
            newInstruction = isRight ? .right(degrees: angleInt) : .left(degrees: angleInt)
        case 130..<160:
            newInstruction = isRight ? .sharpRight(degrees: angleInt) : .sharpLeft(degrees: angleInt)
        default:
            newInstruction = isRight ? .uTurn(degrees: angleInt) : .uTurn(degrees: angleInt)
        }
        
        // Apply hysteresis: only change if difference is significant
        if let previous = previousInstruction {
            let shouldKeepPrevious = shouldApplyHysteresis(
                angleDegrees: angleDegrees,
                isRight: isRight,
                previous: previous,
                hysteresis: hysteresis
            )
            
            if shouldKeepPrevious {
                return previous
            }
        }
        
        return newInstruction
    }
    
    /// Check if we should keep the previous instruction due to hysteresis
    private static func shouldApplyHysteresis(
        angleDegrees: Float,
        isRight: Bool,
        previous: TurnInstruction,
        hysteresis: Float
    ) -> Bool {
        switch previous {
        case .straight:
            return angleDegrees < (25 + hysteresis)
            
        case .slightRight where isRight, .slightLeft where !isRight:
            return angleDegrees >= (25 - hysteresis) && angleDegrees < (50 + hysteresis)
            
        case .right where isRight, .left where !isRight:
            return angleDegrees >= (50 - hysteresis) && angleDegrees < (130 + hysteresis)
            
        case .sharpRight where isRight, .sharpLeft where !isRight:
            return angleDegrees >= (130 - hysteresis) && angleDegrees < (160 + hysteresis)
            
        case .uTurn:
            return angleDegrees >= (160 - hysteresis)
            
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .straight:
            return "Continue straight"
        case .slightLeft(let degrees):
            return "Bear slightly left (\(degrees)°)"
        case .left(let degrees):
            return "Turn left (\(degrees)°)"
        case .sharpLeft(let degrees):
            return "Sharp left turn (\(degrees)°)"
        case .slightRight(let degrees):
            return "Bear slightly right (\(degrees)°)"
        case .right(let degrees):
            return "Turn right (\(degrees)°)"
        case .sharpRight(let degrees):
            return "Sharp right turn (\(degrees)°)"
        case .uTurn(let degrees):
            return "Make a U-turn (\(degrees)°)"
        }
    }
    
    var icon: String {
        switch self {
        case .straight: return "arrow.up"
        case .slightLeft: return "arrow.turn.up.left"
        case .left: return "arrow.turn.left.up"
        case .sharpLeft: return "arrow.uturn.left"
        case .slightRight: return "arrow.turn.up.right"
        case .right: return "arrow.turn.right.up"
        case .sharpRight: return "arrow.uturn.right"
        case .uTurn: return "arrow.uturn.backward"
        }
    }
}

// MARK: - Audio Guidance Helper
class AudioGuidanceHelper {
    private var lastGuidanceTime: Date = Date.distantPast
    private let minimumInterval: TimeInterval = 5.0
    
    func shouldProvideGuidance() -> Bool {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastGuidanceTime)
        return elapsed >= minimumInterval
    }
    
    func markGuidanceProvided() {
        lastGuidanceTime = Date()
    }
    
    func generateGuidance(
        distance: Float,
        targetName: String,
        direction: CompassDirection,
        turn: TurnInstruction
    ) -> String {
        var guidance = ""
        
        if turn != .straight {
            guidance += "\(turn.description). "
        }
        
        guidance += "Head \(direction.rawValue.lowercased()). "
        
        if distance < 1.0 {
            guidance += "Target '\(targetName)' is \(Int(distance * 100)) centimeters ahead."
        } else {
            guidance += "Target '\(targetName)' is \(String(format: "%.1f", distance)) meters ahead."
        }
        
        return guidance
    }
}

// MARK: - Path Smoothing
extension PathResult {
    func smoothed() -> PathResult {
        guard path.count > 2 else { return self }
        
        var smoothedPath: [NavigationNode] = [path[0]]
        
        for i in 1..<(path.count - 1) {
            let prev = path[i - 1]
            let current = path[i]
            let next = path[i + 1]
            
            let dir1 = prev.position.direction(to: current.position)
            let dir2 = current.position.direction(to: next.position)
            
            let dot = simd_dot(dir1, dir2)
            
            if dot < 0.95 {
                smoothedPath.append(current)
            }
        }
        
        smoothedPath.append(path.last!)
        
        return PathResult(
            path: smoothedPath,
            totalDistance: self.totalDistance,
            pathJSON: self.pathJSON
        )
    }
}

// MARK: - Performance Monitor
class PerformanceMonitor {
    private var frameCount: Int = 0
    private var lastUpdateTime: Date = Date()
    private var fps: Double = 0
    
    func update() {
        frameCount += 1
        
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastUpdateTime = now
        }
    }
    
    var currentFPS: Double {
        return fps
    }
    
    var isPerformanceGood: Bool {
        return fps >= 30
    }
    
    func reset() {
        frameCount = 0
        lastUpdateTime = Date()
        fps = 0
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigationStarted = Notification.Name("NavigationStarted")
    static let navigationEnded = Notification.Name("NavigationEnded")
    static let waypointReached = Notification.Name("WaypointReached")
    static let destinationReached = Notification.Name("DestinationReached")
    static let pathRecalculated = Notification.Name("PathRecalculated")
    static let navigationError = Notification.Name("NavigationError")
}

// MARK: - Haptic Feedback Helper
class HapticFeedbackHelper {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    
    init() {
        prepare()
    }
    
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }
    
    func waypointReached() {
        mediumImpact.impactOccurred()
    }
    
    func destinationReached() {
        notification.notificationOccurred(.success)
    }
    
    func pathCalculated() {
        lightImpact.impactOccurred()
    }
    
    func navigationStarted() {
        heavyImpact.impactOccurred()
    }
    
    func error() {
        notification.notificationOccurred(.error)
    }
    
    func warning() {
        notification.notificationOccurred(.warning)
    }
}

// MARK: - Debug Logger
class NavigationLogger {
    static let shared = NavigationLogger()
    
    private var logs: [String] = []
    private let maxLogs = 1000
    
    func log(_ message: String, category: String = "INFO") {
        let timestamp = Date().formatted(.dateTime.hour().minute().second())
        let logMessage = "[\(timestamp)] [\(category)] \(message)"
        
        logs.append(logMessage)
        if logs.count > maxLogs {
            logs.removeFirst()
        }
        
        print(logMessage)
    }
    
    func error(_ message: String) {
        log(message, category: "ERROR")
    }
    
    func warning(_ message: String) {
        log(message, category: "WARNING")
    }
    
    func debug(_ message: String) {
        #if DEBUG
        log(message, category: "DEBUG")
        #endif
    }
    
    func exportLogs() -> String {
        return logs.joined(separator: "\n")
    }
    
    func clearLogs() {
        logs.removeAll()
    }
}
