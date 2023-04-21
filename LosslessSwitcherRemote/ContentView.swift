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
    @State private var selectedBitDepthIndex = 0
    @State private var showConnectionDetails = false
    @State private var pickerSampleRates: [CodableAudioStreamBasicDescription] = []
    @State private var pickerBitDepths: [CodableAudioStreamBasicDescription] = []
    
    private func updatePickerSelections() {
        selectedSampleRateIndex = losslessSwitcherProxy.sampleRatesForCurrentBitDepth.firstIndex { $0.mSampleRate == losslessSwitcherProxy.currentSampleRate } ?? 0
        selectedBitDepthIndex = losslessSwitcherProxy.bitDepthsForCurrentSampleRate.firstIndex { $0.mBitsPerChannel == losslessSwitcherProxy.currentBitDepth } ?? 0
    }

    private func updatePickerData() {
        pickerSampleRates = losslessSwitcherProxy.sampleRatesForCurrentBitDepth
        pickerBitDepths = losslessSwitcherProxy.bitDepthsForCurrentSampleRate
        updatePickerSelections()
    }
    
    var body: some View {
        browserSection()
        controlSection()
        Text(losslessSwitcherProxy.responseTimeStamp).font(.caption)
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
                
                HStack {
                    Button(showConnectionDetails ? "Return to Main UI" : "Connection Details", action: {
                        showConnectionDetails.toggle()
                    })
                    if !showConnectionDetails {
                        Spacer()
                        Button("Refresh", action: {
                            losslessSwitcherProxy.sendRequest(.refresh)
                        })
                    }
                }.padding(.horizontal)
                
                
                if showConnectionDetails {
                    ScrollView {
                        Text("\(losslessSwitcherProxy.discoveredServices.count) service(s) found:")
                            .padding(.top)
                        
                        ForEach(losslessSwitcherProxy.discoveredServices.indices, id: \.self) { index in
                            
                            HStack {
                                Text(losslessSwitcherProxy.getHostNameFromService(at: index))
                                
                                Button("Connect", action: {
                                    losslessSwitcherProxy.connectToService(at: index, with: .refresh)
                                })
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
    }
    
    @ViewBuilder
    func controlSection() -> some View {
        if losslessSwitcherProxy.connection?.state == .ready && !showConnectionDetails {
            Group {
                ScrollView {
                    VStack {
                        Text("\(losslessSwitcherProxy.serverHostName): \(losslessSwitcherProxy.defaultOutputDeviceName)")
                        
                        VStack {
                            let formattedCurrentSampleRate = String(format: "Current: %.1f kHz %d bit", losslessSwitcherProxy.currentSampleRate / 1000, losslessSwitcherProxy.currentBitDepth)
                            Text(formattedCurrentSampleRate)
                                .font(.title2)

                            let formattedDetectedSampleRate = String(format: "Detected: %.1f kHz", losslessSwitcherProxy.detectedSampleRate / 1000)
                            let formattedDetectedBitDepth = String(format: " %d bit", losslessSwitcherProxy.detectedBitDepth)
                            if losslessSwitcherProxy.bitDepthDetectionEnabled {
                                Text(formattedDetectedSampleRate + formattedDetectedBitDepth)
                                    .font(.title2)
                            } else {
                                Text(formattedDetectedSampleRate)
                                    .font(.title2)
                            }
                        }
                        
                        Button("Set Current to Detected", action: {
                            losslessSwitcherProxy.sendRequest(.setCurrentToDetected)
                        }).padding(.bottom)
                            .disabled(losslessSwitcherProxy.detectedSampleRate == 1)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Auto Switch", isOn: Binding<Bool>(
                                get: { losslessSwitcherProxy.autoSwitchingEnabled },
                                set: { newValue in
                                    if newValue != losslessSwitcherProxy.autoSwitchingEnabled {
                                        losslessSwitcherProxy.sendRequest(.toggleAutoSwitching)
                                    }
                                }
                            ))
                            
                            Toggle("Bit Depth Detection", isOn: Binding<Bool>(
                                get: { losslessSwitcherProxy.bitDepthDetectionEnabled },
                                set: { newValue in
                                    if newValue != losslessSwitcherProxy.bitDepthDetectionEnabled {
                                        losslessSwitcherProxy.sendRequest(.toggleBitDepthDetection)
                                    }
                                }
                            ))
                        }.padding(.horizontal)
                        
                        Divider()
                        
                        Text("Manual override:")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        HStack {
                            VStack {
                                Picker("Sample Rate", selection: $selectedSampleRateIndex) {
                                    ForEach(pickerSampleRates.indices, id: \.self) { index in
                                        //Text("\(pickerSampleRates[index].mSampleRate / 1000, specifier: "%.1f") kHz \(pickerSampleRates[index].mBitsPerChannel)")
                                        Text("\(pickerSampleRates[index].mSampleRate / 1000, specifier: "%.1f") kHz")
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 150, height: 100)
                                .clipped()
                                
                                Button("Set Rate", action: {
                                    print("Set Rate: \(pickerSampleRates[selectedSampleRateIndex])")
                                    losslessSwitcherProxy.sendRequest(.setDeviceSampleRate(pickerSampleRates[selectedSampleRateIndex]))
                                }).disabled(pickerSampleRates.count == 0)
                            }
                            
                            VStack {
                                Picker("Bit Depth", selection: $selectedBitDepthIndex) {
                                    ForEach(pickerBitDepths.indices, id: \.self) { index in
                                        //Text("\(pickerBitDepths[index].mBitsPerChannel) bit \(pickerBitDepths[index].mSampleRate / 1000, specifier: "%.1f") kHz")
                                        Text("\(pickerBitDepths[index].mBitsPerChannel) bit")
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 150, height: 100)
                                .clipped()
                                
                                Button("Set Bits", action: {
                                    print("Set Bits: \(pickerBitDepths[selectedBitDepthIndex])")
                                    losslessSwitcherProxy.sendRequest(.setDeviceBitDepth(pickerBitDepths[selectedBitDepthIndex]))
                                }).disabled(pickerBitDepths.count == 0)
                            }
                        }
                    }
                }
                .onChange(of: losslessSwitcherProxy.responseTimeStamp) { _ in
                    updatePickerData()
                }
            }
        }
    }
}
