//
//  ScrollingTimerAttributes.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/5.
//

import ActivityKit
import Foundation

struct ScrollingTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startTime: Date
        var endTime: Date
    }
    var lockScreenTitle: String
    var actionButtonText: String
    var themeColorHex: String
    var theme2ColorHex: String
}
