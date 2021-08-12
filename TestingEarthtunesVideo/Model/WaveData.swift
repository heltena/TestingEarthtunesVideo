//
//  WaveData.swift
//  Earthtunes
//
//  Created by Helio Tejedor on 3/11/21.
//  Copyright © 2021 Heliodoro Tejedor Navarro. All rights reserved.
//

import Foundation

public struct WaveData: Codable, Hashable, Equatable {
    public var station: String
    public var timeZone: String
    public var startDate: Date
    public var duration: TimeInterval

    enum CodingKeys: CodingKey {
        case station, timeZone, startDate, duration
    }
    
    public init(station: String, timeZone: String, startDate: Date, duration: TimeInterval) {
        self.station = station
        self.timeZone = timeZone
        self.startDate = startDate
        self.duration = duration
    }
}

public extension WaveData {
    static let zero = WaveData(station: "", timeZone: "UTC", startDate: Date().addingTimeInterval(-60.0*60.0*24.0*4), duration: 30)
}

