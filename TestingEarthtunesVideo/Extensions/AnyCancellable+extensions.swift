//
//  AnyCancellable+extensions.swift
//  TestingEarthtunesVideo
//
//  Created by Helio Tejedor on 8/12/21.
//

import Combine

public extension AnyCancellable {
    func store<KeyType>(in dict: inout Dictionary<KeyType, AnyCancellable>, key: KeyType) {
        dict[key] = self
    }
}
