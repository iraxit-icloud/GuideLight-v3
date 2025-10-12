//
//  CoordinateSystemDiagnostic.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/12/25.
//


//
//  CoordinateSystemDiagnostic.swift
//  Diagnostic tool to identify coordinate system transformation issues
//

import Foundation
import ARKit
import simd

class CoordinateSystemDiagnostic {
    
    // MARK: - Coordinate Transformation Tests
    
    /// Test different coordinate transformations to find the correct one
    static func testCoordinateTransformations(
        cameraPosition: simd_float3,
        beaconPosition: simd_float3,
        beaconName: String
    ) -> [String: Any] {
        
        var results: [String: Any] = [:]
        
        // Original (no transformation)
        let distanceOriginal = distance(from: cameraPosition, to: beaconPosition)
        results["original"] = [
            "camera": formatVector(cameraPosition),
            "beacon": formatVector(beaconPosition),
            "distance": String(format: "%.2f", distanceOriginal)
        ]
        
        // Test 1: Invert X-axis
        let cameraInvertX = simd_float3(-cameraPosition.x, cameraPosition.y, cameraPosition.z)
        let distanceInvertX = distance(from: cameraInvertX, to: beaconPosition)
        results["invertX"] = [
            "camera": formatVector(cameraInvertX),
            "distance": String(format: "%.2f", distanceInvertX),
            "improvement": distanceInvertX < distanceOriginal ? "✅ BETTER" : "❌ WORSE"
        ]
        
        // Test 2: Invert Z-axis
        let cameraInvertZ = simd_float3(cameraPosition.x, cameraPosition.y, -cameraPosition.z)
        let distanceInvertZ = distance(from: cameraInvertZ, to: beaconPosition)
        results["invertZ"] = [
            "camera": formatVector(cameraInvertZ),
            "distance": String(format: "%.2f", distanceInvertZ),
            "improvement": distanceInvertZ < distanceOriginal ? "✅ BETTER" : "❌ WORSE"
        ]
        
        // Test 3: Invert both X and Z
        let cameraInvertXZ = simd_float3(-cameraPosition.x, cameraPosition.y, -cameraPosition.z)
        let distanceInvertXZ = distance(from: cameraInvertXZ, to: beaconPosition)
        results["invertXZ"] = [
            "camera": formatVector(cameraInvertXZ),
            "distance": String(format: "%.2f", distanceInvertXZ),
            "improvement": distanceInvertXZ < distanceOriginal ? "✅ BETTER" : "❌ WORSE"
        ]
        
        // Test 4: Swap X and Z
        let cameraSwapXZ = simd_float3(cameraPosition.z, cameraPosition.y, cameraPosition.x)
        let distanceSwapXZ = distance(from: cameraSwapXZ, to: beaconPosition)
        results["swapXZ"] = [
            "camera": formatVector(cameraSwapXZ),
            "distance": String(format: "%.2f", distanceSwapXZ),
            "improvement": distanceSwapXZ < distanceOriginal ? "✅ BETTER" : "❌ WORSE"
        ]
        
        // Test 5: Rotate 180° around Y-axis (X→-X, Z→-Z)
        let cameraRotate180 = simd_float3(-cameraPosition.x, cameraPosition.y, -cameraPosition.z)
        let distanceRotate180 = distance(from: cameraRotate180, to: beaconPosition)
        results["rotate180Y"] = [
            "camera": formatVector(cameraRotate180),
            "distance": String(format: "%.2f", distanceRotate180),
            "improvement": distanceRotate180 < distanceOriginal ? "✅ BETTER" : "❌ WORSE"
        ]
        
        // Test 6: Rotate 90° clockwise around Y (X→Z, Z→-X)
        let cameraRotate90CW = simd_float3(cameraPosition.z, cameraPosition.y, -cameraPosition.x)
        let distanceRotate90CW = distance(from: cameraRotate90CW, to: beaconPosition)
        results["rotate90CW"] = [
            "camera": formatVector(cameraRotate90CW),
            "distance": String(format: "%.2f", distanceRotate90CW),
            "improvement": distanceRotate90CW < distanceOriginal ? "✅ BETTER" : "❌ WORSE"
        ]
        
        // Test 7: Rotate 90° counter-clockwise around Y (X→-Z, Z→X)
        let cameraRotate90CCW = simd_float3(-cameraPosition.z, cameraPosition.y, cameraPosition.x)
        let distanceRotate90CCW = distance(from: cameraRotate90CCW, to: beaconPosition)
        results["rotate90CCW"] = [
            "camera": formatVector(cameraRotate90CCW),
            "distance": String(format: "%.2f", distanceRotate90CCW),
            "improvement": distanceRotate90CCW < distanceOriginal ? "✅ BETTER" : "❌ WORSE"
        ]
        
        return results
    }
    
    // MARK: - Direction Tests
    
    /// Test direction calculations with different transformations
    static func testDirectionCalculations(
        cameraPosition: simd_float3,
        cameraForward: simd_float3,
        targetPosition: simd_float3,
        targetName: String
    ) -> [String: Any] {
        
        var results: [String: Any] = [:]
        
        // Calculate expected direction (where target actually is)
        let dx = targetPosition.x - cameraPosition.x
        let dz = targetPosition.z - cameraPosition.z
        let expectedBearing = atan2(dx, dz) * 180 / .pi
        
        results["expectedDirection"] = [
            "dx": String(format: "%.2f", dx),
            "dz": String(format: "%.2f", dz),
            "bearing": String(format: "%.1f°", expectedBearing),
            "interpretation": interpretBearing(expectedBearing)
        ]
        
        // Test camera forward with different transformations
        let cameraHeading = atan2(cameraForward.x, cameraForward.z) * 180 / .pi
        let relativeAngle = expectedBearing - cameraHeading
        
        results["cameraForward"] = [
            "vector": formatVector(cameraForward),
            "heading": String(format: "%.1f°", cameraHeading),
            "relativeAngle": String(format: "%.1f°", normalizeAngle(relativeAngle))
        ]
        
        // Test inverted camera forward
        let cameraForwardInverted = simd_float3(-cameraForward.x, cameraForward.y, -cameraForward.z)
        let invertedHeading = atan2(cameraForwardInverted.x, cameraForwardInverted.z) * 180 / .pi
        let invertedRelative = expectedBearing - invertedHeading
        
        results["cameraForwardInverted"] = [
            "vector": formatVector(cameraForwardInverted),
            "heading": String(format: "%.1f°", invertedHeading),
            "relativeAngle": String(format: "%.1f°", normalizeAngle(invertedRelative)),
            "improvement": abs(normalizeAngle(invertedRelative)) < abs(normalizeAngle(relativeAngle)) ? "✅ BETTER" : "❌ WORSE"
        ]
        
        return results
    }
    
    // MARK: - Build vs Navigation Comparison
    
    /// Compare coordinate systems between build time and navigation time
    static func compareCoordinateSystems(
        buildTimePosition: simd_float3,
        navigationTimePosition: simd_float3,
        knownBeaconPosition: simd_float3,
        beaconName: String
    ) -> [String: Any] {
        
        var results: [String: Any] = [:]
        
        // If positions are the same physical location, they should match
        // Calculate distances in both scenarios
        let buildDistance = distance(from: buildTimePosition, to: knownBeaconPosition)
        let navDistance = distance(from: navigationTimePosition, to: knownBeaconPosition)
        
        results["buildTime"] = [
            "position": formatVector(buildTimePosition),
            "distanceToBeacon": String(format: "%.2f", buildDistance)
        ]
        
        results["navigationTime"] = [
            "position": formatVector(navigationTimePosition),
            "distanceToBeacon": String(format: "%.2f", navDistance)
        ]
        
        // Test if there's a simple transformation
        let positionDiff = navigationTimePosition - buildTimePosition
        results["difference"] = formatVector(positionDiff)
        
        // Check if navigation position needs inversion
        let navPositionInverted = simd_float3(-navigationTimePosition.x, navigationTimePosition.y, -navigationTimePosition.z)
        let invertedDistance = distance(from: navPositionInverted, to: knownBeaconPosition)
        
        results["navigationTimeInverted"] = [
            "position": formatVector(navPositionInverted),
            "distanceToBeacon": String(format: "%.2f", invertedDistance),
            "matchesBuild": abs(invertedDistance - buildDistance) < 0.5 ? "✅ YES" : "❌ NO"
        ]
        
        return results
    }
    
    // MARK: - Movement Direction Test
    
    /// Track movement to determine if coordinate system is inverted
    static func analyzeMovement(
        previousPosition: simd_float3,
        currentPosition: simd_float3,
        targetPosition: simd_float3,
        previousDistance: Float,
        currentDistance: Float
    ) -> [String: Any] {
        
        var results: [String: Any] = [:]
        
        // Calculate movement vector
        let movement = currentPosition - previousPosition
        let movementDistance = simd_length(movement)
        
        results["movement"] = [
            "vector": formatVector(movement),
            "distance": String(format: "%.3f", movementDistance)
        ]
        
        // Calculate direction to target from previous position
        let directionToTarget = simd_normalize(simd_float2(
            targetPosition.x - previousPosition.x,
            targetPosition.z - previousPosition.z
        ))
        
        // Calculate actual movement direction
        let movementDirection = simd_normalize(simd_float2(movement.x, movement.z))
        
        // Dot product tells us if moving toward or away from target
        let dotProduct = simd_dot(movementDirection, directionToTarget)
        let isMovingToward = dotProduct > 0
        
        results["direction"] = [
            "towardTarget": isMovingToward ? "✅ YES" : "❌ NO",
            "dotProduct": String(format: "%.3f", dotProduct),
            "previousDistance": String(format: "%.2f", previousDistance),
            "currentDistance": String(format: "%.2f", currentDistance),
            "distanceChange": String(format: "%.3f", currentDistance - previousDistance)
        ]
        
        // CRITICAL: Check if behavior is inverted
        let distanceDecreased = currentDistance < previousDistance
        let coordinateSystemInverted = (isMovingToward && !distanceDecreased) || (!isMovingToward && distanceDecreased)
        
        results["analysis"] = [
            "movingToward": isMovingToward ? "YES" : "NO",
            "distanceDecreased": distanceDecreased ? "YES" : "NO",
            "coordinateSystemInverted": coordinateSystemInverted ? "⚠️ YES - FIX NEEDED" : "✅ NO - OK"
        ]
        
        return results
    }
    
    // MARK: - Helper Functions
    
    private static func distance(from: simd_float3, to: simd_float3) -> Float {
        let dx = to.x - from.x
        let dz = to.z - from.z
        return sqrt(dx * dx + dz * dz)
    }
    
    private static func formatVector(_ vector: simd_float3) -> String {
        return String(format: "X: %.2f, Y: %.2f, Z: %.2f", vector.x, vector.y, vector.z)
    }
    
    private static func normalizeAngle(_ angle: Float) -> Float {
        var normalized = angle
        while normalized > 180 { normalized -= 360 }
        while normalized < -180 { normalized += 360 }
        return normalized
    }
    
    private static func interpretBearing(_ bearing: Float) -> String {
        let normalized = normalizeAngle(bearing)
        switch normalized {
        case -22.5..<22.5: return "North (forward)"
        case 22.5..<67.5: return "Northeast"
        case 67.5..<112.5: return "East (right)"
        case 112.5..<157.5: return "Southeast"
        case -157.5..<(-112.5): return "Southwest"
        case -112.5..<(-67.5): return "West (left)"
        case -67.5..<(-22.5): return "Northwest"
        default: return "South (behind)"
        }
    }
    
    // MARK: - Logging Helper
    
    static func printDiagnostics(_ results: [String: Any], title: String) {
        print("=" * 60)
        print("📊 \(title)")
        print("=" * 60)
        printDictionary(results, indent: 0)
        print("=" * 60)
        print("")
    }
    
    private static func printDictionary(_ dict: [String: Any], indent: Int) {
        let indentStr = String(repeating: "  ", count: indent)
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            if let nestedDict = value as? [String: Any] {
                print("\(indentStr)\(key):")
                printDictionary(nestedDict, indent: indent + 1)
            } else {
                print("\(indentStr)\(key): \(value)")
            }
        }
    }
}

// MARK: - String Repetition Helper
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}