//
//  NavigationARViewContainer.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/12/25.
//


//
//  NavigationARViewContainer.swift
//  Separate ARView container for Navigation (to avoid conflicts with BuildMapView)
//

import SwiftUI
import ARKit
import SceneKit

struct NavigationARViewContainer: UIViewRepresentable {
    let viewModel: PathNavigationViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session = viewModel.session
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true
        
        // Optional: Add grid or debugging features
        #if DEBUG
        // arView.debugOptions = [.showFeaturePoints]  // Uncomment for debugging
        #endif
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update if needed
    }
}