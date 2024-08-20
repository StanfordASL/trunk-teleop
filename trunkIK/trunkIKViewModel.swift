//
//  trunkIKViewModel.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/13/24.
//
import RealityKit
import SwiftUI


@Observable class trunkIKViewModel {
    
    private var contentEntity = Entity()
    //
    private var angles = (polar: Float(0), azimuth: Float(0))
    let maxPolarAngle: Float = .pi / 4   // 45 degrees

//    func setupContentEntity() -> Entity? {
//        return contentEntity
//    }
//    
//    func getTargetEntity(name: String) -> Entity? {
//        return contentEntity.children.first { $0.name == name }
//    }
    
    func drag2Rotation(currentHandPosition: SIMD3<Float>, parent: Entity, trunkState: TrunkState, segmentNumber: Int) -> SIMD3<Float> {
        // TODO: raise error when segmentNumber <1 or >3
        
        // optimization in angle space
        // can we do optimization in python?
        // include bounds for small delta angles in optimization (remember to wrap azimuth)
        
        let scalingFactor: Float = 0.1 // Closer to 1 = more responsive
        
    
        let fixedEnd = parent.position(relativeTo: nil)
        let fixedtoHand = (currentHandPosition - fixedEnd) * scalingFactor
        //print("fixedtoHand: \(String(describing: fixedtoHand))")
        
        // Calculate the polar and azimuth angles
        angles.polar = atan2(sqrt(fixedtoHand.x * fixedtoHand.x + fixedtoHand.z * fixedtoHand.z), -fixedtoHand.y)
        angles.azimuth = atan2(-fixedtoHand.z, fixedtoHand.x)
        //print("polar: \(String(describing: angles.polar * 180 / .pi))")
        //print("azimuth: \(String(describing: angles.azimuth * 180 / .pi))")
        
        // Constrain the polar angle within maximum angles
        angles.polar = min(max(angles.polar, -maxPolarAngle), maxPolarAngle)
        
        // Wrap azimuth angle
        if angles.azimuth < 0 {
            angles.azimuth += 2 * .pi
        } else if angles.azimuth > 2 * .pi {
            angles.azimuth -= 2 * .pi
        }
        
        // Update debugData with the correct polar and azimuth angles
//        let debugData.dragTranslation = Vector3D(
//            x: angles.polar * 180 / .pi,
//            y: angles.azimuth * 180 / .pi,
//            z: 0
//        )
        //TODO: update debug data
        
        // Reconstruct the direction vector from the constrained angles
        let constrainedDirection = SIMD3<Float>(
            cos(angles.azimuth) * sin(angles.polar),
            -cos(angles.polar),
            -sin(angles.azimuth) * sin(angles.polar)
        )
        
        // get average of the last few vectors
        let idx = segmentNumber - 1
        

        //let rotationQuat = simd_quatf(from: trunkState.currentDirections[idx], to: constrainedDirection)
        let rotationQuat = simd_quatf(from: SIMD3<Float>(0,-1,0), to: constrainedDirection)
       
        // average recent Quaternions for smoothing
        trunkState.recentQuaternions[segmentNumber - 1].append(rotationQuat)
        
        if trunkState.recentQuaternions[idx].count > trunkState.maxPositions {
            trunkState.recentQuaternions[idx].removeFirst()
        }
        
        let avgQuat = trunkState.recentQuaternions[idx].reduce(simd_quatf(ix: 0,iy: 0,iz: 0,r: 0), +) / Float(trunkState.recentQuaternions[idx].count)
        
        // Apply the quaternion to the parent entity's transform
        parent.transform.rotation = avgQuat //TODO: Generalize

        return constrainedDirection
    }
    
}

