//
//  NavigationMainView.swift
//  GuideLight v3
//
//  Complete file with next waypoint display and arrival messages
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
    
    // MARK: - Navigation Overlay
    
    private func navigationOverlay(navViewModel: NavigationViewModel) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Status Bar
                navigationStatusBar(navViewModel: navViewModel)
                
                Spacer()
                
                // Center Clock Compass
                ClockCompassView(viewModel: navViewModel)
                
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
    
    // MARK: - Status Bar (Shows Next Waypoint)
    
    private func navigationStatusBar(navViewModel: NavigationViewModel) -> some View {
        VStack(spacing: 8) {
            // Final destination at top
            if let destination = navViewModel.destinationBeacon {
                Text("To: \(destination.name)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
            }
            
            // Current/next waypoint (immediate target)
            if let progress = navViewModel.progress,
               let currentWaypoint = navViewModel.currentWaypoint {
                VStack(spacing: 4) {
                    Text("🏁 Next: \(currentWaypoint.name)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        // Distance to NEXT waypoint
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.forward")
                                .font(.caption)
                            Text(navViewModel.formatDistance(progress.distanceToNextWaypoint))
                                .font(.title2.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        
                        // Time remaining
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(navViewModel.formatTime(progress.estimatedTimeRemaining))
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                    
                    // Progress indicator
                    if let path = navViewModel.currentPath {
                        Text("Step \(navViewModel.currentWaypointIndex + 1) of \(path.waypoints.count)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
        .padding(.top, 60)
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
}

// MARK: - Clock Compass View
struct ClockCompassView: View {
    @ObservedObject var viewModel: NavigationViewModel
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 280, height: 280)
            
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 4)
                .frame(width: 240, height: 240)
            
            ClockNumbers()
            ClockHourMarkers()
            
            if let progress = viewModel.progress {
                ClockArrow(
                    headingError: Double(progress.headingError),
                    color: progress.clockArrowColor
                )
                .frame(width: 200, height: 200)
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            if let progress = viewModel.progress {
                VStack(spacing: 4) {
                    Text(progress.clockInstructionText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(progress.degreeHelperText)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .offset(y: 160)
            }
        }
    }
}

struct ClockNumbers: View {
    var body: some View {
        ZStack {
            Text("12").font(.system(size: 24, weight: .bold)).foregroundColor(.white).offset(y: -110)
            Text("3").font(.system(size: 24, weight: .bold)).foregroundColor(.white).offset(x: 110)
            Text("6").font(.system(size: 24, weight: .bold)).foregroundColor(.white).offset(y: 110)
            Text("9").font(.system(size: 24, weight: .bold)).foregroundColor(.white).offset(x: -110)
        }
    }
}

struct ClockHourMarkers: View {
    let hours = [1, 2, 4, 5, 7, 8, 10, 11]
    var body: some View {
        ZStack {
            ForEach(hours, id: \.self) { hour in
                Text("\(hour)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .offset(y: -95)
                    .rotationEffect(.degrees(Double(hour) * 30))
                    .rotationEffect(.degrees(-Double(hour) * 30))
            }
        }
    }
}

struct ClockArrow: View {
    let headingError: Double
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .bottom, endPoint: .top))
                .frame(width: 14, height: 110)
                .offset(y: -25)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: -80))
                path.addLine(to: CGPoint(x: -28, y: -45))
                path.addLine(to: CGPoint(x: 28, y: -45))
                path.closeSubpath()
            }
            .fill(color)
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            
            if abs(headingError) < 0.087 {
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.5), .clear], center: .center, startRadius: 30, endRadius: 70))
                    .frame(width: 140, height: 140)
            }
        }
        .rotationEffect(.degrees(headingError * 180 / .pi))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: headingError)
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
