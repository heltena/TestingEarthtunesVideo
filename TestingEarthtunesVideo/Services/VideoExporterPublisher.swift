//
//  VideoExporterPublisher.swift
//  EarthtunesCommon
//
//  Created by Helio Tejedor on 1/24/21.
//  Copyright © 2020 Heliodoro Tejedor Navarro. All rights reserved.
//

import AVFoundation
import Combine
import UIKit
import VideoToolbox

open class VideoExporting {

    public enum Message {
        case progress(Double)
        case exported(URL)
    }

    public enum ExportingError: Error {
        case temporaryFolderError
        case pixelBufferError
        case contextError
        case videoInputAddError
        case videoInputAppendError
        case videoFileError
        case audioFileError
        case mixTrackError
        case mixAddTrackError
        case mixInsertTimeRangeError
        case mixExportingError
        case unknownError
    }

    public let width: CGFloat
    public let height: CGFloat
    public let startDate: Date
    public let duration: TimeInterval
    public let numberOfSeconds: Double
    public let sps: Int
    public let data: [Float]
    public let octavesHigher: OctavesHigher
    public let volumeModifier: VolumeModifier
    
    public init(width: CGFloat, height: CGFloat, startDate: Date, duration: TimeInterval, numberOfSeconds: Double, sps: Int, data: [Float], octavesHigher: OctavesHigher, volumeModifier: VolumeModifier) {
        self.width = width
        self.height = height
        self.startDate = startDate
        self.duration = duration
        self.numberOfSeconds = numberOfSeconds
        self.sps = sps
        self.data = data
        self.octavesHigher = octavesHigher
        self.volumeModifier = volumeModifier
    }
    
    open func generateVideoFrame(currentTime: Double) -> CVPixelBuffer? {
        return nil
    }
}

class VideoExporterSubscription<S: Subscriber>: Subscription where S.Input == VideoExporting.Message, S.Failure == VideoExporting.ExportingError {
        
    class VideoWriterDelegate: NSObject, AVAssetWriterDelegate {
        var fullData = Data()
        
        func assetWriter(_ writer: AVAssetWriter, didOutputSegmentData segmentData: Data, segmentType: AVAssetSegmentType) {
            fullData.append(segmentData)
        }
    }
    
    private var subscriber: S?
    private var isCancelled: Bool
    private let audioQueue: DispatchQueue
    private let videoQueue: DispatchQueue
    private let movieQueue: DispatchQueue
    private var audioUrl: URL!
    private var videoUrl: URL!
    private var movieUrl: URL!
    private var assetExport: AVAssetExportSession?
    
    init(data videoExportingData: VideoExporting, subscriber: S) {
        self.subscriber = subscriber
        self.isCancelled = false
        self.audioQueue = DispatchQueue(label: "edu.northwestern.amaral.audio-queue")
        self.videoQueue = DispatchQueue(label: "edu.northwestern.amaral.video-queue")
        self.movieQueue = DispatchQueue(label: "edu.northwestern.amaral.movie-queue")
               
        guard
            let temporaryFolder = createTemporaryFolder()
        else {
            subscriber.receive(completion: .failure(.temporaryFolderError))
            return
        }

        print("TemperaryFolder: \(temporaryFolder)")
        self.audioUrl = temporaryFolder.appendingPathComponent("audio.m4a")
        self.videoUrl = temporaryFolder.appendingPathComponent("video.mp4")
        self.movieUrl = temporaryFolder.appendingPathComponent("earthtunes.mp4")
        
        var audioStatus: Bool = false
        var videoStatus: Bool = false

        let group = DispatchGroup()
        group.enter()
        self.audioQueue.async {
            self.createWaveFile(data: videoExportingData, url: self.audioUrl) { status in
                audioStatus = status
                if self.isCancelled {
                    try? FileManager.default.removeItem(at: self.audioUrl)
                }
                group.leave()
            }
        }
        
        group.enter()
        self.videoQueue.async {
            self.createVideoFile(data: videoExportingData, url: self.videoUrl) { status in
                videoStatus = status
                if self.isCancelled {
                    try? FileManager.default.removeItem(at: self.videoUrl)
                }
                group.leave()
            }
        }
        
        group.notify(queue: self.movieQueue) {
            if !audioStatus || !videoStatus || self.isCancelled {
                try? FileManager.default.removeItem(at: temporaryFolder)
                return
            }

            self.mixAudioVideo(audioUrl: self.audioUrl, videoUrl: self.videoUrl, movieUrl: self.movieUrl) { status in
                try? FileManager.default.removeItem(at: self.audioUrl)
                try? FileManager.default.removeItem(at: self.videoUrl)
                if status {
                    _ = self.subscriber?.receive(.exported(self.movieUrl))
                    self.subscriber?.receive(completion: .finished)
                }
            }
        }
    }
    
    func request(_ demand: Subscribers.Demand) {
    }
    
    func cancel() {
        self.isCancelled = true
        self.assetExport?.cancelExport()
        self.subscriber = nil
    }
    
    private func createTemporaryFolder() -> URL? {
        for _ in 0..<3 {
            let current = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false, attributes: nil)
                return current
            } catch {
                // Trying another...
            }
        }
        return nil
    }
        
    private func createWaveFile(data videoExportingData: VideoExporting, url: URL, onCompleted: (Bool) -> Void) {
        let sampleRate = Double(videoExportingData.octavesHigher.rawValue) * Double(videoExportingData.sps)
        let sourceBufferData = videoExportingData.data
        let sourceFormatSetting: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1
        ]
        guard
            let sourceBufferFormat = AVAudioFormat(settings: sourceFormatSetting),
            let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceBufferFormat, frameCapacity: AVAudioFrameCount(sourceBufferData.count))
        else {
            subscriber?.receive(completion: .failure(.audioFileError))
            onCompleted(false)
            return
        }
        for (i, value) in sourceBufferData.enumerated() {
            sourceBuffer.floatChannelData?.pointee[i] = value
        }
        sourceBuffer.frameLength = AVAudioFrameCount(sourceBufferData.count)

        // Normalize to 44,100 Hz, PCM
        let normalizedFormatSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1
        ]
        let frameCapacity = AVAudioFrameCount(Float(sourceBufferData.count) * 44_100.0 / Float(sampleRate))
        guard
            let normalizedFormat = AVAudioFormat(settings: normalizedFormatSettings),
            let normalizedBuffer = AVAudioPCMBuffer(pcmFormat: normalizedFormat, frameCapacity: frameCapacity)
        else {
            subscriber?.receive(completion: .failure(.audioFileError))
            onCompleted(false)
            return
        }

        var error: NSError? = nil
        let converter = AVAudioConverter(from: sourceBuffer.format, to: normalizedBuffer.format)!
        let status = converter.convert(to: normalizedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        if let error = error {
            print("Status: \(status), error: \(error)")
            subscriber?.receive(completion: .failure(.audioFileError))
            onCompleted(false)
            return
        }

        // Export to AAC
        let aacFormatSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1
        ]
        
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: aacFormatSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
        } catch {
            subscriber?.receive(completion: .failure(.audioFileError))
            onCompleted(false)
            return
        }
        do {
            try audioFile.write(from: normalizedBuffer)
            onCompleted(true)
        } catch {
            subscriber?.receive(completion: .failure(.audioFileError))
            onCompleted(false)
        }
    }
    
    private func createVideoFile(data videoExportingData: VideoExporting, url: URL, onCompleted: @escaping (Bool) -> Void) {
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let fps = 24.0

        // MovieWriter
        let videoWriterDelegate = VideoWriterDelegate()
        let movieWriter = AVAssetWriter(contentType: .mpeg4Movie)
        movieWriter.initialSegmentStartTime = .zero
        movieWriter.outputFileTypeProfile = .mpeg4CMAFCompliant
        movieWriter.preferredOutputSegmentInterval = .init(seconds: 20.0, preferredTimescale: 1)
        movieWriter.delegate = videoWriterDelegate

        // VideoInput
        let videoOutputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264, // New iPhones: .hevc,
            AVVideoWidthKey: videoExportingData.width,
            AVVideoHeightKey: videoExportingData.height,
            AVVideoCompressionPropertiesKey: [
                kVTCompressionPropertyKey_AverageBitRate: 6_000_000,
                kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Main_AutoLevel, // New iPhones: kVTProfileLevel_HEVC_Main_AutoLevel
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        videoInput.mediaTimeScale = timeScale
        if !movieWriter.canAdd(videoInput) {
            self.subscriber?.receive(completion: .failure(.videoInputAddError))
            onCompleted(false)
            return
        }
        movieWriter.add(videoInput)

        // VideoInputAdaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            String(kCVPixelBufferCGBitmapContextCompatibilityKey): true,
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32ARGB,
            String(kCVPixelBufferWidthKey): videoExportingData.width,
            String(kCVPixelBufferHeightKey): videoExportingData.height]
        let videoInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        movieWriter.startWriting()
        movieWriter.startSession(atSourceTime: .zero)

        var lastProgressValue: Double = 0
        _ = self.subscriber?.receive(.progress(0))
        
        var wasOnCompletedCalled = false
        var currentTime: Double = 0
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
            do {
                while videoInput.isReadyForMoreMediaData && !self.isCancelled {
                    let presentationTime = CMTime(seconds: currentTime, preferredTimescale: timeScale)
                    if currentTime < videoExportingData.numberOfSeconds {
                        guard let pixelBuffer = videoExportingData.generateVideoFrame(currentTime: currentTime) else {
                            throw VideoExporting.ExportingError.pixelBufferError
                        }
                        if !videoInputAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                            print("Failed to append sample buffer to asset write input: \(movieWriter.error!)")
                            print("Video file writer status: \(movieWriter.status.rawValue)")
                            throw VideoExporting.ExportingError.videoInputAppendError
                        }

                        currentTime += 1.0 / fps
                        let progress = min(1.0, currentTime / videoExportingData.numberOfSeconds)
                        if lastProgressValue != progress {
                            _ = self.subscriber?.receive(.progress(progress))
                            lastProgressValue = progress
                        }
                    } else {
                        videoInput.markAsFinished()
                        movieWriter.endSession(atSourceTime: presentationTime)
                        if lastProgressValue != 1.0 {
                            _ = self.subscriber?.receive(.progress(1.0))
                        }
                        self.videoQueue.asyncAfter(deadline: .now() + 0.1) {
                            movieWriter.finishWriting {
                                if movieWriter.status != .completed {
                                    onCompleted(false)
                                    return
                                }
                                if videoWriterDelegate.fullData.count == 0 {
                                    print("Warning! fullData is empty")
                                }
                                do {
                                    try videoWriterDelegate.fullData.write(to: url, options: .atomicWrite)
                                    onCompleted(true)
                                } catch {
                                    self.subscriber?.receive(completion: .failure(.videoFileError))
                                    onCompleted(false)
                                }
                            }
                        }
                        break
                    }
                }
                if self.isCancelled {
                    videoInput.markAsFinished()
                }
                // Only reach this branch if is cancelled, but it could be called twice!
                if self.isCancelled && !wasOnCompletedCalled {
                    onCompleted(false)
                    wasOnCompletedCalled = true
                }
            } catch let error as VideoExporting.ExportingError {
                self.subscriber?.receive(completion: .failure(error))
                onCompleted(false)
            } catch {
                self.subscriber?.receive(completion: .failure(.unknownError))
                onCompleted(false)
            }
        }
    }

    func mixAudioVideo(audioUrl: URL, videoUrl: URL, movieUrl: URL, onCompleted: @escaping (Bool) -> Void) {
        let exportAudioAsset = AVAsset(url: audioUrl)
        let exportVideoAsset = AVAsset(url: videoUrl)
        
        guard
            let audioAssetTrack = exportAudioAsset.tracks(withMediaType: .audio).first,
            let videoAssetTrack = exportVideoAsset.tracks(withMediaType: .video).first
        else {
            subscriber?.receive(completion: .failure(.mixTrackError))
            onCompleted(false)
            return
        }
        
        let mixComposition = AVMutableComposition()
        guard
            let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            subscriber?.receive(completion: .failure(.mixAddTrackError))
            onCompleted(false)
            return
        }
        
        do {
            try compositionAudioTrack.insertTimeRange(audioAssetTrack.timeRange, of: audioAssetTrack, at: .zero)
            try compositionVideoTrack.insertTimeRange(videoAssetTrack.timeRange, of: videoAssetTrack, at: .zero)
        } catch {
            subscriber?.receive(completion: .failure(.mixInsertTimeRangeError))
            onCompleted(false)
            return
        }
        
        assetExport = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetPassthrough)
        guard let assetExport = self.assetExport else {
            subscriber?.receive(completion: .failure(.mixExportingError))
            onCompleted(false)
            return
        }
        
        assetExport.outputFileType = .mp4
        assetExport.outputURL = movieUrl
        assetExport.shouldOptimizeForNetworkUse = false
        
        assetExport.exportAsynchronously {
            switch assetExport.status {
            case .failed:
                self.subscriber?.receive(completion: .failure(.unknownError))
                onCompleted(false)
            case .cancelled:
                onCompleted(false)
            case .completed:
                onCompleted(true)
            default:
                self.subscriber?.receive(completion: .failure(.unknownError))
                onCompleted(false)
            }
        }
    }
}

public struct VideoExporterPublisher: Publisher {
    public typealias Output = VideoExporting.Message
    public typealias Failure = VideoExporting.ExportingError
    
    private let videoExportingData: VideoExporting
    
    public init(data videoExportingData: VideoExporting) {
        self.videoExportingData = videoExportingData
    }
    
    public func receive<S: Subscriber>(subscriber: S) where VideoExporterPublisher.Failure == S.Failure, VideoExporterPublisher.Output == S.Input {
        let subscription = VideoExporterSubscription(data: videoExportingData, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}
