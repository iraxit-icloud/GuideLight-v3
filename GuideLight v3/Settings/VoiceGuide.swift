//
//  VoiceGuide.swift
//  GuideLight
//
//  Created by Indraneel Rakshit on 10/13/25.
//

import Foundation
import AVFoundation
import SwiftUI

/// Centralized text-to-speech service for all voice cues in the app.
/// Users can toggle on/off, choose a specific voice (by identifier), language fallback,
/// and adjust speaking rate + pitch (tone).
@MainActor
final class VoiceGuide: ObservableObject {
    static let shared = VoiceGuide()

    private let synth = AVSpeechSynthesizer()

    // Global settings persisted across app
    @AppStorage("voiceFirstEnabled") private var voiceEnabled: Bool = UIAccessibility.isVoiceOverRunning
    @AppStorage("voiceLocale")       private var voiceLocale: String = AVSpeechSynthesisVoice.currentLanguageCode()
    @AppStorage("voiceRate")         private var voiceRate: Double = 0.47
    @AppStorage("voicePitch")        private var voicePitch: Double = 1.00          // 0.5 ... 2.0
    @AppStorage("voiceIdentifier")   private var voiceIdentifier: String = ""       // empty = use language

    // MARK: - Public controls
    func isEnabled() -> Bool { voiceEnabled }
    func setEnabled(_ new: Bool) { voiceEnabled = new }
    func setLocale(_ code: String) { voiceLocale = code }
    func setVoiceIdentifier(_ id: String) { voiceIdentifier = id }
    func setPitch(_ value: Double) { voicePitch = min(max(value, 0.5), 2.0) }
    func setRate(_ value: Double)  { voiceRate  = min(max(value, 0.2), 0.7) }

    // MARK: - Speak
    func speak(_ cue: VoiceCue) {
        speak(NSLocalizedString(cue.rawValue, comment: ""))
    }

    func speak(_ text: String) {
        guard voiceEnabled, !text.isEmpty else { return }
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)

        // Prefer explicit identifier; else fallback to language
        if !voiceIdentifier.isEmpty, let v = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = v
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: voiceLocale)
        }

        utterance.rate  = Float(voiceRate)          // 0.0 ... 1.0 (system clamps)
        utterance.pitchMultiplier = Float(voicePitch) // 0.5 ... 2.0

        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: - Voice catalog helpers (curated list for Settings UI)

    struct VoiceOption: Identifiable, Hashable {
        let id: String            // identifier ("" = System Default by language)
        let name: String          // "Samantha", "Daniel", etc.
        let language: String      // "en-US", "en-GB", etc.
        let display: String       // Friendly label for picker
    }

    /// Curated, commonly-available Apple voices (compact identifiers present on most devices).
    /// We will show only the ones that exist on the current device/simulator.
    private let curatedVoiceCatalog: [(id: String, name: String, language: String)] = [
        ("com.apple.ttsbundle.Samantha-compact", "Samantha", "en-US"),
        ("com.apple.ttsbundle.Daniel-compact",   "Daniel",   "en-GB"),
        ("com.apple.ttsbundle.Karen-compact",    "Karen",    "en-AU"),
        ("com.apple.ttsbundle.Moira-compact",    "Moira",    "en-IE"),
        ("com.apple.ttsbundle.Rishi-compact",    "Rishi",    "en-IN"),
        ("com.apple.ttsbundle.Monica-compact",   "Mónica",   "es-ES"),
        ("com.apple.ttsbundle.Thomas-compact",   "Thomas",   "fr-FR"),
        ("com.apple.ttsbundle.Anna-compact",     "Anna",     "de-DE"),
    ]

    /// First entry: "System Default (by Language …)"; then curated voices that are installed.
    var availableVoiceOptions: [VoiceOption] {
        var options: [VoiceOption] = []

        // System Default (uses language fallback)
        let lang = AVSpeechSynthesisVoice(language: voiceLocale)?.language ?? voiceLocale
        options.append(
            VoiceOption(
                id: "",
                name: "System Default",
                language: lang,
                display: "System Default (by Language \(lang))"
            )
        )

        // Add curated voices that exist on this device
        for v in curatedVoiceCatalog {
            if let installed = AVSpeechSynthesisVoice(identifier: v.id) {
                options.append(
                    VoiceOption(
                        id: installed.identifier,
                        name: v.name,
                        language: v.language,
                        display: "\(v.name) • \(v.language)"
                    )
                )
            }
        }
        return options
    }

    func currentVoiceName() -> String {
        if voiceIdentifier.isEmpty {
            return "System Default (\(voiceLocale))"
        }
        return AVSpeechSynthesisVoice(identifier: voiceIdentifier)?.name ?? "Custom"
    }
}

/// All standardized cue keys your app can use.
/// Keep matching entries in Localizable.strings.
enum VoiceCue: String {
    case welcome          = "voice.welcome"
    case startPrompt      = "voice.startPrompt"
    case homeHelp         = "voice.homeHelp"
    case startingNav      = "voice.startingNav"
    case pathfinderSel    = "voice.pathfinderSel"
    case settingsSel      = "voice.settingsSel"
    case errorNoMap       = "voice.errorNoMap"
    case test             = "voice.test"          // for “Test Voice” button
}
