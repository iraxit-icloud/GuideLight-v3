//
//  NavigationMainView.swift
//  GuideLight v3
//
//  Navigation view with speech recognition support (VoiceCommandCenter removed)
//

import SwiftUI
import ARKit
import SceneKit
import simd

struct NavigationMainView: View {
    @StateObject private var relocalizationManager: ARRelocalizationManager
    @StateObject private var calibrationViewModel: CalibrationViewModel
    @StateObject private var speechCenter = SimpleSpeechCommandCenter.shared
    @State private var navigationViewModel: NavigationViewModel?
    
    // Screen state
    @State private var showingCalibration = true
    @State private var showingDestinationPicker = false
    @State private var arSession = ARSession()
    
    private let map: IndoorMap
    private let mapFileName: String
    
    init(map: IndoorMap, mapFileName: String) {
        self.map = map
        self.mapFileName = mapFileName

        let rm = ARRelocalizationManager()
        _relocalizationManager = StateObject(wrappedValue: rm)
        _calibrationViewModel = StateObject(
            wrappedValue: CalibrationViewModel(map: map, relocalizationManager: rm)
        )
    }
    
    var body: some View {
        ZStack {
            // AR camera view
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
            
            // Overlays
            if showingCalibration {
                calibrationOverlay
            } else if let navViewModel = navigationViewModel {
                navigationOverlay(navViewModel: navViewModel)
            }
            
            // Voice debug overlay
            if speechCenter.isListening {
                debugVoiceOverlay
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
        .onAppear {
            setupNavigationScreen()
        }
        .onDisappear {
            speechCenter.stopListening()
        }
        // Voice command handling for navigation destinations
        .onReceive(NotificationCenter.default.publisher(for: .glVoiceNavigateCommand)) { note in
            guard !showingCalibration,
                  let navVM = navigationViewModel else { return }
            let raw = (note.userInfo?["destination"] as? String) ?? ""
            Task { @MainActor in
                await handleVoiceNavigatePhrase(rawDestination: raw, navVM: navVM)
            }
        }
    }
    
    // MARK: - Voice Debug Overlay
    private var debugVoiceOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(speechCenter.isListening ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text("Speech: \(speechCenter.isListening ? "ON" : "OFF")")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    
                    if !speechCenter.lastHeardText.isEmpty {
                        Text("Heard: \(speechCenter.lastHeardText)")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.7))
            )
            .padding(.horizontal)
            .padding(.top, 50)
            
            Spacer()
        }
    }
    
    // MARK: - Setup Methods
    private func setupNavigationScreen() {
        // Keep speech recognition running during navigation
        speechCenter.startListening()
        
        // Speak navigation screen announcement
        VoiceGuide.shared.speak("Navigation screen.")
    }
    
    // MARK: - Voice handling helper
    @MainActor
    private func handleVoiceNavigatePhrase(rawDestination: String, navVM: NavigationViewModel) async {
        let trimmed = rawDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            VoiceGuide.shared.speak("Say, show me the path to, followed by a destination.")
            return
        }
        guard let frame = arSession.currentFrame else {
            VoiceGuide.shared.speak("Camera not ready yet.")
            return
        }
        let currentPosition = CoordinateTransformManager.extractPosition(from: frame.camera)
        switch await navVM.selectDestination(named: trimmed, session: arSession, currentPosition: currentPosition) {
        case .success(let pickedName):
            VoiceGuide.shared.speak("Taking you to \(pickedName).")
        case .ambiguous(let options):
            let list = options.prefix(3).map(\.name)
            if list.count == 2 {
                VoiceGuide.shared.speak("I found \(list[0]) and \(list[1]). Say first or second.")
            } else if list.count >= 3 {
                VoiceGuide.shared.speak("I found \(list[0]), \(list[1]), and \(list[2]). Say first, second, or third.")
            }
        case .notFound:
            VoiceGuide.shared.speak("I couldn't find \(trimmed). Say list destinations to hear options.")
        }
    }
    
    // MARK: - Calibration Overlay (EXISTING)
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
    
    // MARK: - Navigation Overlay (EXISTING)
    private func navigationOverlay(navViewModel: NavigationViewModel) -> some View {
        ZStack {
            VStack {
                Spacer()
                FloatingDockView(
                    viewModel: navViewModel,
                    formatTimeShort: formatTimeShort,
                    formatDistance: navViewModel.formatDistance
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                navigationControls(navViewModel: navViewModel)
                    .padding(.bottom, 8)
            }
            if navViewModel.showArrivalMessage, let message = navViewModel.arrivalMessage {
                arrivalMessageView(message: message)
            }
        }
    }
    
    // MARK: - Arrival Message (EXISTING)
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
            .transition(AnyTransition.scale(scale: 0.95).combined(with: .opacity))
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Controls (EXISTING)
    private func navigationControls(navViewModel: NavigationViewModel) -> some View {
        HStack(spacing: 20) {
            if case .navigating = navViewModel.navigationState {
                Button {
                    navViewModel.pauseNavigation()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.orange.opacity(0.95))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 5)
                }
            } else if case .paused = navViewModel.navigationState {
                Button {
                    navViewModel.resumeNavigation()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.green.opacity(0.95))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 5)
                }
            }
            
            Button {
                navViewModel.cancelNavigation()
                showingDestinationPicker = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red.opacity(0.95))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 5)
            }
        }
    }
    
    // MARK: - Completion (EXISTING)
    private func completeCalibration(_ calibration: CalibrationData) {
        let navVM = NavigationViewModel(map: map, calibration: calibration)
        navigationViewModel = navVM
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

// MARK: - Floating Curved Dock (EXISTING)
private struct FloatingDockView: View {
    @ObservedObject var viewModel: NavigationViewModel
    let formatTimeShort: (TimeInterval) -> String
    let formatDistance: (Float) -> String
    @AppStorage("stepsPerMeter") private var stepsPerMeter: Double = 1.35
    @AppStorage("walkingSpeedMps") private var walkingSpeedMps: Double = 1.20
    
    var body: some View {
        HStack(spacing: 16) {
            MiniCompassView(headingError: Double(viewModel.progress?.headingError ?? 0))
                .frame(width: 72, height: 72)
            
            VStack(alignment: .leading, spacing: 4) {
                if let progress = viewModel.progress {
                    HStack {
                        RoundedChip(text: formatDistance(progress.distanceToNextWaypoint))
                        RoundedChip(text: formatTimeShort(progress.estimatedTimeRemaining))
                    }
                    if let currentWaypoint = viewModel.currentWaypoint {
                        Text(currentWaypoint.name.isEmpty ? "Next waypoint" : currentWaypoint.name)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                } else {
                    Text("Calculating route...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(viewModel.veilOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.15), lineWidth: 1.5)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
}

private struct MiniCompassView: View {
    let headingError: Double
    private let arrowColor = Color.cyan
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.6))
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
            
            ClockArrowHand(headingError: headingError, color: arrowColor)
        }
        .frame(width: 72, height: 72)
    }
}

private struct RoundedChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}

struct ClockArrowHand: View {
    let headingError: Double
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [color, color.opacity(0.7)],
                                     startPoint: .bottom, endPoint: .top))
                .frame(width: 12, height: 48)
                .offset(y: -12)
            if abs(headingError) < 0.15 {
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.35), .clear],
                                         center: .center, startRadius: 20, endRadius: 56))
                    .frame(width: 84, height: 84)
            }
        }
        .rotationEffect(.degrees(headingError * 180 / Double.pi))
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: headingError)
    }
}

// MARK: - Destination Picker (EXISTING)
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
                            Text(beacon.name).font(.headline)
                            if !beacon.roomId.isEmpty,
                               let room = viewModel.map.room(withId: beacon.roomId) {
                                Text(room.name).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle").foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }
    
    private func selectDestination(_ beacon: Beacon) {
        guard let frame = session.currentFrame else { return }
        let currentPosition = CoordinateTransformManager.extractPosition(from: frame.camera)
        viewModel.selectDestination(beacon, currentPosition: currentPosition, session: session)
        onSelected(); dismiss()
    }
}

// MARK: - Calibration Progress View (EXISTING)
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
                    ProgressView(value: viewModel.currentAlignment).tint(.green).frame(height: 8)
                    Text("Alignment: \(Int(viewModel.currentAlignment * 100))%")
                        .font(.caption).foregroundColor(.white.opacity(0.8))
                    Button {
                        Task { await viewModel.confirmBeaconMeasurement() }
                    } label: {
                        Text("Confirm")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
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
                    Text("Quality: \(calibration.qualityRating.rawValue)").font(.caption).foregroundColor(.white)
                    Text("Confidence: \(Int(calibration.confidence * 100))%").font(.caption).foregroundColor(.white)
                    Text("Consistency: \(String(format: "%.1f", 100 - calibration.residualError))%")
                        .font(.caption)
                        .foregroundColor(calibration.residualError > 20 ? .orange : .white.opacity(0.8))
                    if calibration.confidence < 0.6 {
                        Text("Consider recalibrating for better accuracy")
                            .font(.caption2).foregroundColor(.orange).multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
    }
}
