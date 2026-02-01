//
//  Item.swift
//  puddeuk
//
//  Created by 성현 on 2/1/26.
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
