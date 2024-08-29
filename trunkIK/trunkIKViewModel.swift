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
    
}

