import SwiftUI

/// Animated “portal” that replaces the static logo.
/// Shows a glowing icon with radiating scanning waves (AR vibe).
struct ARPortalLogoView: View {
    /// Provide either an asset name or SF Symbol. Defaults to your app logo asset.
    var imageName: String = "GuideLightLogo"
    var size: CGFloat = 220

    // Default wave styling — tuned for dark navy background
    private let waveColor = Color(red: 1.00, green: 0.84, blue: 0.35) // brand yellow

    var body: some View {
        ZStack {
            ScanningWaves(
                color: waveColor,
                ringCount: 4,
                cycle: 3.6,             // slower than before (was ~2.2)
                maxRadiusFactor: 0.50,  // larger spread
                maxLineWidth: 5,
                baseOpacity: 0.28       // more visible
            )
            .frame(width: size * 2.1, height: size * 2.1) // bigger canvas
            .accessibilityHidden(true)

            // If asset exists, use it; else fallback to an SF Symbol
            if UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: waveColor.opacity(0.55), radius: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(waveColor.opacity(0.25), lineWidth: 2)
                            .blur(radius: 1.5)
                            .padding(6)
                    )
            } else {
                Image(systemName: "figure.walk.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundStyle(.white)
                    .shadow(color: waveColor.opacity(0.55), radius: 22)
            }
        }
        .accessibilityLabel("GuideLight portal logo")
    }
}

private struct ScanningWaves: View {
    var color: Color
    var ringCount: Int = 4
    var cycle: Double = 3.6              // seconds per full cycle
    var maxRadiusFactor: CGFloat = 0.62  // relative to canvas min dimension
    var maxLineWidth: CGFloat = 12
    var baseOpacity: Double = 0.28

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle
                let center = CGPoint(x: size.width/2, y: size.height/2)
                let maxR = min(size.width, size.height) * maxRadiusFactor

                for i in 0..<ringCount {
                    let offset = Double(i) * (1.0 / Double(ringCount)) * 0.9
                    let p = (phase + offset).truncatingRemainder(dividingBy: 1.0)
                    let r = maxR * p
                    var path = Path()
                    path.addEllipse(in: CGRect(x: center.x - r,
                                               y: center.y - r,
                                               width: r * 2,
                                               height: r * 2))

                    // Fade out as it expands. Keep brighter than before for visibility.
                    let alpha = (1.0 - p)
                    let opacity = baseOpacity * alpha

                    ctx.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        lineWidth: max(1, maxLineWidth * (1.0 - p))
                    )
                }
            }
            // Keep additive blending so yellow glows stack nicely
            .blendMode(.plusLighter)
        }
    }
}
