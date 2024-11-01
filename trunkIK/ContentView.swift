//
//  ContentView.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/9/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ToggleGripperButton: View {

    @StateObject var trunkState = DataManager.shared.trunkState
    @State private var gripperButtonLabel: String = "Open Gripper"

    var body: some View {
        Button {
            trunkState.isGripperOpen.toggle()
            gripperButtonLabel = (trunkState.isGripperOpen ? "Close Gripper" : "Open Gripper")
            //print("gripper open?: ")
            //print(trunkState.isGripperOpen)
        } label: {
            Text(gripperButtonLabel)
        }
        .fontWeight(.semibold)
    }
}


struct ToggleStreamingButton: View {

    @StateObject var trunkState = DataManager.shared.trunkState
    @State private var streamingButtonLabel: String = "Start Streaming"
    @State private var backgroundColor: Color = .clear
    @State private var appModel = AppModel()

    var body: some View {
        Button {
            // TODO: add stopsServer else
            trunkState.isStreaming.toggle()
            streamingButtonLabel = (trunkState.isStreaming ? "Stop Streaming" : "Start Streaming")
            backgroundColor = (trunkState.isStreaming ? .green : .clear)
            print(trunkState.isStreaming)
            if trunkState.isStreaming {
                            print("starting stream")
                            appModel.startServer()
                        }
            else {
                // need to actually implement deinit of server - this is where memory issues come from
                print("stopping server")
            }
        } label: {
            Text(streamingButtonLabel)
            // add effect if streaming is on (green button)
        }
        .fontWeight(.semibold)
        .background(backgroundColor)
        .foregroundColor(.white)
        .cornerRadius(20)
    }
}

struct ToggleRecordingButton: View {

    @StateObject var trunkState = DataManager.shared.trunkState
    @State private var recordingButtonLabel: String = "Start Recording"
    @State private var backgroundColor: Color = .clear

    var body: some View {
        Button {
             // you can only use the recording button when streaming is running
            trunkState.isRecording.toggle()
            recordingButtonLabel = (trunkState.isRecording ? "Stop Recording" : "Start Recording")
            backgroundColor = (trunkState.isRecording ? .red : .clear)
            print("recording: ")
            print(trunkState.isRecording)
        } label: {
            Text(recordingButtonLabel)
            // add effect if recording is on (red button)
        }
        .fontWeight(.semibold)
        .background(backgroundColor)
        .foregroundColor(.white)
        .cornerRadius(20)
    }
}

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
                .font(.largeTitle) // Use .title2 or .title3 for smaller titles
                .fontWeight(.bold)
                .padding()
            // Commented out for SRC
            Text("You're on IP address [\(getIPAddress())]")
                .font(.title)
            
            .environment(shapes)
            //will this work
                .onAppear{
                    if runCount == 0 {
                        initialOrientation = shapes.baseEntity.orientation
                        initialPosition = shapes.baseEntity.position
                        }
                }
            
            ToggleImmersiveSpaceButton()
            .padding()
            
            
            // Positioning mode
            if appModel.immersiveSpaceState == .open && !isPositionConfirmed {
                Text("Look at the white ball and pinch your fingers to select")
                    .font(.title)
                Text(" ")
                Text("Drag the white ball to the trunk origin")
                    .font(.title)
                Text(" ")
                Text("Click 'Confirm Position' when set")
                    .font(.title)
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
            
            
            // Rotating mode
            if isPositionConfirmed && !isRotationConfirmed {
                VStack {
                    Text("Pinch and drag the slider to adjust trunk rotation")
                        .font(.title)
                    Text(" ")
                    Text("Point the long axis to the back of the enclosure and the short axis to the left of the enclosure")
                        .font(.title)
                    Text(" ")
                    Text("Click 'Confirm Rotation' when set")
                        .font(.title)
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
                        // ADDED FOR SRC DEMO, just set streaming to always be true
                        //trunkState.isStreaming = true
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
            
            // operation mode
            if isPositionConfirmed && isRotationConfirmed {
                Button("Redo Calibration") { // reset to positioning mode
                    isRotationConfirmed = false
                    isPositionConfirmed = false
                    appStateManager.currentState = .positioning
                    updateHoverEffects(for: shapes, state: appStateManager.currentState)
                    
                    shapes.baseEntity.orientation = initialOrientation
                    shapes.baseEntity.position = trunkState.lastBasePosition ?? [0, 1.5, -1]//[0, 1.5, -1] is og position
                    
                    trunkState.lastBasePosition = nil
                    trunkState.recentBasePositions = []
                    
                    yRotationAngle = 0.0
                    runCount += 1
                    // maybe add more, like setting the position and rotation of the trunk to initial values (saved above), and potentially another button for resetting the angles
                
                }
                // added for src
                Spacer().frame(height: 100)
                Text("Look at the lowest disk and pinch your fingers and drag to control the trunk")
                    .font(.title)
                
                // COMMENTED FOR SRC DEMO, STREAMING ALWAYS OCCURS ONCE ENVIRONMENT IS ENTERED
//                .padding()
//                ToggleStreamingButton()
                // ADDED FOR SRC DEMO, STREAMING ALWAYS OCCURS ONCE ENVIRONMENT IS ENTERED

                Spacer().frame(height: 100) // Adjust the height as needed
                ToggleGripperButton()
                
                // COMMENTED THIS FOR SRC DEMO, RECORDING NOT NECESSARY
//                .padding()
//                ToggleRecordingButton()
                
                //TODO: right now recording button is still available even when streaming is off, although recording is impossible without streaming. Fix this in the future, but @StateObject variables do not update in swiftUI view (I think)
                
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
                                          radius: bounds.boundingRadius) // doubled the bounding radius
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

