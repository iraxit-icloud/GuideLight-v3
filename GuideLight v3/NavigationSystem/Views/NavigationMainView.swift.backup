//
//  NavigationMainView.swift
//  GuideLight v3
//
//  Updated with improved UI combining both screenshot styles
//

import SwiftUI
import ARKit
import SceneKit

// MARK: - Main Navigation View
struct NavigationMainView: View {
    @StateObject private var relocalizationManager = ARRelocalizationManager()
    @StateObject private var calibrationViewModel: CalibrationViewModel
    @State private var navigationViewModel: NavigationViewModel?
    
    @State private var showingCalibration = true
    @State private var showingDestinationPicker = false
    @State private var arSession = ARSession()
    
    private let map: IndoorMap
    private let mapFileName: String
    
    init(map: IndoorMap, mapFileName: String) {
        self.map = map
        self.mapFileName = mapFileName
        _calibrationViewModel = StateObject(wrappedValue: CalibrationViewModel(
            map: map,
            relocalizationManager: ARRelocalizationManager()
        ))
    }
    
    var body: some View {
        ZStack {
            // AR Camera View (Full Screen)
            if showingCalibration {
                CalibrationARView(
                    viewModel: calibrationViewModel,
                    session: arSession,
                    mapFileName: mapFileName
                )
            } else if let navViewModel = navigationViewModel {
                NavigationARView(
                    viewModel: navViewModel,
                    session: arSession
                )
            }
            
            // Overlay UI
            if showingCalibration {
                calibrationOverlay
            } else if let navViewModel = navigationViewModel {
                navigationOverlay(navViewModel: navViewModel)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingDestinationPicker) {
            if let navViewModel = navigationViewModel {
                DestinationPickerView(
                    viewModel: navViewModel,
                    session: arSession,
                    onSelected: { showingDestinationPicker = false }
                )
            }
        }
    }
    
    // MARK: - Calibration Overlay
    private var calibrationOverlay: some View {
        VStack {
            Spacer()
            
            CalibrationProgressView(viewModel: calibrationViewModel)
                .padding()
            
            if case .completed(let calibration) = calibrationViewModel.calibrationState {
                if calibration.confidence < 0.6 {
                    Text("⚠️ Low confidence. Consider recalibrating.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }
                
                Button {
                    completeCalibration(calibration)
                } label: {
                    Text("Start Navigation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(calibration.qualityRating == .poor ? Color.orange : Color.green)
                        .cornerRadius(12)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Navigation Overlay (UPDATED)
    private func navigationOverlay(navViewModel: NavigationViewModel) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Status Bar (observing subview)
                NavigationStatusBarUpdatedView(
                    viewModel: navViewModel,
                    formatTimeShort: formatTimeShort,
                    formatDistance: navViewModel.formatDistance
                )
                .padding(.top, 60)
                
                Spacer()
                
                // Center Clock Compass (Combined style)
                ImprovedClockCompassView(viewModel: navViewModel)
                
                Spacer()
                
                // Bottom Controls
                navigationControls(navViewModel: navViewModel)
            }
            
            // Arrival Message Overlay
            if navViewModel.showArrivalMessage, let message = navViewModel.arrivalMessage {
                arrivalMessageView(message: message)
            }
        }
    }
    
    // MARK: - Arrival Message View
    private func arrivalMessageView(message: String) -> some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                
                Text(message)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 10)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: message)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Navigation Controls
    private func navigationControls(navViewModel: NavigationViewModel) -> some View {
        HStack(spacing: 20) {
            if case .navigating = navViewModel.navigationState {
                Button {
                    navViewModel.pauseNavigation()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.orange.opacity(0.9))
                        .clipShape(Circle())
                }
            } else if case .paused = navViewModel.navigationState {
                Button {
                    navViewModel.resumeNavigation()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.green.opacity(0.9))
                        .clipShape(Circle())
                }
            }
            
            Button {
                navViewModel.cancelNavigation()
                showingDestinationPicker = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.red.opacity(0.9))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Methods
    private func completeCalibration(_ calibration: CalibrationData) {
        navigationViewModel = NavigationViewModel(map: map, calibration: calibration)
        showingCalibration = false
        showingDestinationPicker = true
    }
    
    private func formatTimeShort(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "—" }
        let m = Int(time) / 60
        let s = Int(time) % 60
        if m >= 60 {
            let h = m / 60
            let rm = m % 60
            return "\(h)h \(rm)m"
        } else if m > 0 {
            return "\(m)m \(s)s"
        } else {
            return "\(s)s"
        }
    }
}

// MARK: - Observing Status Bar (Fix for non-updating To/Next/Distance/Time)
private struct NavigationStatusBarUpdatedView: View {
    @ObservedObject var viewModel: NavigationViewModel
    let formatTimeShort: (TimeInterval) -> String
    let formatDistance: (Float) -> String
    
    var body: some View {
        VStack(spacing: 12) {
            // Final destination
            if let destination = viewModel.destinationBeacon {
                Text("To: \(destination.name)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8)
            }
            
            // Current waypoint with flag icon
            if let currentWaypoint = viewModel.currentWaypoint {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    
                    Text("Next: \(currentWaypoint.name)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.9))
                )
                .shadow(color: .black.opacity(0.3), radius: 6)
            }
            
            // Distance and Time boxes
            if let progress = viewModel.progress {
                HStack(spacing: 16) {
                    // Distance box
                    VStack(spacing: 2) {
                        Text(formatDistance(progress.distanceToNextWaypoint))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text("distance")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.75))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8)
                    
                    // Time box
                    VStack(spacing: 2) {
                        Text(formatTimeShort(progress.estimatedTimeRemaining))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text("time")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.75))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8)
                }
            }
        }
        // Small, targeted animations on change
        .animation(.easeInOut(duration: 0.2), value: viewModel.destinationBeacon?.id)
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentWaypoint?.id)
        .animation(.easeInOut(duration: 0.2), value: viewModel.progress?.distanceToNextWaypoint)
    }
}

// MARK: - Improved Clock Compass (center)
struct ImprovedClockCompassView: View {
    @ObservedObject var viewModel: NavigationViewModel
    
    var body: some View {
        ZStack {
            // Background disk
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 320, height: 320)
                .shadow(color: .black.opacity(0.4), radius: 12)
            
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 280, height: 280)
            
            // Clock face with prominent numbers
            ClockFaceNumbers()
            
            // Arrow hand
            if let progress = viewModel.progress {
                ClockArrowHand(
                    headingError: Double(progress.headingError),
                    color: progress.clockArrowColor
                )
                .frame(width: 240, height: 240)
            }
            
            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.5), radius: 3)
            
            // Instruction text below clock
            if let progress = viewModel.progress {
                VStack(spacing: 4) {
                    Text(progress.clockInstructionText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(progress.degreeHelperText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                )
                .offset(y: 200)
            }
        }
    }
}

// MARK: - Clock Face with Prominent Numbers
struct ClockFaceNumbers: View {
    var body: some View {
        ZStack {
            Text("12")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .offset(y: -120)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            Text("3")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .offset(x: 120)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            Text("6")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .offset(y: 120)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            Text("9")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .offset(x: -120)
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
    }
}

// MARK: - Clock Arrow Hand
struct ClockArrowHand: View {
    let headingError: Double
    let color: Color
    
    var body: some View {
        ZStack {
            // Arrow shaft (solid rectangle)
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 16, height: 120)
                .offset(y: -30)
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Arrow head (triangle) - Indraneel
            /*
            Path { path in
                path.move(to: CGPoint(x: 0, y: -90))
                path.addLine(to: CGPoint(x: -30, y: -55))
                path.addLine(to: CGPoint(x: 30, y: -55))
                path.closeSubpath()
            }
            .fill(color)
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            */
             
            // Glow effect when aligned
            if abs(headingError) < 0.15 { // ~8.6 degrees
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
            }
        }
        .rotationEffect(.degrees(headingError * 180 / .pi))
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: headingError)
    }
}

// MARK: - Destination Picker
struct DestinationPickerView: View {
    @ObservedObject var viewModel: NavigationViewModel
    @Environment(\.dismiss) private var dismiss
    
    let session: ARSession
    let onSelected: () -> Void
    
    var body: some View {
        NavigationView {
            List(viewModel.availableDestinations) { beacon in
                Button {
                    selectDestination(beacon)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(beacon.name)
                                .font(.headline)
                            
                            if !beacon.roomId.isEmpty,
                               let room = viewModel.map.room(withId: beacon.roomId) {
                                Text(room.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func selectDestination(_ beacon: Beacon) {
        guard let frame = session.currentFrame else { return }
        let currentPosition = CoordinateTransformManager.extractPosition(from: frame.camera)
        
        viewModel.selectDestination(beacon, currentPosition: currentPosition, session: session)
        onSelected()
        dismiss()
    }
}

// MARK: - Calibration Progress View
struct CalibrationProgressView: View {
    @ObservedObject var viewModel: CalibrationViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.calibrationState.displayMessage)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            if case .measuringBeacon(let index, let total) = viewModel.calibrationState {
                VStack(spacing: 8) {
                    Text("Beacon \(index + 1) of \(total)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    if index < viewModel.candidateBeacons.count {
                        Text(viewModel.candidateBeacons[index].beacon.name)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    ProgressView(value: viewModel.currentAlignment)
                        .tint(.green)
                        .frame(height: 8)
                    
                    Text("Alignment: \(Int(viewModel.currentAlignment * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button {
                        Task {
                            await viewModel.confirmBeaconMeasurement()
                        }
                    } label: {
                        Text("Confirm")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canConfirmMeasurement ? Color.green : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!viewModel.canConfirmMeasurement)
                }
            } else if case .completed(let calibration) = viewModel.calibrationState {
                VStack(spacing: 8) {
                    let icon = calibration.qualityRating == .excellent ? "✅" :
                              calibration.qualityRating == .good ? "✅" :
                              calibration.qualityRating == .fair ? "⚠️" : "❌"
                    
                    Text("\(icon) Calibration Complete")
                        .font(.title2.bold())
                        .foregroundColor(calibration.qualityRating == .poor ? .orange : .green)
                    
                    Text("Quality: \(calibration.qualityRating.rawValue)")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Text("Confidence: \(Int(calibration.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Text("Consistency: \(String(format: "%.1f", 100 - calibration.residualError))%")
                        .font(.caption)
                        .foregroundColor(calibration.residualError > 20 ? .orange : .white.opacity(0.8))
                    
                    if calibration.confidence < 0.6 {
                        Text("Consider recalibrating for better accuracy")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
    }
}

#Preview {
    let sampleMap = IndoorMap(name: "Sample Home")
    NavigationMainView(map: sampleMap, mapFileName: "sample.arworldmap")
}
