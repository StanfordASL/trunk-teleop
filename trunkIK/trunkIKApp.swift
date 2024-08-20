//
//  trunkIKApp.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/9/24.
//

import SwiftUI
import RealityKit

@Observable class Shapes {
    var baseEntity = Entity()
    var positionSetEntity = Entity()
    var x_axis = Entity()
    var z_axis = Entity()
    
    var segment1 = Entity()
    var segment2 = Entity()
    var segment3 = Entity()
    
    var parent1 = Entity()
    var parent2 = Entity()
    var parent3 = Entity()

    var disk1 = Entity()
    var disk2 = Entity()
    var disk3 = Entity()
}

@Observable class TrunkState {
    // for base positioning
    var lastBasePosition: SIMD3<Float>? = nil
    var recentBasePositions: [SIMD3<Float>] = []
    var currentBaseHandPosition: SIMD3<Float>? = nil
    
    // for trunk angles
    var recentQuaternions: [[simd_quatf]] = [[], [], []] // nested vector
    var maxPositions: Int = 10
    
    var lastDirections: [SIMD3<Float>?] = [nil, nil, nil]
    var currentDirections: [SIMD3<Float>] = [SIMD3<Float>(0,-1,0), SIMD3<Float>(0,-1,0), SIMD3<Float>(0,-1,0)] // start off vertical
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
    @State private var trunkState = TrunkState()
    @State private var appStateManager = AppStateManager()

    // State properties for position and rotation confirmation
    @State private var isPositionConfirmed = false
    @State private var isRotationConfirmed = false

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
            .environment(trunkState)
            .environment(appStateManager)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView(
                isPositionConfirmed: $isPositionConfirmed,
                isRotationConfirmed: $isRotationConfirmed
            )
            .environment(appModel)
            .environment(shapes)
            .environment(trunkState)
            .environment(appStateManager)
            .onAppear {
                appModel.immersiveSpaceState = .open
            }
            .onDisappear {
                appModel.immersiveSpaceState = .closed
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
