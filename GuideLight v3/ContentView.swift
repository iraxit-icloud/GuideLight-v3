import SwiftUI
import UIKit

enum HubDestination: String, Identifiable {
    case navigation = "Pathfinder"
    case settings   = "Settings"
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var showingPathNavigation = false
    @AppStorage("voiceFirstEnabled") private var voiceFirstEnabled: Bool = UIAccessibility.isVoiceOverRunning

    // Voice & haptics
    @StateObject private var voice = VoiceGuide.shared
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

                VStack(spacing: 24) {
                    // MARK: Portal Logo + Title + short story line
                    VStack(spacing: 14) {
                        ARPortalLogoView(imageName: "GuideLightLogo", size: 220)
                            .padding(.top, 24)

                        Text("GuideLight")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Your voice, your steps, your guide.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .accessibilityHidden(true)
                    }

                    // MARK: Primary CTA – Start Navigation
                    Button {
                        select(.navigation)
                        voice.speak(.startingNav)
                        showingPathNavigation = true
                    } label: {
                        Text("Start Navigation")
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.white, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Start navigation. Double tap to begin.")
                    .accessibilityHint("Opens indoor navigation.")

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

            // MARK: Swipe shortcuts (right swipe to start nav)
            .gesture(
                DragGesture(minimumDistance: 20).onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        if dx > swipeThreshold {
                            select(.navigation)
                            voice.speak(.startingNav)
                            showingPathNavigation = true
                        }
                    } else if dy < -swipeThreshold {
                        // future: swipe up for settings or help
                    }
                }
            )
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingPathNavigation) {
                PathNavigationLauncherView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            hapticLight.prepare()
            hapticHeavy.prepare()

            // Voice-first cues
            if voiceFirstEnabled {
                voice.speak(.welcome)
                voice.speak(.startPrompt)
                voice.speak(.homeHelp)
            } else {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Home. Start Navigation button, or tap the gear for Settings.")
            }
        }
    }

    private func select(_ dest: HubDestination) {
        hapticHeavy.impactOccurred()
        if voiceFirstEnabled {
            switch dest {
            case .navigation: voice.speak(.pathfinderSel)
            case .settings:   voice.speak(.settingsSel)
            }
        }
    }
}
