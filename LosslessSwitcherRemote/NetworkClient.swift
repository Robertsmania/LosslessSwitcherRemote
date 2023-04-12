//
//  NetworkClient.swift
//  LosslessSwitcherRemote
//
//  Created by Kris Roberts on 4/6/23.
//

import Foundation
import Network

class NetworkClient: ObservableObject {
    var browser: NWBrowser?
    @Published var discoveredServices: [NWBrowser.Result] = []
    @Published var connection: NWConnection?
    
    var onReceiveServerResponse: ((ServerResponse) -> Void)?
    
    func browseForServices() {
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_lossless-switcher._tcp", domain: "local"), using: .tcp)
        browser?.browseResultsChangedHandler = { results, changes in
            for change in changes {
                switch change {
                case .added(let browseResult):
                    // Found a new service, add it to the discoveredServices array if it doesn't already exist
                    if !self.discoveredServices.contains(where: { $0.endpoint == browseResult.endpoint }) {
                        self.discoveredServices.append(browseResult)
                        if self.discoveredServices.count == 1 {
                            //if its the only service, connect automatically
                            self.connectToService(browseResult, with: .refresh)
                        }
                        print("added")
                    }
                case .removed(let browseResult):
                    // A service was removed, remove it from the discoveredServices array
                    self.discoveredServices.removeAll { $0.endpoint == browseResult.endpoint }
                    // Only close the connection if the removed service's endpoint matches the current connection's endpoint
                    if let currentConnection = self.connection, currentConnection.endpoint == browseResult.endpoint {
                        self.disconnectFromService()
                    }
                    print("removed")
                default:
                    break
                }
            }
        }
        
        browser?.start(queue: .main)
    }
    
    func connectToService(_ service: NWBrowser.Result, with request: ClientRequest) {
        self.connection?.cancel()
        let connection = NWConnection(to: service.endpoint, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connection established")
                self.connection = connection
                self.sendRequest(request)
                self.receiveServerResponse(connection: connection)
            case .failed(let error):
                print("Connection failed with error: \(error)")
            default:
                break
            }
        }

        connection.start(queue: .main)
    }
    
    func disconnectFromService() {
        connection?.cancel()
        connection = nil
    }
    
    func getHostNameFromService(_ browseResult: NWBrowser.Result) -> String {
        var hostNameString = ""
        
        switch browseResult.metadata {
        case .bonjour(let record):
            if let serverHostName = record.dictionary["serverHostName"] {
                hostNameString = serverHostName
            }
        case .none:
            hostNameString = "none"
        @unknown default:
            hostNameString = "default"
        }
        
        return hostNameString
    }
    
    func sendRequest(_ request: ClientRequest) {
        guard let connection = connection else {
            print("No connections")
            return
        }
        if connection.state != .ready {
            print("Connetion not ready")
            return
        }
        let message = ClientMessage(request: request)
        print("Sending \(message)")
        do {
            let data = try JSONEncoder().encode(message)
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    print("Error sending request: \(error)")
                } else {
                    print("Request sent")
                }
            }))
        } catch {
            print("Error encoding request: \(error)")
        }
    }
    
    func receiveServerResponse(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            if let data = data {
                do {
                    let serverResponseData = try JSONDecoder().decode(ServerResponse.self, from: data)
                    print("Received: \(serverResponseData)")
                    self.onReceiveServerResponse?(serverResponseData)
                    self.receiveServerResponse(connection: connection)
                } catch {
                    print("Error decoding server response data: \(error)")
                }
            } else if let error = error {
                print("Error receiving server response data: \(error)")
            }
        }
    }
    

}

struct ServerResponse: Codable, CustomStringConvertible {
    let currentSampleRate: Float64
    let detectedSampleRate: Float64
    let autoSwitchingEnabled: Bool
    let supportedSampleRates: [Float64]
    let defaultOutputDeviceName: String
    let serverHostName: String
    
    var description: String {
        return "ServerResponse(currentSampleRate: \(currentSampleRate), detectedSampleRate: \(detectedSampleRate), autoSwitchingEnabled: \(autoSwitchingEnabled), serverHostName: \(serverHostName), defaultOutputDeviceName: \(defaultOutputDeviceName), supportedSampleRates: \(supportedSampleRates))"
    }
}

enum ClientRequest: Codable, CustomStringConvertible {
    case refresh
    case toggleAutoSwitching
    case setDeviceSampleRate(Float64)
    
    var description: String {
        switch self {
        case .refresh:
            return "ClientRequest.refresh"
        case .toggleAutoSwitching:
            return "ClientRequest.toggleAutoSwitching"
        case .setDeviceSampleRate(let sampleRate):
            return "ClientRequest.setDeviceSampleRate(\(sampleRate))"
        }
    }
    
    private enum CodingKeys: CodingKey {
        case type
        case sampleRate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "refresh":
            self = .refresh
        case "toggleAutoSwitching":
            self = .toggleAutoSwitching
        case "setDeviceSampleRate":
            let sampleRate = try container.decode(Float64.self, forKey: .sampleRate)
            self = .setDeviceSampleRate(sampleRate)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid request type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .refresh:
            try container.encode("refresh", forKey: .type)
        case .toggleAutoSwitching:
            try container.encode("toggleAutoSwitching", forKey: .type)
        case .setDeviceSampleRate(let sampleRate):
            try container.encode("setDeviceSampleRate", forKey: .type)
            try container.encode(sampleRate, forKey: .sampleRate)
        }
    }
}

struct ClientMessage: Codable, CustomStringConvertible {
    let request: ClientRequest
    
    var description: String {
        return "ClientMessage(request: \(request))"
    }
}

extension NWConnection.State {
    var description: String {
        switch self {
        case .cancelled:
            return "Cancelled"
        case .failed(_):
            return "Failed"
        case .preparing:
            return "Preparing"
        case .ready:
            return "Ready"
        case .waiting(_):
            return "Waiting"
        default:
            return "Unknown"
        }
    }
}
