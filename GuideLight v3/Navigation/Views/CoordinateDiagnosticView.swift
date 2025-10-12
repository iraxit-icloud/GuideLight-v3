//
//  CoordinateDiagnosticView.swift
//  Diagnostic UI for testing coordinate transformations in real-time
//  SIMPLIFIED VERSION - Fixes type-checking timeout
//

import SwiftUI
import simd

struct CoordinateDiagnosticView: View {
    @ObservedObject var viewModel: PathNavigationViewModel
    @State private var showFullDiagnostics = false
    
    var body: some View {
        mainContainer
    }
    
    // MARK: - Main Container
    
    private var mainContainer: some View {
        VStack(spacing: 0) {
            compactBanner
            
            if showFullDiagnostics {
                fullDiagnosticsView
            }
        }
        .background(Color.black.opacity(0.9))
    }
    
    // MARK: - Compact Banner
    
    private var compactBanner: some View {
        VStack(spacing: 8) {
            bannerHeader
            bannerInfo
        }
        .background(Color.black.opacity(0.95))
        .overlay(bannerBottomBorder, alignment: .bottom)
    }
    
    private var bannerHeader: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundColor(.orange)
            
            Text("Coordinate Diagnostic")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            toggleButton
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    private var toggleButton: some View {
        Button {
            withAnimation {
                showFullDiagnostics.toggle()
            }
        } label: {
            Image(systemName: showFullDiagnostics ? "chevron.up" : "chevron.down")
                .foregroundColor(.orange)
                .padding(8)
                .background(Color.orange.opacity(0.2))
                .clipShape(Circle())
        }
    }
    
    private var bannerInfo: some View {
        HStack {
            Text("Transform:")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(viewModel.coordinateTransformMode.rawValue)
                .font(.caption.weight(.bold))
                .foregroundColor(.orange)
            
            Spacer()
            
            distanceIndicator
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    private var distanceIndicator: some View {
        Group {
            if let target = viewModel.getNextTarget(),
               let pos = viewModel.getCurrentCameraPosition() {
                let distance = calculateDistance(from: pos, to: target.position)
                Text("Dist: \(String(format: "%.2f", distance))m")
                    .font(.caption.bold())
                    .foregroundColor(abs(distance - viewModel.distanceToNextPoint) < 0.1 ? .green : .red)
            }
        }
    }
    
    private var bannerBottomBorder: some View {
        Rectangle()
            .fill(Color.orange)
            .frame(height: 2)
    }
    
    // MARK: - Full Diagnostics
    
    private var fullDiagnosticsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                transformationPicker
                quickTestButtons
                
                if let pos = viewModel.getCurrentCameraPosition(),
                   let target = viewModel.getNextTarget() {
                    positionInfoView(currentPos: pos, target: target)
                }
                
                if !viewModel.diagnosticInfo.isEmpty {
                    diagnosticOutputView
                }
                
                movementTrackerView
            }
            .padding()
        }
        .frame(maxHeight: 400)
    }
    
    // MARK: - Transformation Picker
    
    private var transformationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            pickerTitle
            pickerDescription
            transformationGrid
        }
    }
    
    private var pickerTitle: some View {
        Text("Test Coordinate Transformations")
            .font(.subheadline.weight(.bold))
            .foregroundColor(.white)
    }
    
    private var pickerDescription: some View {
        Text("If navigation is inverted, try different transformations below:")
            .font(.caption)
            .foregroundColor(.gray)
    }
    
    private var transformationGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(CoordinateTransformMode.allCases, id: \.self) { mode in
                transformButton(for: mode)
            }
        }
    }
    
    private func transformButton(for mode: CoordinateTransformMode) -> some View {
        Button {
            viewModel.coordinateTransformMode = mode
            print("🔘 Selected: \(mode.rawValue)")
            
            // Force UI update
            DispatchQueue.main.async {
                viewModel.objectWillChange.send()
            }
            
            // Force immediate update
            if viewModel.navigationState == .navigating {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.forceNavigationUpdate()
                }
            }
        } label: {
            transformButtonContent(for: mode)
        }
    }
    
    private func transformButtonContent(for mode: CoordinateTransformMode) -> some View {
        let isSelected = mode == viewModel.coordinateTransformMode
        
        return VStack(spacing: 4) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .green : .gray)
            
            Text(mode.rawValue)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(transformButtonBackground(isSelected: isSelected))
        .overlay(transformButtonBorder(isSelected: isSelected))
    }
    
    private func transformButtonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
    }
    
    private func transformButtonBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
    }
    
    // MARK: - Quick Test Buttons
    
    private var quickTestButtons: some View {
        VStack(spacing: 8) {
            // Real-time diagnostic button
            Button {
                viewModel.printRealtimeDiagnostic()
            } label: {
                HStack {
                    Image(systemName: "stethoscope")
                    Text("Show Real-Time Diagnostic")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Apply & Test button (makes it obvious transformation is active)
            if viewModel.coordinateTransformMode != .none {
                Button {
                    viewModel.forceNavigationUpdate()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Apply & Update Arrow")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            testAllButton
            analyzeMovementButton
        }
    }
    
    private var testAllButton: some View {
        Button {
            viewModel.testAllTransformations()
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Test All Transformations")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private var analyzeMovementButton: some View {
        Button {
            viewModel.runMovementDiagnostic()
        } label: {
            HStack {
                Image(systemName: "figure.walk")
                Text("Analyze Movement Direction")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(viewModel.navigationState != .navigating)
        .opacity(viewModel.navigationState != .navigating ? 0.5 : 1.0)
    }
    
    // MARK: - Position Info
    
    private func positionInfoView(currentPos: simd_float3, target: NavigationNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            positionInfoTitle
            positionInfoContent(currentPos: currentPos, target: target)
        }
    }
    
    private var positionInfoTitle: some View {
        Text("Real-time Position Data")
            .font(.subheadline.weight(.bold))
            .foregroundColor(.white)
    }
    
    private func positionInfoContent(currentPos: simd_float3, target: NavigationNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            infoRow(label: "Your Position", value: formatVector(currentPos))
            infoRow(label: "Target Position", value: formatVector(target.position))
            
            // Show target type and name with waypoint counter
            HStack {
                Text("Target:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(target.name)
                        .font(.caption.monospaced().bold())
                        .foregroundColor(.orange)
                    
                    Text("Waypoint \(viewModel.currentPathIndex + 1) of \(viewModel.currentPath?.path.count ?? 0)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            let distance = calculateDistance(from: currentPos, to: target.position)
            infoRow(label: "Calculated Distance", value: String(format: "%.2fm", distance))
            infoRow(label: "Reported Distance", value: String(format: "%.2fm", viewModel.distanceToNextPoint))
            
            matchStatusRow(calculatedDistance: distance)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func matchStatusRow(calculatedDistance: Float) -> some View {
        HStack {
            Text("Match Status:")
                .font(.caption)
                .foregroundColor(.gray)
            
            let matches = abs(calculatedDistance - viewModel.distanceToNextPoint) < 0.1
            Text(matches ? "✅ MATCH" : "⚠️ MISMATCH")
                .font(.caption.bold())
                .foregroundColor(matches ? .green : .red)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Diagnostic Output
    
    private var diagnosticOutputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            diagnosticOutputHeader
            diagnosticOutputScroll
        }
    }
    
    private var diagnosticOutputHeader: some View {
        HStack {
            Text("Diagnostic Results")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                viewModel.diagnosticInfo = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var diagnosticOutputScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(viewModel.diagnosticInfo)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .padding()
        }
        .frame(maxHeight: 150)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Movement Tracker
    
    private var movementTrackerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            movementTrackerTitle
            movementInstructions
        }
    }
    
    private var movementTrackerTitle: some View {
        Text("Movement Instructions")
            .font(.subheadline.weight(.bold))
            .foregroundColor(.white)
    }
    
    private var movementInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            instructionRow(icon: "1.circle.fill", text: "Start navigation to a destination")
            instructionRow(icon: "2.circle.fill", text: "Walk TOWARD the destination")
            instructionRow(icon: "3.circle.fill", text: "Watch if distance DECREASES (correct) or INCREASES (inverted)")
            instructionRow(icon: "4.circle.fill", text: "Tap 'Analyze Movement' to get recommendations")
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateDistance(from: simd_float3, to: simd_float3) -> Float {
        let dx = to.x - from.x
        let dz = to.z - from.z
        return sqrt(dx * dx + dz * dz)
    }
    
    private func formatVector(_ vector: simd_float3) -> String {
        return String(format: "X:%.2f Y:%.2f Z:%.2f", vector.x, vector.y, vector.z)
    }
}

// MARK: - Preview
struct CoordinateDiagnosticView_Previews: PreviewProvider {
    static var previews: some View {
        CoordinateDiagnosticView(viewModel: PathNavigationViewModel())
            .preferredColorScheme(.dark)
    }
}
