//
//  RealtimeDiagnostic.swift
//  Shows EXACTLY what's happening with transformations - FIXED VERSION
//

import Foundation
import simd
import ARKit

extension PathNavigationViewModel {
    
    /// Print detailed diagnostic showing if transformation is working
    func printRealtimeDiagnostic() {
        guard let frame = session.currentFrame,
              let target = getNextTarget() else {
            return
        }
        
        // Get RAW position (no transformation)
        let rawTransform = frame.camera.transform
        let rawPosition = simd_float3(
            rawTransform.columns.3.x,
            rawTransform.columns.3.y,
            rawTransform.columns.3.z
        )
        
        // Get TRANSFORMED position
        let transformedPosition = coordinateTransformMode.transform(rawPosition)
        
        // Get camera forward RAW (NOT transformed)
        let cameraForwardRaw = -simd_float3(
            rawTransform.columns.2.x,
            rawTransform.columns.2.y,
            rawTransform.columns.2.z
        )
        
        // Get camera forward TRANSFORMED
        let cameraForwardTrans = coordinateTransformMode.transform(cameraForwardRaw)
        
        print("\n" + String(repeating: "=", count: 70))
        print("🔬 REALTIME DIAGNOSTIC")
        print(String(repeating: "=", count: 70))
        
        print("\n📍 YOUR POSITION:")
        print("   RAW:         X:\(String(format: "%6.2f", rawPosition.x))  Z:\(String(format: "%6.2f", rawPosition.z))")
        print("   TRANSFORMED: X:\(String(format: "%6.2f", transformedPosition.x))  Z:\(String(format: "%6.2f", transformedPosition.z))")
        print("   Changed:     \(rawPosition.x != transformedPosition.x || rawPosition.z != transformedPosition.z ? "✅ YES" : "❌ NO")")
        
        print("\n🎯 TARGET: \(target.name)")
        print("   Position: X:\(String(format: "%6.2f", target.position.x))  Z:\(String(format: "%6.2f", target.position.z))")
        
        print("\n🧭 CAMERA FORWARD:")
        print("   RAW:         X:\(String(format: "%6.3f", cameraForwardRaw.x))  Z:\(String(format: "%6.3f", cameraForwardRaw.z))")
        print("   TRANSFORMED: X:\(String(format: "%6.3f", cameraForwardTrans.x))  Z:\(String(format: "%6.3f", cameraForwardTrans.z))")
        print("   Changed:     \(abs(cameraForwardRaw.x - cameraForwardTrans.x) > 0.01 || abs(cameraForwardRaw.z - cameraForwardTrans.z) > 0.01 ? "✅ YES" : "❌ NO")")
        
        // Calculate arrow with RAW position and RAW camera forward
        let rawDx = target.position.x - rawPosition.x
        let rawDz = target.position.z - rawPosition.z
        let rawDirection = simd_normalize(simd_float2(rawDx, rawDz))
        let rawBearing = atan2(rawDirection.x, rawDirection.y)
        
        let cameraHeadingRaw = atan2(cameraForwardRaw.x, cameraForwardRaw.z)
        var rawRelativeAngle = rawBearing - cameraHeadingRaw
        while rawRelativeAngle > Float.pi { rawRelativeAngle -= 2 * Float.pi }
        while rawRelativeAngle < -Float.pi { rawRelativeAngle += 2 * Float.pi }
        let rawArrow = rawRelativeAngle * 180 / Float.pi
        
        // Calculate arrow with TRANSFORMED position and TRANSFORMED camera forward
        let transDx = target.position.x - transformedPosition.x
        let transDz = target.position.z - transformedPosition.z
        let transDirection = simd_normalize(simd_float2(transDx, transDz))
        let transBearing = atan2(transDirection.x, transDirection.y)
        
        let cameraHeadingTrans = atan2(cameraForwardTrans.x, cameraForwardTrans.z)
        var transRelativeAngle = transBearing - cameraHeadingTrans
        while transRelativeAngle > Float.pi { transRelativeAngle -= 2 * Float.pi }
        while transRelativeAngle < -Float.pi { transRelativeAngle += 2 * Float.pi }
        let transArrow = transRelativeAngle * 180 / Float.pi
        
        print("\n📐 ARROW CALCULATION:")
        print("   With RAW position:         \(String(format: "%6.1f", rawArrow))°")
        print("   With TRANSFORMED position: \(String(format: "%6.1f", transArrow))°")
        print("   Current arrowRotation:     \(String(format: "%6.1f", arrowRotation))°")
        print("   Arrow changed:             \(abs(rawArrow - transArrow) > 5.0 ? "✅ YES" : "❌ NO")")
        
        print("\n🎨 COLOR:")
        print("   Current: \(directionColor == .green ? "🟢 GREEN" : directionColor == .yellow ? "🟡 YELLOW" : directionColor == .orange ? "🟠 ORANGE" : directionColor == .red ? "🔴 RED" : "⚪️ OTHER")")
        print("   Is Aligned: \(isAligned ? "✅ YES" : "❌ NO")")
        
        print("\n🔧 TRANSFORMATION:")
        print("   Mode: \(coordinateTransformMode.rawValue)")
        print("   Active: \(coordinateTransformMode != .none ? "✅ YES" : "❌ NO")")
        
        print("\n💡 DIAGNOSIS:")
        let posChanged = abs(rawPosition.x - transformedPosition.x) > 0.01 || abs(rawPosition.z - transformedPosition.z) > 0.01
        let camChanged = abs(cameraForwardRaw.x - cameraForwardTrans.x) > 0.01 || abs(cameraForwardRaw.z - cameraForwardTrans.z) > 0.01
        let arrowChanged = abs(rawArrow - transArrow) > 5.0
        let uiMatches = abs(Double(arrowRotation) - Double(transArrow)) < 5.0
        
        if !posChanged && coordinateTransformMode != .none {
            print("   ❌ POSITION NOT BEING TRANSFORMED!")
        } else if !camChanged && coordinateTransformMode != .none {
            print("   ⚠️  CAMERA FORWARD NOT BEING TRANSFORMED!")
            print("   This is the bug! Camera direction needs transformation too")
        } else if !arrowChanged && coordinateTransformMode != .none {
            print("   ⚠️  TRANSFORMATION TOO SMALL!")
            print("   Position & camera transformed but arrow only changed by \(String(format: "%.1f", abs(rawArrow - transArrow)))°")
        } else if !uiMatches && coordinateTransformMode != .none {
            print("   ⚠️  UI NOT UPDATING!")
            print("   Calculation shows \(String(format: "%.1f", transArrow))° but UI shows \(String(format: "%.1f", arrowRotation))°")
        } else if coordinateTransformMode != .none {
            print("   ✅ Transformation is working correctly!")
            print("   Arrow changed by \(String(format: "%.1f", abs(rawArrow - transArrow)))°")
        } else {
            print("   ℹ️  No transformation applied (baseline)")
        }
        
        print(String(repeating: "=", count: 70) + "\n")
    }
}
