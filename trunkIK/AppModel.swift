//
//  AppModel.swift
//  trunkIK
//
//  Created by ASLTrunk on 8/9/24.
//

//import SwiftUI
//
///// Maintains app-wide state
//@MainActor
//@Observable
//class AppModel {
//    let immersiveSpaceID = "ImmersiveSpace"
//    enum ImmersiveSpaceState {
//        case closed
//        case inTransition
//        case open
//    }
//    var immersiveSpaceState = ImmersiveSpaceState.closed
//}

import SwiftUI
import RealityKit
import ARKit
import GRPC
import NIO

@MainActor
@Observable
class AppModel {
    
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    let trunkState = DataManager.shared.trunkState
    
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    private var server: Server?


    func startServer() {
        Task {
            await self.setupServer()
        }
    }
    

    private func setupServer() async {
        let provider = DiskTrackingServiceProvider(trunkState: trunkState)
        server = try! await GRPC.Server.insecure(group: group)
            .withServiceProviders([provider])
            .bind(host: "0.0.0.0", port: 12345)
            .get()

        print("Server is listening on port \(server?.channel.localAddress?.port ?? 0)")

        do {
            try await server?.onClose.get()
        } catch {
            print("Server error: \(error)")
        }
    }

    deinit {
        Task { [weak self] in
            try? await self?.server?.close().get()
            try? await self?.group.shutdownGracefully()
        }
    }
}



class DataManager {
    static let shared = DataManager()
    
    var trunkState = TrunkState()
    
    // Shared queue for diskPositions
    let diskPositionsQueue = DispatchQueue(label: "aslTrunk.trunkIK.diskPositionsQueue")
        
    
    private init() {}
}

class DiskTrackingServiceProvider: Disktracking_DiskTrackingServiceProvider {
    var interceptors: Disktracking_DiskTrackingServiceServerInterceptorFactoryProtocol?
    var trunkState: TrunkState

    let diskPositionsQueue = DataManager.shared.diskPositionsQueue // Use shared queue

    init(trunkState: TrunkState) {
        self.trunkState = trunkState
    }

    nonisolated func streamDiskPositions(
        request: Disktracking_DiskPosition,
        context: StreamingResponseCallContext<Disktracking_DiskPositions>
    ) -> EventLoopFuture<GRPCStatus> {
        let eventLoop = context.eventLoop
        // delay was 100ms = 10Hz, changed to 10ms = 100Hz
        let task = eventLoop.scheduleRepeatedAsyncTask(initialDelay: .milliseconds(10), delay: .milliseconds(10)) { task -> EventLoopFuture<Void> in
            let diskPositions = self.fillDiskPositions()
            //print("Sending disk positions...")
            return context.sendResponse(diskPositions).map { _ in }
        }

        context.statusPromise.futureResult.whenComplete { _ in task.cancel() }
        return eventLoop.makePromise(of: GRPCStatus.self).futureResult
    }

    private func fillDiskPositions() -> Disktracking_DiskPositions {
        var diskPositions = Disktracking_DiskPositions()

        diskPositionsQueue.sync {
            for (id, position) in trunkState.diskPositions {
                //print("Current \(id) Position: \(position)")
                let diskPosition = Disktracking_DiskPosition.with {
                    $0.id = id
                    $0.position = [position.x, position.y, position.z]
                    
                }
                diskPositions.diskPositions[id] = diskPosition
            }
            
            
            
            diskPositions.isRecording = trunkState.isRecording
            diskPositions.isGripperOpen = trunkState.isGripperOpen
            
        }
        //print("sending gripper open state?:")
        //  print(trunkState.isGripperOpen)

        return diskPositions
    }
}
