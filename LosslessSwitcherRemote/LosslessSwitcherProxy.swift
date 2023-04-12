//
//  LosslessSwitcherProxy.swift
//  LosslessSwitcherRemote
//
//  Created by Kris Roberts on 4/8/23.
//

import SwiftUI
import Network

class LosslessSwitcherProxy: ObservableObject {
    static let shared = LosslessSwitcherProxy()
    @Published var currentSampleRate: Float64 = 0
    @Published var detectedSampleRate: Float64 = 0
    @Published var autoSwitchingEnabled: Bool = false
    @Published var supportedSampleRates: [Float64] = []
    @Published var discoveredServices: [NWBrowser.Result] = []
    @Published var connection: NWConnection?
    @Published var defaultOutputDeviceName: String = ""
    @Published var serverHostName: String = ""
    private let networkClient = NetworkClient()
    private var willEnterForegroundObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?

    init() {
        networkClient.$discoveredServices
            .assign(to: &$discoveredServices)
        
        networkClient.$connection
            .assign(to: &$connection)
        
        networkClient.onReceiveServerResponse = { [weak self] serverResponse in
            self?.currentSampleRate = serverResponse.currentSampleRate
            self?.detectedSampleRate = serverResponse.detectedSampleRate
            self?.autoSwitchingEnabled = serverResponse.autoSwitchingEnabled
            self?.supportedSampleRates = serverResponse.supportedSampleRates
            self?.defaultOutputDeviceName = serverResponse.defaultOutputDeviceName
            self?.serverHostName = serverResponse.serverHostName
        }
        
        willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            print("Will Resign Active")
            self?.disconnectFromService()
            self?.networkClient.browser?.cancel()
            self?.networkClient.discoveredServices = []
        }
        
        willEnterForegroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            print("Will Enter Foreground")
            self?.browseForServices()
        }
    }
    
    deinit {
        networkClient.disconnectFromService()
        networkClient.browser?.cancel()
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func browseForServices() {
        networkClient.browseForServices()
    }
    
    func connectToService(at index: Int, with request: ClientRequest) {
        networkClient.connectToService(networkClient.discoveredServices[index], with: request)
    }
    
    func sendRequest(_ request: ClientRequest) {
        networkClient.sendRequest(request)
    }
    
    func disconnectFromService() {
        networkClient.disconnectFromService()
    }
    
    func getHostNameFromService(at index: Int) -> String {
        return networkClient.getHostNameFromService(networkClient.discoveredServices[index])
    }
    
}

