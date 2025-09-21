import SwiftUI
import AVFoundation
import UIKit

enum HubDestination: String, Identifiable {
    case navigation = "Pathfinder"
    case mail       = "MailReader"
    case settings   = "Settings"
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var pushed: HubDestination? = nil
    @AppStorage("voiceFirstEnabled") private var voiceFirstEnabled: Bool = UIAccessibility.isVoiceOverRunning

    // Speech & haptics
    @State private var speech = AVSpeechSynthesizer()
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)

    private let swipeThreshold: CGFloat = 60

    // Brand colors
    private let brandNavy   = Color(red: 0.11, green: 0.17, blue: 0.29)
    private let brandYellow = Color(red: 1.00, green: 0.84, blue: 0.35)

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                brandNavy.ignoresSafeArea()

                VStack(spacing: 28) {
                    // MARK: Header / Logo
                    VStack(spacing: 16) {
                        if UIImage(named: "GuideLightLogo") != nil {
                            Image("GuideLightLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 350)
                                .accessibilityHidden(true)
                        } else {
                            Text("GuideLight")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 24)

                    // MARK: Primary CTA – Pathfinder
                    NavigationLink(destination: PathfinderView()) {
                        HStack(spacing: 14) {
                            AppIcon(name: "NavHero")
                                .foregroundStyle(.white)
                                .frame(width: 75, height: 75)

                            Text("Pathfinder")
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .accessibilityLabel("Pathfinder")
                    .accessibilityHint("Open indoor navigation")
                    .simultaneousGesture(TapGesture().onEnded {
                        select(.navigation)
                    })

                    // MARK: Secondary CTA – Read Mail (Temporarily Disabled)
                    Button {
                        // Temporarily disabled
                    } label: {
                        HStack(spacing: 14) {
                            AppIcon(name: "MailHero")
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 75, height: 75)

                            Text("MailReader")
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.5), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .accessibilityLabel("MailReader - Temporarily Disabled")
                    .accessibilityHint("Feature under maintenance")
                    .disabled(true)

                    Spacer(minLength: 0)
                }

                // MARK: Settings gear (bottom-right)
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Opens app settings and map management")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    select(.settings)
                })
                .padding(.trailing, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            // MARK: Swipe shortcuts
            .gesture(
                DragGesture(minimumDistance: 20).onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        if dx > swipeThreshold {
                            // Navigate to Pathfinder
                        }
                        // Mail reader temporarily disabled
                    } else if dy < -swipeThreshold {
                        // Navigate to Settings
                    }
                }
            )
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force stack style on all devices
        .onAppear {
            hapticLight.prepare()
            hapticHeavy.prepare()
            
            if voiceFirstEnabled {
                speak("Home. Pathfinder for navigation, or tap the gear for Settings.")
            } else {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Swipe right for Pathfinder, or tap the gear for Settings.")
            }
        }
    }

    private func select(_ dest: HubDestination) {
        hapticHeavy.impactOccurred()
        if voiceFirstEnabled {
            speak("\(dest.rawValue) selected.")
        }
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speech.speak(utterance)
    }
}

// MARK: - Destination Views
struct PathfinderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Pathfinder Navigation")
                .font(.title.weight(.semibold))
            
            Text("Indoor navigation feature will use maps created with the BuildMap tool.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            NavigationLink("Go to Settings", destination: SettingsView())
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Pathfinder")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - App Icon Helper
private struct AppIcon: View {
    let name: String
    
    var body: some View {
        if let _ = UIImage(named: name) {
            Image(name)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
        } else {
            // Fallback SF Symbol
            Image(systemName: name == "NavHero" ? "location.circle.fill" : "envelope.open.fill")
                .resizable()
                .scaledToFit()
        }
    }
}

#Preview {
    ContentView()
}
