//
//  trunkIKApp.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/9/24.
//

import SwiftUI
import RealityKit

@Observable class Shapes {
    var baseEntity = ModelEntity(mesh: .generateSphere(radius:0.01), materials: [SimpleMaterial(color: .white, isMetallic: false)])
    var rootJoint = ModelEntity(mesh: .generateSphere(radius:0.01), materials: [SimpleMaterial(color: .red, isMetallic: false)])
    
    var positionSetEntity = ModelEntity(mesh: .generateSphere(radius:0.0125), materials: [SimpleMaterial(color: .white, isMetallic: false)])
    var x_axis = ModelEntity(mesh: .generateCylinder(height:0.15, radius:0.005), materials: [SimpleMaterial(color: .white, isMetallic: false)])
    var z_axis = ModelEntity(mesh: .generateCylinder(height:0.45, radius:0.005), materials: [SimpleMaterial(color: .white, isMetallic: false)])
    
    var disk1 = ModelEntity(mesh: .generateCylinder(height:0.015, radius:0.025), materials: [SimpleMaterial(color: .black, isMetallic: false)])
    var disk2 = ModelEntity(mesh: .generateCylinder(height:0.015, radius:0.025), materials: [SimpleMaterial(color: .black, isMetallic: false)])
    var disk3 = ModelEntity(mesh: .generateCylinder(height:0.015, radius:0.025), materials: [SimpleMaterial(color: .black, isMetallic: false)])
    
    var segment1 = Entity()
    var segment2 = Entity()
    var segment3 = Entity()
    
    var parent1 = Entity()
    var parent2 = Entity()
    var parent3 = Entity()

}

class TrunkState: ObservableObject{
    // for base positioning
    var lastBasePosition: SIMD3<Float>? = nil
    var recentBasePositions: [SIMD3<Float>] = []
    var currentBaseHandPosition: SIMD3<Float>? = nil
    
    // for trunk angles
    var recentQuaternions: [[simd_quatf]] = [[], [], []] // nested vector
    var maxPositions: Int = 10
    
    var lastDirections: [SIMD3<Float>?] = [nil, nil, nil]
    var currentDirections: [SIMD3<Float>] = [SIMD3<Float>(0,-1,0), SIMD3<Float>(0,-1,0), SIMD3<Float>(0,-1,0)] // start off vertical
    
    // in optitrack coordinates
    var diskPositions: [String : SIMD3<Float>] = ["disk1": SIMD3<Float>(0,0,0),
                                                  "disk2": SIMD3<Float>(0,0,0),
                                                  "disk3": SIMD3<Float>(0,0,0)]
    
}

enum AppState {
    case positioning
    case rotating
    case interaction
}

@Observable class AppStateManager {
    var currentState: AppState = .positioning
}

@main
struct trunkIKApp: App {
    
    @State private var appModel = AppModel()
    @State private var shapes = Shapes()
    
    @State private var appStateManager = AppStateManager()

    // State properties for position and rotation confirmation
    @State private var isPositionConfirmed = false
    @State private var isRotationConfirmed = false
    
    // Initialize the system here
    init() {
        IKTargetPositionerSystem.registerSystem()
        print("IKTargetPositionerSystem registered")
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView(
                isPositionConfirmed: $isPositionConfirmed,
                isRotationConfirmed: $isRotationConfirmed
//                initialOrientation: simd_quatf(ix: 0,iy: 0,iz: 0,r: 0),
//                initialPosition: SIMD3<Float>(0,0,0)
            )
            .environment(appModel)
            .environment(shapes)
            .environmentObject(DataManager.shared.trunkState)
            .environment(appStateManager)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView(
                isPositionConfirmed: $isPositionConfirmed,
                isRotationConfirmed: $isRotationConfirmed
            )
            .environment(appModel)
            .environment(shapes)
            .environmentObject(DataManager.shared.trunkState)
            .environment(appStateManager)
            .onAppear {
                appModel.immersiveSpaceState = .open
                appModel.startServer()
            }
            .onDisappear {
                appModel.immersiveSpaceState = .closed
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
