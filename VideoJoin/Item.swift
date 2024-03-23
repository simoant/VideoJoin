//
//  Item.swift
//  VideoJoin
//
//  Created by Anton Simonov on 23/3/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
