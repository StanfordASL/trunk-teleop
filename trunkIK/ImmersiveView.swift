//
//  ImmersiveView.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/9/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

// TODO:

// need:
// 1) implement FK in this app
// 2) have a reset button to go back to beginning state
// 3) readout xyz values of each disk [simd31, simd3_2, simd3_3] in mocap space where the origin is at the trunk base
// 4) implement streaming on mac
// 5) set up AVP streaming ros node on Dell
// 6) implement IK in this app (buy developer account if nobody responds by thursday morning)

// nice to have:
// - add gripper functionality (activate gripper button and distance between hands)
// - think about different ways to orient (ask luis and hugo this afternoon)
// - make sure segment lengths are exactly correct

// Before Marco's Demo:
// - 3D scan for world anchoring of the trunk
// - Full Gripper position streaming functionality (with ros)

struct ImmersiveView: View {
    // for operation
    @State var model = trunkIKViewModel()
    
    // for setup
    @State private var baseEntityOrientation: simd_quatf = simd_quatf()
    @State private var angle = Angle(degrees: 0.0)
    
    @Binding var isPositionConfirmed: Bool
    @Binding var isRotationConfirmed: Bool
    
    @Environment(Shapes.self) var shapes: Shapes
    @Environment(TrunkState.self) var trunkState: TrunkState
    @Environment(AppStateManager.self) var appStateManager: AppStateManager
    
    let maxPositions = 10 // Define the number of positions to average - 3 is still shaky, 10 is too delayed
    
    
    var body: some View {
        GeometryReader { geometry in
            RealityView { content in
                if let entity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                    content.add(entity)
                    
                    setupIK(entity: entity, shapes: shapes)
                                        
                    if isPositionConfirmed && isRotationConfirmed{ // make axes disappear after calibration
                        shapes.x_axis = entity.findEntity(named: "X_Axis") ?? Entity()
                        shapes.z_axis = entity.findEntity(named: "Z_Axis") ?? Entity()
                        
                        makeTransparent(entity: shapes.x_axis)
                        makeTransparent(entity: shapes.x_axis)
                    }
                    
                }
            }
            // Set position gesture
            // need to target the gesture to a child of baseEntity that is the same as baseEntity,
            // this is to avoid the hierarchy-blocking of gestures
            .gesture(
                DragGesture()
                    .targetedToEntity(shapes.positionSetEntity)
                    .onChanged { value in
                        if !isPositionConfirmed {
                            Task {
                                do {
                                    if trunkState.lastBasePosition == nil { //upon first gesture
                                        trunkState.currentBaseHandPosition = value.convert(value.location3D, from: .local, to: shapes.positionSetEntity)
                                    } else { //upon 2nd + gestures
                                        trunkState.currentBaseHandPosition = value.convert(value.location3D, from: .local, to: shapes.positionSetEntity) + trunkState.lastBasePosition!
                                    }
                                    
                                    trunkState.recentBasePositions.append(trunkState.currentBaseHandPosition!)
                                    if trunkState.recentBasePositions.count > maxPositions {
                                        trunkState.recentBasePositions.removeFirst()
                                    }
                                    let averagePosition = trunkState.recentBasePositions.reduce(SIMD3<Float>(0, 0, 0), +) / Float(trunkState.recentBasePositions.count)
                                    
                                    // Update baseEntity position
                                    shapes.baseEntity.position = averagePosition
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        trunkState.lastBasePosition = trunkState.currentBaseHandPosition // had ! here but dont anymore...'
                        // try to reproduce error where app exits and upon restart get fault here: Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value
                        // aslo happens after "hideimmersive space"
                        // small axis disappears
                    }
            )
            
            // TODO: current problem is it kind of "snaps" back to a zero polar angle upon a new gesture beginning
            // - fix with logic similar to position setup
            // Operate Segment 1 gesture (FK)
            .gesture(
                DragGesture()
                    .targetedToEntity(shapes.disk1)
                    .onChanged { value in
                        let parentEntity = shapes.parent1
                        let idx = 0
                        
                        // Convert the gesture location to the RealityKit coordinate space from SwiftUI
                        let currentHandPosition = value.convert(value.location3D, from: .local, to: parentEntity) + parentEntity.position(relativeTo:nil) // to world frame
                        
                        trunkState.lastDirections[idx] = model.drag2Rotation(currentHandPosition: currentHandPosition, parent: parentEntity, trunkState: trunkState, segmentNumber: 1)
                        
                    }
                    .onEnded { _ in
                        let idx = 0
                        print("ended")
                        trunkState.currentDirections[idx] = trunkState.lastDirections[idx]!
                        print(trunkState.currentDirections[idx])
                        // TODO: this still doesnt work since im not using simd_quatf right
                        // restrict jumps in another way, like having a maximum delta polar and delta azimuth per frame...
                    }
            )
            
            // Operate Segment 2 gesture (FK)
            .gesture(
                DragGesture()
                    .targetedToEntity(shapes.disk2)
                    .onChanged { value in
                        let parentEntity = shapes.parent2
                        
                        // Convert the gesture location to the RealityKit coordinate space from SwiftUI
                        let currentHandPosition = value.convert(value.location3D, from: .local, to: parentEntity) + parentEntity.position(relativeTo:nil) // to world frame
                        
                        // convert user drag to rotation of a segment
                        model.drag2Rotation(currentHandPosition: currentHandPosition, parent: parentEntity, trunkState: trunkState, segmentNumber: 2)

                    }
                    .onEnded { _ in
                        
                    }
            )
            
            // Operate Segment 3 gesture (FK)
            .gesture(
                DragGesture()
                    .targetedToEntity(shapes.disk3)
                    .onChanged { value in
                        let parentEntity = shapes.parent3
                        
                        // Convert the gesture location to the RealityKit coordinate space from SwiftUI
                        let currentHandPosition = value.convert(value.location3D, from: .local, to: parentEntity) + parentEntity.position(relativeTo:nil) // to world frame
                        
                        // convert user drag to rotation of a segment
                        model.drag2Rotation(currentHandPosition: currentHandPosition, parent: parentEntity, trunkState: trunkState, segmentNumber: 3)

                    }
                    .onEnded { _ in
                        
                    }
            )

            //        //IK Gesture
            //        .gesture(
            //            DragGesture()
            //                .targetedToEntity(shapes.disk3)
            //                .onChanged { value in
            //                    if isRotationConfirmed { // Only allow this if position and rotation are confirmed
            //                        Task {
            //                            do {
            //                                let entity = try await Entity(named: "Immersive", in: realityKitContentBundle)
            //                                let currentHandPosition = value.convert(value.location3D, from: .local, to: entity)
            //
            //                                if initialHandPosition == nil {
            //                                    initialHandPosition = currentHandPosition
            //                                }
            //
            //                                var ikComponent = entity.components[IKComponent.self]!
            //                                ikComponent.solvers[0].constraints["Joint3Constraint"]!.target.translation = currentHandPosition
            //                                ikComponent.solvers[0].constraints["Joint3Constraint"]!.animationOverrideWeight.position = 1.0
            //                                entity.components.set(ikComponent)
            //                            }
            //                        }
            //                    }
            //                }
            //                .onEnded { _ in
            //                    initialHandPosition = nil
            //                }
            //        )
        }
    }
}

// make axes totally transparent
// this doesn't work yet but its minor
func makeTransparent(entity: Entity){
    let opacityComponent = OpacityComponent(opacity: 0.0)
    
    entity.components.set(opacityComponent)
}

// set up the joints, skeleton, and IKrig/resource
func setupIK(entity: Entity, shapes: Shapes) {
    shapes.baseEntity = entity.findEntity(named: "Base") ?? Entity()
    shapes.positionSetEntity = entity.findEntity(named: "PositionSetEntity") ?? Entity()
    
    shapes.parent1 = entity.findEntity(named: "Parent1") ?? Entity()
    shapes.segment1 = entity.findEntity(named: "Segment1") ?? Entity()
    shapes.disk1 = entity.findEntity(named: "Disk1") ?? Entity()
    
    shapes.parent2 = entity.findEntity(named: "Parent2") ?? Entity()
    shapes.segment2 = entity.findEntity(named: "Segment2") ?? Entity()
    shapes.disk2 = entity.findEntity(named: "Disk2") ?? Entity()
    
    shapes.parent3 = entity.findEntity(named: "Parent3") ?? Entity()
    shapes.segment3 = entity.findEntity(named: "Segment3") ?? Entity()
    shapes.disk3 = entity.findEntity(named: "Disk3") ?? Entity()
    
    
    // shapes.baseEntity is correctly being read in in this function
    //print("shapes.baseEntity: \(shapes.baseEntity)")
    
    // setup collisioncomponent for baseEntity
    let bounds = shapes.positionSetEntity.visualBounds(recursive: false,
                                            relativeTo: nil,
                                       excludeInactive: false)
            
    let shape: ShapeResource = ShapeResource.generateCapsule(
                                       height: bounds.extents.y,
                                       radius: bounds.boundingRadius / 2)
                                .offsetBy(translation: [0, 0, 0])
                                   
    let collision = CollisionComponent(shapes: [shape],
                                         mode: .default,
                                       filter: .sensor)
    shapes.positionSetEntity.components.set(collision)
    
    // create hovercomponents
    let hoverComponent = HoverEffectComponent(.highlight(
        HoverEffectComponent.HighlightHoverEffectStyle(
            color: .green, strength: 2.0)
    ))
    
    shapes.positionSetEntity.components.set(hoverComponent)

    
    // check for meshresource - baseEntity has one but entity doesnt?
    guard let meshResource = shapes.baseEntity.components[ModelComponent.self]?.mesh else {
        fatalError("No mesh found")
    }
    
    //access skeleton collection
    // meshresource.contents.skeletoncollection isEmpty initially, we need to populate it
    var skeletonCollection = meshResource.contents.skeletons
    
    // Create the joints
    let joint1 = MeshResource.Skeleton.Joint(name: "Joint1",
                                             parentIndex: nil,
                                             inverseBindPoseMatrix: matrix_identity_float4x4,
                                             restPoseTransform: shapes.baseEntity.transform)
    let joint2 = MeshResource.Skeleton.Joint(name: "Joint2",
                                             parentIndex: 0,
                                             inverseBindPoseMatrix: matrix_identity_float4x4,
                                             restPoseTransform: shapes.disk1.transform)
    let joint3 = MeshResource.Skeleton.Joint(name: "Joint3",
                                             parentIndex: 1,
                                             inverseBindPoseMatrix: matrix_identity_float4x4,
                                             restPoseTransform: shapes.disk2.transform)
    
    // create the skeleton
    let skeleton = MeshResource.Skeleton(id: "PendulumSkeleton",
                                         joints: [joint1, joint2, joint3])
    
    
    
    // dont understand how to associate a new meshresource.contents.skeletons with an existing meshresource
    //meshResource.contents.skeletons.insert(skeleton) // doesnt work, contents is read only
    //skeletonCollection.insert(skeleton) // does work, but we need to write the skeletoncollection back to meshresource
    let modelSkeleton = skeleton // delete tis in final implementation
    
    
    // Create the IKRig
    if var ikRig = try? IKRig(for: modelSkeleton) {
        // Set up constraints
        ikRig.constraints = [
            .parent(named: "Joint1Constraint",
                    on: "Joint1",
                    positionWeight: SIMD3(repeating: 90.0),
                    orientationWeight: SIMD3(repeating: 90.0)),
            .parent(named: "Joint2Constraint",
                    on: "Joint2",
                    positionWeight: SIMD3(repeating: 90.0),
                    orientationWeight: SIMD3(repeating: 90.0)),
            .parent(named: "Joint3Constraint",
                    on: "Disk3",
                    positionWeight: SIMD3(repeating: 90.0),
                    orientationWeight: SIMD3(repeating: 90.0))
        ]
        ikRig.maxIterations = 30
        
        // Create and set the IKComponent
        if let ikResource = try? IKResource(rig: ikRig) {
            let ikComponent = IKComponent(resource: ikResource)
            print("initial IKComponent: \(String(describing: ikComponent))")
            entity.components.set(ikComponent)
            
        
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView(isPositionConfirmed: .constant(false),
                  isRotationConfirmed: .constant(false))
        .environment(AppModel())
}



