//
//  RelocalizationState.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/9/25.
//


//
//  RelocalizationView.swift
//  UI for ARWorldMap Relocalization Process
//
//  Provides visual feedback while ARKit aligns coordinate frames
//

import SwiftUI
import ARKit

// MARK: - Relocalization State
enum RelocalizationState: Equatable {
    case notStarted
    case scanning
    case limited
    case mapped
    case failed(String)
    
    var displayText: String {
        switch self {
        case .notStarted:
            return "Preparing..."
        case .scanning:
            return "Scanning environment..."
        case .limited:
            return "Limited tracking. Move your device slowly."
        case .mapped:
            return "Environment recognized!"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
    
    var icon: String {
        switch self {
        case .notStarted:
            return "hourglass"
        case .scanning:
            return "viewfinder.circle"
        case .limited:
            return "exclamationmark.triangle"
        case .mapped:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notStarted:
            return .gray
        case .scanning:
            return .blue
        case .limited:
            return .orange
        case .mapped:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - Relocalization View
struct RelocalizationView: View {
    let state: RelocalizationState
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(state.color.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: state.icon)
                        .font(.system(size: 50))
                        .foregroundColor(state.color)
                        .scaleEffect(isAnimating && state == .scanning ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                // Status Text
                VStack(spacing: 8) {
                    Text(state.displayText)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if state == .scanning || state == .limited {
                        Text("Point your camera around the room")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                
                // Progress Indicator
                if state == .scanning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
                
                // Action Buttons
                if case .failed = state {
                    HStack(spacing: 16) {
                        Button {
                            onRetry()
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Button {
                            onCancel()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                } else if state == .limited {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                // Tips
                if state == .scanning || state == .limited {
                    VStack(alignment: .leading, spacing: 8) {
                        tipRow(icon: "hand.point.up.left", text: "Move slowly and steadily")
                        tipRow(icon: "light.max", text: "Ensure good lighting")
                        tipRow(icon: "square.3.stack.3d", text: "Point at unique features")
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(32)
        }
        .onAppear {
            if state == .scanning {
                isAnimating = true
            }
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Relocalization Progress View
struct RelocalizationProgressView: View {
    let mappingStatus: ARFrame.WorldMappingStatus
    let onCancel: () -> Void
    
    var body: some View {
        let state = relocalizationState(from: mappingStatus)
        
        RelocalizationView(
            state: state,
            onRetry: {},
            onCancel: onCancel
        )
    }
    
    private func relocalizationState(from status: ARFrame.WorldMappingStatus) -> RelocalizationState {
        switch status {
        case .notAvailable:
            return .notStarted
        case .limited:
            return .limited
        case .extending, .mapped:
            return .mapped
        @unknown default:
            return .scanning
        }
    }
}

// MARK: - Compact Relocalization Indicator
struct CompactRelocalizationIndicator: View {
    let mappingStatus: ARFrame.WorldMappingStatus
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
            
            if mappingStatus == .limited || mappingStatus == .notAvailable {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var statusIcon: String {
        switch mappingStatus {
        case .notAvailable:
            return "exclamationmark.triangle.fill"
        case .limited:
            return "viewfinder.circle"
        case .extending, .mapped:
            return "checkmark.circle.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var statusText: String {
        switch mappingStatus {
        case .notAvailable:
            return "Not Ready"
        case .limited:
            return "Scanning..."
        case .extending:
            return "Extending"
        case .mapped:
            return "Ready"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var statusColor: Color {
        switch mappingStatus {
        case .notAvailable:
            return .red
        case .limited:
            return .orange
        case .extending, .mapped:
            return .green
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Preview
#Preview("Scanning") {
    RelocalizationView(
        state: .scanning,
        onRetry: {},
        onCancel: {}
    )
}

#Preview("Limited") {
    RelocalizationView(
        state: .limited,
        onRetry: {},
        onCancel: {}
    )
}

#Preview("Mapped") {
    RelocalizationView(
        state: .mapped,
        onRetry: {},
        onCancel: {}
    )
}

#Preview("Failed") {
    RelocalizationView(
        state: .failed("Could not recognize environment"),
        onRetry: {},
        onCancel: {}
    )
}