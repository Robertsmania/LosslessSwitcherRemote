//
//  LosslessSwitcherRemoteApp.swift
//  LosslessSwitcherRemote
//
//  Created by Kris Roberts on 4/6/23.
//

import SwiftUI

@main
struct LosslessSwitcherRemoteApp: App {
    @StateObject var losslessSwitcherProxy = LosslessSwitcherProxy.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(losslessSwitcherProxy)
        }
    }
}
