//
//  LosslessSwitcherProxy.swift
//  LosslessSwitcherRemote
//
//  Created by Kris Roberts on 4/8/23.
//

import SwiftUI
import Network
import CoreAudioTypes

class LosslessSwitcherProxy: ObservableObject {
    static let shared = LosslessSwitcherProxy()
    @Published var currentSampleRate: Float64 = 1
    @Published var currentBitDepth: UInt32 = 0
    @Published var detectedSampleRate: Float64 = 1
    @Published var detectedBitDepth: UInt32 = 0
    @Published var autoSwitchingEnabled: Bool = false
    @Published var bitDepthDetectionEnabled: Bool = false
    @Published var sampleRatesForCurrentBitDepth: [CodableAudioStreamBasicDescription] = []
    @Published var bitDepthsForCurrentSampleRate: [CodableAudioStreamBasicDescription] = []
    @Published var discoveredServices: [NWBrowser.Result] = []
    @Published var connection: NWConnection?
    @Published var defaultOutputDeviceName: String = ""
    @Published var serverHostName: String = ""
    @Published var responseTimeStamp: String = ""
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
            self?.currentBitDepth = serverResponse.currentBitDepth
            self?.detectedSampleRate = serverResponse.detectedSampleRate
            self?.detectedBitDepth = serverResponse.detectedBitDepth
            self?.autoSwitchingEnabled = serverResponse.autoSwitchingEnabled
            self?.bitDepthDetectionEnabled = serverResponse.bitDepthDetectionEnabled
            self?.sampleRatesForCurrentBitDepth = serverResponse.sampleRatesForCurrentBitDepth
            self?.bitDepthsForCurrentSampleRate = serverResponse.bitDepthsForCurrentSampleRate
            self?.defaultOutputDeviceName = serverResponse.defaultOutputDeviceName
            self?.serverHostName = serverResponse.serverHostName
            self?.responseTimeStamp = serverResponse.timeStamp
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

