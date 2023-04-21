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
                print("connectToService: .ready - MTU: \(connection.maximumDatagramSize)")
                self.connection = connection
                self.sendRequest(request)
                self.receiveServerResponse(connection: connection)
            case .failed(let error):
                print("connectToService: .failed - Connection failed with error: \(error)")
            default:
                print("connectToService: default - \(connection.state) MTU: \(connection.maximumDatagramSize)\n \(connection.debugDescription)")
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
            print("sendRequest: No connections")
            return
        }
        if connection.state != .ready {
            print("sendRequest: Connetion not ready")
            return
        }
        let message = ClientMessage(request: request, timeStamp: timeStamp())
        do {
            let data = try JSONEncoder().encode(message)
            let dataLength = UInt32(data.count)
            let lengthData = withUnsafeBytes(of: dataLength.bigEndian) { Data($0) }
            let combinedData = lengthData + data
            connection.send(content: combinedData, completion: .contentProcessed({ error in
                if let error = error {
                    print("sendRequest: Error sending: \(error) - \(request.description)")
                } else {
                    print("Request sent - Data size: \(data.count) bytes, MTU: \(connection.maximumDatagramSize) \(message.description)")
                }
            }))
        } catch {
            print("Error encoding request: \(error)")
            print(request.description)
        }
    }
    
    func receiveServerResponse(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { data, _, _, error in
            if let data = data, data.count == 4 {
                let length = data.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
                self.receiveData(connection: connection, totalLength: Int(length), receivedLength: 0, receivedData: Data())
            } else if let error = error {
                print("Error receiving server response length: \(self.timeStamp()) \(error)")
            }
        }
    }

    func receiveData(connection: NWConnection, totalLength: Int, receivedLength: Int, receivedData: Data) {
        let remainingLength = totalLength - receivedLength
        let chunkSize = min(connection.maximumDatagramSize, remainingLength)

        connection.receive(minimumIncompleteLength: chunkSize, maximumLength: chunkSize) { data, _, _, error in
            if let data = data {
                let newReceivedData = receivedData + data
                let newReceivedLength = receivedLength + data.count

                if newReceivedLength == totalLength {
                    do {
                        let serverResponseData = try JSONDecoder().decode(ServerResponse.self, from: newReceivedData)
                        self.onReceiveServerResponse?(serverResponseData)
                        print("Received/Decoded Response: \(serverResponseData.timeStamp)")
                        print(serverResponseData.description)
                        
                        // Continue receiving the next message
                        self.receiveServerResponse(connection: connection)
                    } catch {
                        print("Error decoding server response data: \(self.timeStamp()) \(error)")
                    }
                } else {
                    // Keep receiving data until we have the complete message
                    self.receiveData(connection: connection, totalLength: totalLength, receivedLength: newReceivedLength, receivedData: newReceivedData)
                }
            } else if let error = error {
                print("Error receiving server response data: \(self.timeStamp()) \(error)")
            }
        }
    }
    
    func timeStamp() -> String {
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return dateFormatter.string(from: currentDate)
    }
}

struct CodableAudioStreamBasicDescription: Codable, Equatable, CustomStringConvertible {
    let mSampleRate: Float64
    let mFormatID: UInt32
    let mFormatFlags: UInt32
    let mBytesPerPacket: UInt32
    let mFramesPerPacket: UInt32
    let mBytesPerFrame: UInt32
    let mChannelsPerFrame: UInt32
    let mBitsPerChannel: UInt32
    let mReserved: UInt32
    
    /*
    //Dont need on the iOS side since we never decode/encode
    init(from audioStreamBasicDescription: AudioStreamBasicDescription) {
        mSampleRate = audioStreamBasicDescription.mSampleRate
        mFormatID = audioStreamBasicDescription.mFormatID
        mFormatFlags = audioStreamBasicDescription.mFormatFlags
        mBytesPerPacket = audioStreamBasicDescription.mBytesPerPacket
        mFramesPerPacket = audioStreamBasicDescription.mFramesPerPacket
        mBytesPerFrame = audioStreamBasicDescription.mBytesPerFrame
        mChannelsPerFrame = audioStreamBasicDescription.mChannelsPerFrame
        mBitsPerChannel = audioStreamBasicDescription.mBitsPerChannel
        mReserved = audioStreamBasicDescription.mReserved
    }
    */
    
    static func ==(lhs: CodableAudioStreamBasicDescription, rhs: CodableAudioStreamBasicDescription) -> Bool {
        return lhs.mSampleRate == rhs.mSampleRate &&
               lhs.mFormatID == rhs.mFormatID &&
               lhs.mFormatFlags == rhs.mFormatFlags &&
               lhs.mBytesPerPacket == rhs.mBytesPerPacket &&
               lhs.mFramesPerPacket == rhs.mFramesPerPacket &&
               lhs.mBytesPerFrame == rhs.mBytesPerFrame &&
               lhs.mChannelsPerFrame == rhs.mChannelsPerFrame &&
               lhs.mBitsPerChannel == rhs.mBitsPerChannel &&
               lhs.mReserved == rhs.mReserved
    }
    
    var description: String {
        return String(format: "%.1fkHz/%dbit ", mSampleRate, mBitsPerChannel)
    }
}

struct ServerResponse: Codable, CustomStringConvertible {
    let currentSampleRate: Float64
    let currentBitDepth: UInt32
    let detectedSampleRate: Float64
    let detectedBitDepth: UInt32
    let autoSwitchingEnabled: Bool
    let bitDepthDetectionEnabled: Bool
    let sampleRatesForCurrentBitDepth: [CodableAudioStreamBasicDescription]
    let bitDepthsForCurrentSampleRate: [CodableAudioStreamBasicDescription]
    let defaultOutputDeviceName: String
    let serverHostName: String
    let timeStamp: String
    
    var description: String {
        return "ServerResponse(currentSampleRate: \(currentSampleRate), detectedSampleRate: \(detectedSampleRate), autoSwitchingEnabled: \(autoSwitchingEnabled), serverHostName: \(serverHostName), defaultOutputDeviceName: \(defaultOutputDeviceName), timeStamp: \(timeStamp)\n SR4BD: \(sampleRatesForCurrentBitDepth)\n BD4SR: \(bitDepthsForCurrentSampleRate)"
    }
}

enum ClientRequest: Codable, CustomStringConvertible {
    case refresh
    case toggleAutoSwitching
    case toggleBitDepthDetection
    case setDeviceSampleRate(CodableAudioStreamBasicDescription)
    case setDeviceBitDepth(CodableAudioStreamBasicDescription)
    case setCurrentToDetected
    
    var description: String {
        switch self {
        case .refresh:
            return "ClientRequest.refresh"
        case .toggleAutoSwitching:
            return "ClientRequest.toggleAutoSwitching"
        case .toggleBitDepthDetection:
            return "ClientRequest.toggleBitDepthDetection"
        case .setDeviceSampleRate(let asbdRate):
            return "ClientRequest.setDeviceSampleRate(\(asbdRate.mSampleRate))"
        case .setDeviceBitDepth(let asbdBits):
            return "ClientRequest.setDeviceBitDepth(\(asbdBits.mBitsPerChannel))"
        case .setCurrentToDetected:
            return "ClientRequest.setCurentToDetected"
        }
    }
    
    private enum CodingKeys: CodingKey {
        case type
        case sampleRate
        case bitDepth
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "refresh":
            self = .refresh
        case "toggleAutoSwitching":
            self = .toggleAutoSwitching
        case "toggleBitDepthDetection":
            self = .toggleBitDepthDetection
        case "setDeviceSampleRate":
            let asbdRate = try container.decode(CodableAudioStreamBasicDescription.self, forKey: .sampleRate)
            self = .setDeviceSampleRate(asbdRate)
        case "setDeviceBitDepth":
            let asbdBits = try container.decode(CodableAudioStreamBasicDescription.self, forKey: .bitDepth)
            self = .setDeviceBitDepth(asbdBits)
        case "setCurrentToDetected":
            self = .setCurrentToDetected
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
        case .toggleBitDepthDetection:
            try container.encode("toggleBitDepthDetection", forKey: .type)
        case .setDeviceSampleRate(let asbdRate):
            try container.encode("setDeviceSampleRate", forKey: .type)
            try container.encode(asbdRate, forKey: .sampleRate)
        case .setDeviceBitDepth(let asbdBits):
            try container.encode("setDeviceBitDepth", forKey: .type)
            try container.encode(asbdBits, forKey: .bitDepth)
        case .setCurrentToDetected:
            try container.encode("setCurrentToDetected", forKey: .type)
        }
    }
}

struct ClientMessage: Codable, CustomStringConvertible {
    let request: ClientRequest
    let timeStamp: String
    
    var description: String {
        return "ClientMessage(request: \(request)), timeStamp: \(timeStamp)"
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
