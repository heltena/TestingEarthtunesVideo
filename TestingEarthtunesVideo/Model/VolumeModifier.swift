//
//  VolumeModifier.swift
//  EarthtunesCommon
//
//  Created by Helio Tejedor on 3/11/21.
//  Copyright © 2021 Heliodoro Tejedor Navarro. All rights reserved.
//

import Foundation

public enum VolumeModifier: String, Codable {
    case fixed
    case autoAdjusted
}

extension VolumeModifier: CaseIterable, Identifiable {
    public var id: String { rawValue }
}
