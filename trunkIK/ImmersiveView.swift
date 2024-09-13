//
//  ImmersiveView.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/9/24.
//

import SwiftUI
import RealityKit
import RealityKitContent


/// Stores the name of an IK constraint and its target position, along with an optional helper entity for visualizing the target position.
struct IKTargetPositionerComponent: Component {
    let targetConstraintName: String
    var targetPosition: SIMD3<Float>
    let targetVisualizerEntity: Entity?
}

/// Updates the target position of an IK constraint every frame.
struct IKTargetPositionerSystem: System {
    let query: EntityQuery = EntityQuery(where: .has(IKTargetPositionerComponent.self))
    
    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        // Get all entities with an `IKTargetPositionerComponent`.
        let entities = context.entities(matching: self.query, updatingSystemWhen: .rendering)
        
        for entity in entities {
            // Get the necessary IK components attached to the entity.
            guard let ikComponent = entity.components[IKComponent.self],
                  let ikTargetPositionerComponent = entity.components[IKTargetPositionerComponent.self] else {
                assertionFailure("Entity is missing required IK components.")
                return
            }
            
            // Set the target position of the target constraint.
            ikComponent.solvers[0].constraints[ikTargetPositionerComponent.targetConstraintName]!.target.translation = ikTargetPositionerComponent.targetPosition
            
//            print("targetPosition: ")
//            print(ikTargetPositionerComponent.targetPosition)
            
            // Fully override the rest pose, allowing IK to fully move the joint to the target position.
            ikComponent.solvers[0].constraints[ikTargetPositionerComponent.targetConstraintName]!.animationOverrideWeight.position = 1.0
            
            // Position the target visualizer entity at the target position.
            ikTargetPositionerComponent.targetVisualizerEntity?.position = ikTargetPositionerComponent.targetPosition
            
            //print("updating target constraint position")

            // Apply component changes.
            entity.components.set(ikComponent)
        }
    }
}


struct ImmersiveView: View {
    // for operation
    @State var model = trunkIKViewModel()
    
    // for setup
    @State private var baseEntityOrientation: simd_quatf = simd_quatf()
    @State private var angle = Angle(degrees: 0.0)
    
    @Binding var isPositionConfirmed: Bool
    @Binding var isRotationConfirmed: Bool
    
    @Environment(Shapes.self) var shapes: Shapes
//    @Environment(TrunkState.self) var trunkState: TrunkState
    @StateObject var trunkState = DataManager.shared.trunkState
    @Environment(AppStateManager.self) var appStateManager: AppStateManager
    
    @State var skeletonContainerEntity: ModelEntity = ModelEntity()
    
    // Access shared queue via DataManager
    let diskPositionsQueue = DataManager.shared.diskPositionsQueue
    
    let maxPositions = 10 // Define the number of positions to average - 3 is still shaky, 10 is too delayed
    
    
    var body: some View {
        GeometryReader { geometry in
            RealityView { content in
                shapes.baseEntity.position = [0, 1.5, -1]
                shapes.baseEntity.name = "base"
                
                shapes.rootJoint.name = "root"
                shapes.rootJoint.setParent(shapes.baseEntity)
                
                // Y offsets for 200g from mocap data:
                //-0.10665, -0.20432, -0.320682
                
                
                shapes.disk1.setParent(shapes.rootJoint)
                shapes.disk1.name = "disk1"
                shapes.disk1.position = [0, -0.10665, 0]
                
                shapes.disk2.setParent(shapes.disk1)
                shapes.disk2.name = "disk2"
                shapes.disk2.position = [0, -0.09767, 0]
                
                shapes.disk3.setParent(shapes.disk2)
                shapes.disk3.name = "disk3"
                shapes.disk3.position = [0, -0.116362, 0]
                
                
                shapes.positionSetEntity.setParent(shapes.baseEntity)
                shapes.positionSetEntity.name = "positionSetEntity"
                shapes.x_axis.setParent(shapes.baseEntity)
                shapes.x_axis.transform.rotation = simd_quatf(from: SIMD3<Float>(0,1,0), to: SIMD3<Float>(1,0,0))
                shapes.x_axis.transform.translation = SIMD3<Float>(-0.15/2,0,0)
                shapes.x_axis.name = "x_axis"
                
                shapes.z_axis.setParent(shapes.baseEntity)
                shapes.z_axis.transform.rotation = simd_quatf(from: SIMD3<Float>(0,1,0), to: SIMD3<Float>(0,0,1))
                shapes.z_axis.transform.translation = SIMD3<Float>(0,0,-0.45/2)
                shapes.z_axis.name = "z_axis"
                
                // Initialize disk positions
                diskPositionsQueue.async {
                    trunkState.diskPositions["disk1"] = toOptiTrackCoords(coords: shapes.disk1.position(relativeTo: shapes.baseEntity))
                    trunkState.diskPositions["disk2"] = toOptiTrackCoords(coords: shapes.disk2.position(relativeTo: shapes.baseEntity))
                    trunkState.diskPositions["disk3"] = toOptiTrackCoords(coords: shapes.disk3.position(relativeTo: shapes.baseEntity))
                }
//                print(trunkState.diskPositions)
                             
                content.add(shapes.baseEntity)
                
                // problem: rootJoint and its children are linked to IK component, so they do not update with baseEntity's position and rotation changes
                // potential solutions:
                // - do IK setup after the baseentity and all child components have been placed
                // - do IK on baseEntity to initially place it in the scene (idk how this would work with rotation, but it would probably be a lot of work)
                
                
                //----------------------Calibration setup------------------------------//
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
                
                shapes.positionSetEntity.components.set([InputTargetComponent(), hoverComponent])
                //---------------------------------------------------------------//
                
                
                // Create the skeleton entity
                // Define a unique skeleton id.
                let skeletonId = "customSkeleton"
                
                // Convert the root entity hierarchy into an array of "joint" entities.
                let jointEntities = getEntityHierarchyAsArray(rootEntity: shapes.rootJoint)
                print("length")
                print((jointEntities.count))
                
                // Create a custom skeleton from the entity array.
                guard let customSkeleton = try? createSkeletonFromEntityArray(skeletonId: skeletonId, jointEntities: jointEntities) else {
                    assertionFailure("Failed to create custom skeleton.")
                    return
                }
                print("customSkeleton created successfully")
                
                // create mesh and add skeleton to mesh
                // In order for an entity to use IK it needs a mesh with a skeleton,
                // so create a dummy mesh part referencing the skeleton.
                var newPart = MeshResource.Part(id: "dummyPart", materialIndex: 0)
                newPart.skeletonID = skeletonId
                // Make the mesh part consist of a single invisible triangle.
                newPart.positions = .init([[0,0,0], [0,0,0], [0,0,0]])
                newPart.triangleIndices = .init([0, 1, 2])
                newPart.jointInfluences = .init(influences: .init([.init(), .init(), .init()]), influencesPerVertex: 1)
                // Add the invisible mesh part and skeleton to the mesh contents.
                var meshContent = MeshResource.Contents()
                meshContent.models = [.init(id: "dummyModel", parts: [newPart])]
                meshContent.skeletons = [customSkeleton]
                
                // Create a model entity to contain the skeleton mesh.
                guard let meshResource = try? MeshResource.generate(from: meshContent) else {
                    assertionFailure("Failed to create skeleton mesh resource.")
                    return
                }
                skeletonContainerEntity = ModelEntity(mesh: meshResource, materials: [])
                //let skeletonRootEntity = Entity()
                
                // Add the skeleton model entity and the root joint entity to the scene.
//                skeletonContainerEntity.setParent(skeletonRootEntity)
//                jointEntities.first?.setParent(skeletonRootEntity)  // `jointEntities.first` is the root joint entity.
//                content.add(skeletonRootEntity)
                skeletonContainerEntity.setParent(shapes.baseEntity)
                jointEntities.first?.setParent(shapes.baseEntity)
                
                
                // Create IK Component and assign to skeleton entity
                // Create an IK rig for the skeleton.
                guard var customIKRig = try? IKRig(for: customSkeleton) else {
                    assertionFailure("Failed to create IK rig from custom skeleton.")
                    return
                }
                
                // Set the global forward kinematics weight to zero so that the arm is entirely moved by inverse kinematics.
                customIKRig.globalFkWeight = 0.0
                
                // Define the joint constraints for the rig.
                // Get the index of the hand joint.
                // May be different for your custom skeleton.
                let disk3JointIndex = customSkeleton.joints.count - 1
                let disk2JointIndex = customSkeleton.joints.count - 2
                let disk1JointIndex = customSkeleton.joints.count - 3
                
                
                // Define the joint constraints for the rig.
                let rootConstraintName = "root_constraint"
                let disk3ConstraintName = "disk3_constraint"
                let disk2ConstraintName = "disk2_constraint"
                let disk1ConstraintName = "disk1_constraint"
                customIKRig.constraints = [
                    // Constrain the root joint's position.
                    .parent(named: rootConstraintName, on: customSkeleton.joints.first!.name, positionWeight: [100.0, 100.0, 100.0], orientationWeight: SIMD3(repeating: 100.0)), //basically fixed
                    // Add a point demand to the hand joint.
                    // This will be used to set a target position for the hand.
                    // parent constraints make everything very wobbly - error message: bad solver tuning detected
                        .point(named: disk3ConstraintName, on: customSkeleton.joints[disk3JointIndex].name, positionWeight: SIMD3(repeating:1.0)),
                    
                        .point(named: disk2ConstraintName, on: customSkeleton.joints[disk2JointIndex].name, positionWeight: SIMD3(repeating:1.0)),
                    
                        .point(named: disk1ConstraintName, on: customSkeleton.joints[disk1JointIndex].name, positionWeight: SIMD3(repeating:1.0)),
                ]
                
                
                // Add an input target and collision shape to the hand joint entity
                // so that it can be the target of a drag gesture.
                shapes.disk3.components.set(InputTargetComponent())
                shapes.disk3.generateCollisionShapes(recursive: false)
                
                
                
                // Create an IK resource for the custom IK rig.
                guard let ikResource = try? IKResource(rig: customIKRig) else {
                    assertionFailure("Failed to create IK resource.")
                    return
                }
                
                
                // Add an IK component to the entity using the new resource.
                skeletonContainerEntity.components.set(IKComponent(resource: ikResource))
                print("created IKComponent")
                
                
                // Create a helper entity to visualize the target position.
                let targetVisualizerEntity = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [SimpleMaterial(color: .magenta, isMetallic: false)])
                targetVisualizerEntity.components.set(OpacityComponent(opacity: 0.5))
                targetVisualizerEntity.setParent(skeletonContainerEntity)
                // Create the IK target positioner component and add it to the skeleton container entity.
                skeletonContainerEntity.components.set(IKTargetPositionerComponent(targetConstraintName: disk3ConstraintName,
                                                                                   targetPosition: shapes.disk3.position(relativeTo: skeletonContainerEntity),
                                                                                   targetVisualizerEntity: targetVisualizerEntity))
                
                // TODO: just adding another component doesnt work, maybe add this as a list of constraint names, positions, and entities and it will work
                
                // Position joint entities to match their corresponding skeleton joint transforms upon trigger
                // Subscribe to the skeletal pose update complete event and update the joint entities whenever it is triggered.
                content.subscribe(to: AnimationEvents.SkeletalPoseUpdateComplete.self) { event in
                    //print("SkeletalPoseUpdateComplete event triggered")
                    for i in 0..<skeletonContainerEntity.jointTransforms.count {
                        jointEntities[i].transform.rotation = skeletonContainerEntity.jointTransforms[i].rotation
                        jointEntities[i].transform.translation = skeletonContainerEntity.jointTransforms[i].translation
                        //print("Updated joint entity \(i) transforms")
                        //}
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
                                        trunkState.currentBaseHandPosition = value.convert(value.location3D, from: .local, to: shapes.positionSetEntity) + [0, 1.5, -1]
                                        //print("new baseposition")
                                    } else { //upon 2nd + gestures
                                        trunkState.currentBaseHandPosition = value.convert(value.location3D, from: .local, to: shapes.positionSetEntity) + trunkState.lastBasePosition!
                                        //print("existing baseposition")
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

            
            //operate segment 3 gesture (IK)
            .gesture(
                DragGesture()
                    .targetedToEntity(shapes.disk3)
                    .onChanged { value in
                        if isPositionConfirmed && isRotationConfirmed{
                            let currentHandPosition = value.convert(value.location3D, from: .local, to: skeletonContainerEntity)
                            //print("DragGesture detected, currentHandPosition: \(currentHandPosition)")
                            
                            
                            skeletonContainerEntity.components[IKTargetPositionerComponent.self]?.targetPosition = currentHandPosition
                            //print("Updated target position in IKTargetPositionerComponent")
                            
                            diskPositionsQueue.async {
                                // update disk positions
                                trunkState.diskPositions["disk1"] = toOptiTrackCoords(coords: shapes.disk1.position(relativeTo: shapes.baseEntity))
                                trunkState.diskPositions["disk2"] = toOptiTrackCoords(coords: shapes.disk2.position(relativeTo: shapes.baseEntity))
                                trunkState.diskPositions["disk3"] = toOptiTrackCoords(coords: shapes.disk3.position(relativeTo: shapes.baseEntity))
                                //                            print("gesture disk positions: ")
                                //                            print(trunkState.diskPositions)
                            }
                        }
                    }
            )
            
            
        }
    }
}

func toOptiTrackCoords(coords: SIMD3<Float>) -> SIMD3<Float> {
    return coords * [-1, 1, -1] // flip x and z axes, y stays the same
}

/// Takes a root entity and traverses through its hierarchy breadth first to create a flat array of all the entities in the hierarchy.
func getEntityHierarchyAsArray(rootEntity: Entity) -> [Entity] {
    // Prepare the entity array.
    var entities: [Entity] = []
    
    // Create the queue which will be used to traverse the entity hierarchy breadth first.
    var queue = [rootEntity]
    
    // There are more entities to traverse as long as the queue isn't empty.
    while !queue.isEmpty {
        // Get the first entity in the queue.
        let entity = queue.removeFirst()
        // Add it to the entities array.
        if entity.name.starts(with: "disk") || entity.name.starts(with: "root"){
            entities.append(entity)
            print(entity.name)
        }
        
        // Enqueue all of the entity's children.
        for child in entity.children {
            queue.append(child)
        }
    }
    
    // Return the array of entities. The root entity will be the first entity in the array.
    return entities
}

/// Creates a skeleton from an array of joint entities created with `getEntityHierarchyAsArray`.
func createSkeletonFromEntityArray(skeletonId: String, jointEntities: [Entity]) -> MeshResource.Skeleton? {
    // Prepare the arrays needed to create the skeleton.
    var jointNames: [String] = []
    var restPoseTransforms: [Transform] = []
    var parentIndices: [Int?] = []
    
    // Iterate through each of the entities.
    for jointEntity in jointEntities {
        // Set a unique joint name.
        jointNames.append(jointEntity.name + UUID().uuidString)
        // Record the entity's transform.
        restPoseTransforms.append(jointEntity.transform)
        // Find the entity's parent index, if it has one.
        let jointParent = jointEntity.parent
        parentIndices.append(jointParent == nil ? nil : jointEntities.lastIndex(of: jointParent!))
    }
    
    // Create a skeleton from the joint names, transforms and parent indices.
    return MeshResource.Skeleton(id: skeletonId,
                                 jointNames: jointNames,
                                 inverseBindPoseMatrices: .init(repeating: matrix_identity_float4x4, count: jointNames.count),
                                 restPoseTransforms: restPoseTransforms,
                                 parentIndices: parentIndices)
}


#Preview(immersionStyle: .full) {
    ImmersiveView(isPositionConfirmed: .constant(false),
                  isRotationConfirmed: .constant(false))
    .environment(AppModel())
}



