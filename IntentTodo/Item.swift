//
//  Item.swift
//  IntentTodo
//
//  Created by 藤井陽介 on 2026/01/29.
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
