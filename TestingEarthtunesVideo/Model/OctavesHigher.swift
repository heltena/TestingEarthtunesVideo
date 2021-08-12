//
//  OctavesHigher.swift
//  EarthtunesCommon
//
//  Created by Helio Tejedor on 3/11/21.
//  Copyright © 2021 Heliodoro Tejedor Navarro. All rights reserved.
//

import Foundation

public enum OctavesHigher: Int, Codable {
    case _7 = 128
    case _8 = 256
    case _9 = 512
    case _10 = 1024
    case _11 = 2048
    case _12 = 4096
    case _13 = 8192
    case _14 = 16384
}

extension OctavesHigher: CaseIterable, Identifiable, CustomStringConvertible {
    public var id: Int { rawValue }
    
    static var prefix: String { "♩" }
    
    public var shortDescription: String {
        switch self {
        case ._7: return "7"
        case ._8: return "8"
        case ._9: return "9"
        case ._10: return "10"
        case ._11: return "11"
        case ._12: return "12"
        case ._13: return "13"
        case ._14: return "14"
        }
    }

    public var description: String {
        "\(Self.prefix) \(shortDescription)"
    }
}
