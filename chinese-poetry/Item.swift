//
//  Item.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
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
