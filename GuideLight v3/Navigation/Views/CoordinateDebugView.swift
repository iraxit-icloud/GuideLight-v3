//
//  CoordinateDebugView.swift
//  Debug Overlay for X,Z Coordinates (Horizontal Plane)
//  FIXED: Now shows X,Z coordinates (Y is vertical height)
//

import SwiftUI
import simd

// MARK: - Coordinate Debug View
struct CoordinateDebugView: View {
    @ObservedObject var viewModel: PathNavigationViewModel
    @AppStorage("showCoordinateDebug") private var showCoordinateDebug = true
    
    var body: some View {
        VStack {
            Spacer()
            
            if showCoordinateDebug && viewModel.navigationState == .navigating {
                debugPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showCoordinateDebug)
    }
    
    private var debugPanel: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.green)
                Text("Coordinate Debug (X,Z Horizontal)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    showCoordinateDebug = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Current Position
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Your Position")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if let currentPos = viewModel.getCurrentCameraPosition() {
                    HStack(spacing: 16) {
                        CoordinateLabel(label: "X", value: currentPos.x, color: .red)
                        CoordinateLabel(label: "Z", value: currentPos.z, color: .blue)
                    }
                    
                    // Show Y (height) separately
                    HStack {
                        Text("Height (Y):")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(String(format: "%.3f m", currentPos.y))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 2)
                } else {
                    Text("Position unavailable")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 4)
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Target Position
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "flag.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Next Target")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let target = viewModel.getNextTarget() {
                        Text("(\(target.name))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                if let target = viewModel.getNextTarget() {
                    HStack(spacing: 16) {
                        CoordinateLabel(label: "X", value: target.position.x, color: .red)
                        CoordinateLabel(label: "Z", value: target.position.z, color: .blue)
                    }
                    
                    // Show Y (height) separately
                    HStack {
                        Text("Height (Y):")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(String(format: "%.3f m", target.position.y))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 2)
                } else {
                    Text("No target")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 4)
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Distance and Delta
            if let currentPos = viewModel.getCurrentCameraPosition(),
               let target = viewModel.getNextTarget() {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "ruler.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("Distance & Delta")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    HStack(spacing: 16) {
                        // Total Horizontal Distance (X,Z only)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distance")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Text(String(format: "%.2f m", viewModel.distanceToNextPoint))
                                .font(.caption.monospacedDigit().bold())
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        // Delta X
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ΔX")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Text(String(format: "%.2f m", target.position.x - currentPos.x))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.red.opacity(0.8))
                        }
                        
                        // Delta Z
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ΔZ")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Text(String(format: "%.2f m", target.position.z - currentPos.z))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                    
                    // Show Y delta separately (should be minimal for floor nav)
                    HStack {
                        Text("ΔY (Height):")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        Text(String(format: "%.3f m", target.position.y - currentPos.y))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }
            
            // Coordinate System Info
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.caption2)
                Text("Navigation uses X,Z (horizontal plane)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 4)
            
            HStack {
                Image(systemName: "arrow.up.and.down")
                    .foregroundColor(.cyan)
                    .font(.caption2)
                Text("Y = vertical height (ignored)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.bottom, 100) // Above bottom controls
    }
}

// MARK: - Coordinate Label Component
struct CoordinateLabel: View {
    let label: String
    let value: Float
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(color.opacity(0.8))
            
            Text(String(format: "%.3f m", value))
                .font(.caption.monospacedDigit())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(color.opacity(0.5), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Toggle Button for Debug View
struct CoordinateDebugToggle: View {
    @AppStorage("showCoordinateDebug") private var showCoordinateDebug = true
    
    var body: some View {
        Button {
            showCoordinateDebug.toggle()
        } label: {
            Image(systemName: showCoordinateDebug ? "location.circle.fill" : "location.circle")
                .font(.title3)
                .foregroundColor(.white)
                .padding(8)
                .background(showCoordinateDebug ? .green.opacity(0.7) : .gray.opacity(0.7))
                .clipShape(Circle())
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        CoordinateDebugView(viewModel: PathNavigationViewModel())
    }
}
