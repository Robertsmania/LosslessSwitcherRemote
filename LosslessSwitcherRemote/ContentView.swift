//
//  ContentView.swift
//  LosslessSwitcherRemote
//
//  Created by Kris Roberts on 4/6/23.
//

import SwiftUI
import Network

struct ContentView: View {
    @EnvironmentObject private var losslessSwitcherProxy: LosslessSwitcherProxy
    @State private var selectedSampleRateIndex = 0
    @State private var showConnectionDetails = false

    var body: some View {
        browserSection()
        controlSection()
    }
    
    @ViewBuilder
    func browserSection() -> some View {
        VStack {
            HStack {
                Image(systemName: "music.note")
                Text("Lossless Switcher Remote")
                    .font(.title2)
            }
            .padding(.top)
            
            if losslessSwitcherProxy.discoveredServices.isEmpty {
                Text("No services found")
                
                Button("Browse for services", action: {
                    losslessSwitcherProxy.browseForServices()
                }).padding(.vertical)
                        
            } else {
                
                Button(showConnectionDetails ? "Hide Connection Details" : "Show Connection Details", action: {
                    showConnectionDetails.toggle()
                })
                
                
                if showConnectionDetails {
                    Text("\(losslessSwitcherProxy.discoveredServices.count) service(s) found:")
                        .padding(.top)
                    
                    ForEach(losslessSwitcherProxy.discoveredServices.indices, id: \.self) { index in
                            
                        HStack {
                            Text(losslessSwitcherProxy.getHostNameFromService(at: index))
                            
                            Button("Connect", action: {
                                losslessSwitcherProxy.connectToService(at: index, with: .refresh)
                            })
                            
                            /*
                            Button("Disconnect", action: {
                                losslessSwitcherProxy.disconnectFromService()
                            })
                            .disabled(losslessSwitcherProxy.connection?.state != .ready)
                             */
                        }.padding(.vertical)
                        
                    }
                    
                    if let connectionStatus = losslessSwitcherProxy.connection?.state.description {
                        Text("Current connection: \(losslessSwitcherProxy.serverHostName)")
                        Text("Status: \(connectionStatus)")
                        Button("Disconnect", action: {
                            losslessSwitcherProxy.disconnectFromService()
                        })
                        .disabled(losslessSwitcherProxy.connection?.state != .ready)
                    }
                    
                    Button("Browse for services", action: {
                        losslessSwitcherProxy.browseForServices()
                    }).padding(.vertical)
                    
                }
            }
        }
    }
    
    @ViewBuilder
    func controlSection() -> some View {
        if losslessSwitcherProxy.connection?.state == .ready && !showConnectionDetails {
            Group {
                VStack {
                    Text("\(losslessSwitcherProxy.serverHostName): \(losslessSwitcherProxy.defaultOutputDeviceName)")
                    
                    Button("Refresh", action: {
                        losslessSwitcherProxy.sendRequest(.refresh)
                    }).padding(.vertical)
                    
                    let formattedCurrentSampleRate = String(format: "Current: %.1f kHz", losslessSwitcherProxy.currentSampleRate)
                    Text(formattedCurrentSampleRate)
                    let formattedDetectedSampleRate = String(format: "Detected: %.1f kHz", losslessSwitcherProxy.detectedSampleRate)
                    Text(formattedDetectedSampleRate)
                    let autoSwitchingDescription = losslessSwitcherProxy.autoSwitchingEnabled ? "Auto Switching Enabled" : "Auto Switching Disabled"
                    Text(autoSwitchingDescription)
                    
                    Button("Toggle Auto Switch", action: {
                        losslessSwitcherProxy.sendRequest(.toggleAutoSwitching)
                    }).padding(.vertical)
                    
                    Button("Set Rate to Detected", action: {
                        losslessSwitcherProxy.sendRequest(.setDeviceSampleRate(losslessSwitcherProxy.detectedSampleRate * 1000))
                    }).padding(.vertical)
                        .disabled(losslessSwitcherProxy.detectedSampleRate < 1)
                    
                    Picker("Sample Rate", selection: $selectedSampleRateIndex) {
                        //ForEach(0..<losslessSwitcherProxy.standardSampleRates.count) { index in
                        ForEach(losslessSwitcherProxy.supportedSampleRates.indices, id: \.self) { index in
                            Text("\(losslessSwitcherProxy.supportedSampleRates[index], specifier: "%.1f") kHz")
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 150, height: 100)
                    .clipped()
                    Button("Set Rate to Selected", action: {
                        losslessSwitcherProxy.sendRequest(.setDeviceSampleRate(losslessSwitcherProxy.supportedSampleRates[selectedSampleRateIndex] * 1000))
                    }).padding(.vertical)
                        .disabled(losslessSwitcherProxy.supportedSampleRates.count == 0)
                }
            }
        }
    }
        
}
