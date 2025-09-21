//
//  SettingsView.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 9/21/25.
//

import SwiftUI
import Foundation

// MARK: - Notification for launching the mapping flow
extension Notification.Name {
    static let triggerPathfinderMapping = Notification.Name("TriggerPathfinderMapping")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    // NO @StateObject needed - using singleton

    var body: some View {
        NavigationView {
            Form {
                // =========================
                // MARK: Pathfinder Settings
                // =========================
                Section("Pathfinder Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mapping & Navigation")
                            .font(.headline)

                        // Launch BuildMap flow
                        Button {
                            NotificationCenter.default.post(name: .triggerPathfinderMapping, object: nil)
                        } label: {
                            HStack {
                                Image(systemName: "viewfinder")
                                Text("Start 2D Mapping")
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        // Basic info text
                        Text("Create indoor maps by placing beacons at important locations and marking doorways between rooms.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // =========================
                // MARK: JSON Maps Section
                // =========================
                Section("JSON Maps") {
                    NavigationLink(destination: SimpleJSONMapsListView()) {
                        Text("Manage Maps")
                    }
                }


                // =========================
                // MARK: App Information
                // =========================
                Section("About") {
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
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
