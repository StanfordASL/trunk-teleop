//
//  ContentView.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/9/24.
//

import SwiftUI
import RealityKit
import RealityKitContent


struct ContentView: View {
    @Environment(AppStateManager.self) var appStateManager: AppStateManager
    @Environment(Shapes.self) var shapes: Shapes
    @Environment(AppModel.self) var appModel: AppModel
    
    @StateObject var trunkState = DataManager.shared.trunkState
    
    @Binding var isPositionConfirmed: Bool
    @Binding var isRotationConfirmed: Bool
    @State private var yRotationAngle: Double = 0.0  // Slider value for Y-axis rotation
    
    @State private var initialOrientation: simd_quatf = simd_quatf()
    @State private var initialPosition: SIMD3<Float> = SIMD3<Float>(0,0,0)
    @State private var runCount: Int = 0

    var body: some View {
        VStack {
            Text("Welcome to ASL TrunkTeleop!")
                .font(.title) // Use .title2 or .title3 for smaller titles
                .fontWeight(.bold)
                .padding()
            Text("You're on IP address [\(getIPAddress())]")
                .font(.title2)
            
            .environment(shapes)
            //will this work
                .onAppear{
                    if runCount == 0 {
                        // try accessing this as a struct: Type '()' cannot conform to 'View', Only concrete types such as structs, enums and classes can conform to protocols,Required by static method 'buildExpression' where 'Content' = '()'
                        initialOrientation = shapes.baseEntity.orientation
                        initialPosition = shapes.baseEntity.position
                        }
                }
            
            
            // Positioning mode
            if appModel.immersiveSpaceState == .open && !isPositionConfirmed {
                Text("Look at the white ball and pinch your fingers to select")
                Text(" ")
                Text("Drag the white ball to the trunk origin")
                Text(" ")
                Text("Click 'Confirm Position' when set")
                Text(" ")
                
                Button("Confirm Position") {
                    isPositionConfirmed = true
                    appStateManager.currentState = .rotating
                    updateHoverEffects(for: shapes, state: appStateManager.currentState)
                    print("current state: rotation")
                }
                .padding()
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            ToggleImmersiveSpaceButton()
            
            // Rotating mode
            if isPositionConfirmed && !isRotationConfirmed {
                VStack {
                    Text("Pinch and drag the slider to adjust trunk rotation")
                    Text(" ")
                    Text("The long axis should point to the back of the enclosure and the short axis should point to the left of the enclosure")
                    Text(" ")
                    Text("Click 'Confirm Rotation' when set")
                    Text(" ")
                    Slider(value: $yRotationAngle, in: 0...360, step: 1) {
                        Text("Rotation Angle")
                    }
                    .padding()
                    Text(" ")
                    Button("Confirm Rotation") {
                        isRotationConfirmed = true
                        appStateManager.currentState = .interaction
                        updateHoverEffects(for: shapes, state: appStateManager.currentState)
                        print("current state: interaction")
                        
                    }
                    .padding()
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .onChange(of: yRotationAngle, initial: false) { newValue,yRotationAngle  in
                    // Update baseEntity's orientation based on slider value
                    let rotation = simd_quatf(angle: Float(newValue) * .pi / 180, axis: SIMD3(0, 1, 0))
                    shapes.baseEntity.orientation = rotation
                }
            }
            
            // Reset to positioning mode
            if isPositionConfirmed && isRotationConfirmed {
                Button("Redo Calibration") {
                    isRotationConfirmed = false
                    isPositionConfirmed = false
                    appStateManager.currentState = .positioning
                    updateHoverEffects(for: shapes, state: appStateManager.currentState)
                    
                    shapes.baseEntity.orientation = initialOrientation
                    shapes.baseEntity.position = initialPosition
                    
                    trunkState.lastBasePosition = nil
                    trunkState.recentBasePositions = []
                    
                    yRotationAngle = 0.0
                    runCount += 1
                    // maybe add more, like setting the position and rotation of the turnk to initial values (saved above), and potentially another button for resetting the angles
                    
                }
                .padding()
            }
        }
        .padding()
    }
}

func updateHoverEffects(for shapes: Shapes, state: AppState) {
   switch state {
   case .positioning:
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
       
       // Allow hover on baseEntity only
       if !shapes.positionSetEntity.components.has(HoverEffectComponent.self) {
           let hoverComponent = HoverEffectComponent(.highlight(
               HoverEffectComponent.HighlightHoverEffectStyle(
                   color: .green, strength: 2.0)
           ))
           shapes.positionSetEntity.components.set(hoverComponent)
       }
       // Remove hover effect from other entities
       shapes.disk1.components.remove(HoverEffectComponent.self)
       shapes.disk2.components.remove(HoverEffectComponent.self)
       shapes.disk3.components.remove(HoverEffectComponent.self)
       
   case .rotating:
       // Disable hover on baseEntity
       shapes.positionSetEntity.components.remove(HoverEffectComponent.self)
       // Disable hover on disk entities
       shapes.disk1.components.remove(HoverEffectComponent.self)
       shapes.disk2.components.remove(HoverEffectComponent.self)
       shapes.disk3.components.remove(HoverEffectComponent.self)
       
   case .interaction:
       // Enable hover on disk entities only
       if !shapes.disk1.components.has(HoverEffectComponent.self) {
           let hoverComponent = HoverEffectComponent(.highlight(
               HoverEffectComponent.HighlightHoverEffectStyle(
                   color: .green, strength: 2.0)
           ))
           print("Adding hovereffects to disks")
           shapes.disk1.components.set(hoverComponent)
           shapes.disk2.components.set(hoverComponent)
           shapes.disk3.components.set(hoverComponent)
       }
       // Remove hover from baseEntity
       shapes.positionSetEntity.components.remove(HoverEffectComponent.self)
   }
}

func getIPAddress() -> String {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { return "" }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // wifi = ["en0"]
                // wired = ["en2", "en3", "en4"]
                // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                let name: String = String(cString: (interface.ifa_name))
                if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return address ?? ""
}

                                       
#Preview(windowStyle: .automatic) {
    ContentView(
        isPositionConfirmed: .constant(false),
        isRotationConfirmed: .constant(false)
    )
    .environment(AppModel())
    .environment(Shapes())
}

