//
//  VideoExporter.swift
//  EarthtunesCommon
//
//  Created by Helio Tejedor on 3/11/21.
//  Copyright © 2021 Heliodoro Tejedor Navarro. All rights reserved.
//

import Combine
import Foundation

public class VideoExporter: ObservableObject {

    @Published public var progress: Double?

    private enum CancellableType {
        case exportVideo
    }
    private var cancellableDict: [CancellableType: AnyCancellable] = [:]
    
    public init() {
    }
    
    public func exportVideo(data videoExportingData: VideoExporting, onCompleted: @escaping (URL?) -> Void) {
        VideoExporterPublisher(data: videoExportingData)
            .receive(on: DispatchQueue.main)
            .sink {
                self.progress = nil
                switch $0 {
                case .finished:
                    break
                case .failure(let value):
                    print("Failure: \(value)")
                    onCompleted(nil)
                }
            } receiveValue: {
                switch $0 {
                case .progress(let value):
                    self.progress = value
                case .exported(let url):
                    onCompleted(url)
                    self.progress = nil
                }
            }
        .store(in: &cancellableDict, key: .exportVideo)
    }
    
    public func cancelExportingVideo() {
        cancellableDict[.exportVideo]?.cancel()
        cancellableDict[.exportVideo] = nil
        self.progress = nil
    }
}

