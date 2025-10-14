//
//  SettingsView.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 9/21/25.
//

import SwiftUI
import Foundation
import AVFoundation   // ✅ Needed for AVSpeechSynthesisVoice default code

// MARK: - Notification for launching the mapping flow
extension Notification.Name {
    static let triggerPathfinderMapping = Notification.Name("TriggerPathfinderMapping")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voice = VoiceGuide.shared

    // Persisted app settings
    @AppStorage("voiceFirstEnabled") private var voiceEnabled: Bool = UIAccessibility.isVoiceOverRunning
    @AppStorage("voiceRate")  private var voiceRate: Double  = 0.47     // 0.2...0.7 recommended
    @AppStorage("voicePitch") private var voicePitch: Double = 1.00     // 0.5...2.0
    @AppStorage("voiceLocale") private var voiceLocale: String = AVSpeechSynthesisVoice.currentLanguageCode()
    @AppStorage("voiceIdentifier") private var voiceIdentifier: String = "" // empty = system default by language

    // 🔧 New: Navigation preferences for steps & speed
    @AppStorage("stepsPerMeter") private var stepsPerMeter: Double = 1.35     // typical 1.3–1.5
    @AppStorage("walkingSpeedMps") private var walkingSpeedMps: Double = 1.20 // indoor pace ~1.0–1.4

    var body: some View {
        NavigationView {
            Form {

                // =========================
                // MARK: Accessibility & Voice
                // =========================
                Section {
                    Toggle(isOn: $voiceEnabled) {
                        Label("Voice Guidance", systemImage: "waveform")
                    }
                    .onChange(of: voiceEnabled) { newValue in
                        voice.setEnabled(newValue)
                        if newValue { voice.speak("Voice guidance enabled.") }
                        else { voice.stop() }
                    }

                    if voiceEnabled {
                        // Specific Voice Picker (identifier)
                        Picker("Voice", selection: $voiceIdentifier) {
                            ForEach(voice.availableVoiceOptions) { option in
                                Text(option.display).tag(option.id) // tag type = String
                            }
                        }
                        .onChange(of: voiceIdentifier) { newValue in
                            voice.setVoiceIdentifier(newValue)
                            voice.speak("Voice changed.")
                        }

                        // Language fallback (used only when identifier is empty)
                        Picker("Language (fallback)", selection: $voiceLocale) {
                            let common = ["en-US","en-GB","es-ES","fr-FR","de-DE","hi-IN"]
                            ForEach(common, id: \.self) { code in
                                Text(code).tag(code) // tag type = String
                            }
                        }
                        .onChange(of: voiceLocale) { newValue in
                            voice.setLocale(newValue)
                            if voiceIdentifier.isEmpty { voice.speak("Language changed.") }
                        }

                        // Speech speed
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Speech Speed", systemImage: "speedometer")
                                Spacer()
                                Text(String(format: "%.2f", voiceRate))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $voiceRate, in: 0.20...0.70, step: 0.01) {
                                Text("Speech Speed")
                            } minimumValueLabel: {
                                Text("Slow")
                            } maximumValueLabel: {
                                Text("Fast")
                            }
                            .onChange(of: voiceRate) { newValue in
                                voice.setRate(newValue)
                                voice.speak("Speech speed adjusted.")
                            }
                        }

                        // Tone (Pitch)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Tone (Pitch)", systemImage: "slider.horizontal.3")
                                Spacer()
                                Text(String(format: "%.2f", voicePitch))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $voicePitch, in: 0.70...1.30, step: 0.01) {
                                Text("Tone")
                            } minimumValueLabel: {
                                Text("Lower")
                            } maximumValueLabel: {
                                Text("Higher")
                            }
                            .onChange(of: voicePitch) { newValue in
                                voice.setPitch(newValue)
                                voice.speak("Pitch adjusted.")
                            }
                        }

                        // Test Voice
                        Button {
                            voice.speak(.test)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.2.fill")
                                Text("Test Voice")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .accessibilityLabel("Test Voice")
                        .accessibilityHint("Plays a short sample with the current voice settings.")
                        .padding(.top, 2)
                    }
                } header: {
                    Text("Accessibility & Voice")
                }

                // =========================
                // MARK: Navigation Preferences (NEW)
                // =========================
                Section {
                    // Steps per meter
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Steps per meter", systemImage: "figure.walk")
                            Spacer()
                            Text(String(format: "%.2f", stepsPerMeter))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $stepsPerMeter, in: 0.80...2.50, step: 0.05)
                        Text("Typical adult stride ≈ 1.3–1.5 steps/m")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Walking speed (m/s)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Walking speed", systemImage: "speedometer")
                            Spacer()
                            Text(String(format: "%.2f m/s", walkingSpeedMps))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $walkingSpeedMps, in: 0.40...2.00, step: 0.05)
                        Text("Indoor pace: ~1.0–1.4 m/s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Navigation Preferences")
                } footer: {
                    Text("These settings affect the navigation dock: distance is shown in steps, and time is calculated from your walking speed.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // =========================
                // MARK: Pathfinder Settings
                // =========================
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mapping & Navigation")
                            .font(.headline)

                        Button {
                            NotificationCenter.default.post(name: .triggerPathfinderMapping, object: nil)
                        } label: {
                            HStack {
                                Image(systemName: "viewfinder")
                                Text("Start 2D Mapping")
                            }
                        }
                        .buttonStyle(.bordered)

                        Text("Create indoor maps by placing beacons at important locations and marking doorways between rooms.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Pathfinder Settings")
                }

                // =========================
                // MARK: JSON Maps Section
                // =========================
                Section {
                    NavigationLink(destination: SimpleJSONMapsListView()) {
                        Text("Manage Maps")
                    }
                } header: {
                    Text("JSON Maps")
                }

                // =========================
                // MARK: App Information
                // =========================
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GuideLight")
                            .font(.headline)

                        Text("Indoor navigation assistance for blind users")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Attach mapping launcher
        .mappingLauncher()
    }
}

#Preview {
    SettingsView()
}
