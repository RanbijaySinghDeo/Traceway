//
//  Item.swift
//  TraceWay
//
//  Created by Ranbijay SinghDeo on 22/08/26.
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
