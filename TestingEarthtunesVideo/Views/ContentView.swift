//
//  ContentView.swift
//  TestingEarthtunesVideo
//
//  Created by Helio Tejedor on 8/12/21.
//

import Combine
import SwiftUI

extension String: Identifiable {
    public var id: String { self }
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct ContentView: View {
    @State var showingError: String?
    @State var showingShare: URL?
    @StateObject var videoExporter = VideoExporter()
    
    @State var octavesHigher: OctavesHigher = ._8
    @State var volumeModifier: VolumeModifier = .fixed
    @State var startDate: Date = Date().addingTimeInterval(-24 * 60 * 60)
    @State var duration: Int = 30 * 60
    @State var sps: Int = 40
    
    var waveData: WaveData {
        WaveData(station: "Test", timeZone: "TZ", startDate: startDate, duration: TimeInterval(duration))
    }
    
    var treatedData: [Float] {
        let frequency: Float = 261.63 / Float(octavesHigher.rawValue)
        return stride(from: 0.0, to: Float(duration), by: 1.0/Float(sps)).map { sin($0 * 2 * .pi * frequency) }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Octaves Higher")) {
                    Picker("Octaves Higher", selection: $octavesHigher) {
                        ForEach(OctavesHigher.allCases) { current in
                            Text(current.shortDescription)
                                .tag(current)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Volume Modifier")) {
                    Picker("Volume Modifier", selection: $volumeModifier) {
                        Text("Fixed").tag(VolumeModifier.fixed)
                        Text("Auto Adjusted").tag(VolumeModifier.autoAdjusted)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Start Date & Duration")) {
                    DatePicker("Start Date", selection: $startDate)
                    Picker("Duration", selection: $duration) {
                        Text("30 min").tag(30 * 60)
                        Text("1 hr").tag(1 * 60 * 60)
                        Text("2 hr").tag(2 * 60 * 60)
                        Text("4 hr").tag(4 * 60 * 60)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("SPS")) {
                    Picker("SPS", selection: $sps) {
                        Text("10").tag(10)
                        Text("20").tag(20)
                        Text("40").tag(40)
                        Text("100").tag(100)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if let progress = videoExporter.progress {
                    Section(header: Text("Export video")) {
                        Text(verbatim: String(format: "%0.2f %%", progress * 100))
                    }
                } else {
                    Button("Generate and share") {
                        guard
                            let data = VideoExportingData(waveData: waveData, octavesHigher: octavesHigher, volumeModifier: volumeModifier, sps: sps, treatedData: treatedData)
                        else {
                            self.showingError = "Problems creating the VideoExportingData object"
                            return
                        }
                    
                        videoExporter.exportVideo(data: data) { url in
                            guard
                                let url = url
                            else {
                                self.showingError = "Problems at exportVideo"
                                return
                            }
                            self.showingShare = url
                        }
                    }
                }
            }
            .navigationTitle("Wave")
        }
        .actionSheet(item: $showingError) { message in
            ActionSheet(title: Text("Error"), message: Text(message), buttons: [
                ActionSheet.Button.default(Text("OK")) { self.showingError = nil }
            ])
        }
        .sheet(item: $showingShare) { url in
            ActivityView(activityItems: [url], applicationActivities: nil)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
