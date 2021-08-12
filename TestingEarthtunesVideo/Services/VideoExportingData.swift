//
//  VideoExportingData.swift
//  Earthtunes
//
//  Created by Helio Tejedor on 3/10/21.
//  Copyright © 2021 Heliodoro Tejedor Navarro. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
import UIKit

public class VideoExportingData: VideoExporting {
    let cgImage: CGImage
    let attributedString: NSAttributedString
    let dataPathHeight: CGFloat
    let dataPath: CGPath
    let timeZone: String
    
    public init?(waveData: WaveData, octavesHigher: OctavesHigher, volumeModifier: VolumeModifier, sps: Int, treatedData: [Float]) {
        guard let cgImage = UIImage(named: "ExportVideoBackground", in: Bundle.main, with: nil)?.cgImage else { return nil }
        self.cgImage = cgImage
        
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.unitsStyle = .short
        durationFormatter.allowedUnits = [.hour, .minute, .second]
        let durationString = durationFormatter.string(from: waveData.duration) ?? ""
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: waveData.startDate)
        
        let normalizedString: String
        switch volumeModifier {
        case .autoAdjusted: normalizedString = "Auto Adjusted"
        case .fixed: normalizedString = "Fixed"
        }
        
        let octavesHigherString = octavesHigher.description
        let stationAttributedString = NSAttributedString(string: waveData.station, attributes: [.font: UIFont.systemFont(ofSize: 48, weight: .bold)])
        let dateAttributedString = NSAttributedString(string: "\(dateString) - \(durationString)", attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .semibold)])
        let timeZoneAttributedString = NSAttributedString(string: waveData.timeZone, attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)])
        let dataManiputalionAttributedString = NSAttributedString(string: "\(normalizedString), \(octavesHigherString)", attributes: [.font: UIFont.systemFont(ofSize: 18, weight: .semibold)])
        
        let attributedString = NSMutableAttributedString()
        attributedString.append(stationAttributedString)
        attributedString.append(NSAttributedString(string: "\n"))
        attributedString.append(dateAttributedString)
        attributedString.append(NSAttributedString(string: "\n"))
        attributedString.append(timeZoneAttributedString)
        attributedString.append(NSAttributedString(string: "\n"))
        attributedString.append(dataManiputalionAttributedString)
        self.attributedString = attributedString
        
        self.dataPathHeight = CGFloat(cgImage.width) * 150.0 / 640.0
        self.dataPath = VideoExportingData.path(for: treatedData, width: CGFloat(cgImage.width), height: dataPathHeight, inverseY: true)
        self.timeZone = waveData.timeZone
        
        let sampleRate = Double(sps) * Double(octavesHigher.rawValue)
        let numberOfSeconds = Double(treatedData.count) / sampleRate

        super.init(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height), startDate: waveData.startDate, duration: waveData.duration, numberOfSeconds: numberOfSeconds, sps: sps, data: treatedData, octavesHigher: octavesHigher, volumeModifier: volumeModifier)
    }
    
    public override func generateVideoFrame(currentTime: Double) -> CVPixelBuffer? {
        var maybePixelBuffer: CVPixelBuffer? = nil
        guard
            kCVReturnSuccess == CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height, kCVPixelFormatType_32ARGB, NSDictionary(), &maybePixelBuffer),
            let pixelBuffer = maybePixelBuffer
        else {
            return nil
        }

        let flags = CVPixelBufferLockFlags(rawValue: 0)
        if kCVReturnSuccess != CVPixelBufferLockBaseAddress(pixelBuffer, flags) {
            return nil
        }

        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, flags)
        }

        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(pixelBuffer),
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        context.move(to: .init(x: 0, y: CGFloat(cgImage.height) - dataPathHeight))
        context.setStrokeColor(UIColor(named: "ShareNorthwestern", in: Bundle.main, compatibleWith: nil)!.cgColor)
        context.addPath(dataPath)
        context.strokePath()

        let dialX = CGFloat(cgImage.width) * CGFloat(currentTime) / CGFloat(numberOfSeconds)

        let dialPath = CGMutablePath()
        dialPath.move(to: .init(x: dialX, y: 0))
        dialPath.addLine(to: .init(x: dialX, y: dataPathHeight))

        context.setLineWidth(2)
        context.setStrokeColor(UIColor(named: "Dial")!.cgColor)
        context.addPath(dialPath)
        context.strokePath()

        do {
            let currentSeconds = TimeInterval(CGFloat(duration) * CGFloat(currentTime) / CGFloat(numberOfSeconds))
            let currentDate = startDate.addingTimeInterval(currentSeconds)
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short

            let attributedString = NSAttributedString(string: dateFormatter.string(from: currentDate), attributes: [.font: UIFont.systemFont(ofSize: 12.0, weight: .medium)])
            let attributedStringX = min(max(10, CGFloat(dialX) - attributedString.size().width / 2), CGFloat(cgImage.width) - attributedString.size().width - 20)

            let textPath = CGMutablePath()
            textPath.addRect(CGRect(x: attributedStringX, y: 0.0, width: attributedString.size().width, height: dataPathHeight + attributedString.size().height + 2))
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            let textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), textPath, nil)
            CTFrameDraw(textFrame, context)
        }

        do {
            let textPath = CGMutablePath()
            textPath.addRect(CGRect(x: 20, y: 0, width: cgImage.width - 40, height: Int(CGFloat(cgImage.height) - dataPathHeight - 40)))
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            let textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), textPath, nil)
            CTFrameDraw(textFrame, context)
        }

        return pixelBuffer
    }
    
    private static func path(for data: [Float], width: CGFloat, height: CGFloat, inverseY: Bool) -> CGPath {
        if data.isEmpty {
            return CGPath(rect: .zero, transform: nil)
        }
        let numberOfFrames = data.count
        let steps = CGFloat(numberOfFrames) / width
        
        let max: CGFloat = 1.0 //data.map { CGFloat(abs($0)) }.max() ?? 1.0
        var previousIndex = 0
        
        let path = CGMutablePath()
        for i in 0..<Int(width) {
            let index = min(numberOfFrames-1, Int(CGFloat(i) * steps))
            let minValue = CGFloat(data[previousIndex..<index].min() ?? 0) / max
            let maxValue = CGFloat(data[previousIndex..<index].max() ?? 0) / max
            previousIndex = index

            let yMove: CGFloat
            let yLine: CGFloat
            if !inverseY {
                yMove = height * (0.5 + minValue / 2.0)
                yLine = height * (0.5 + maxValue / 2.0)
            } else {
                yMove = height - height * (0.5 + minValue / 2.0)
                yLine = height - height * (0.5 + maxValue / 2.0)
            }
            path.move(to: .init(x: CGFloat(i), y: yMove))
            path.addLine(to: .init(x: CGFloat(i), y: yLine))
        }
        return path
    }
}
