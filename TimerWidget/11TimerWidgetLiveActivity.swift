//
//  TimerWidgetLiveActivity.swift
//  TimerWidget
//
//  Created by kikiho on 2026/6/4.
//

import ActivityKit
import WidgetKit
import SwiftUI

@main
struct TimerWidgetLiveActivity: Widget {
    private var celebrateURL: URL {
        var components = URLComponents()
        components.scheme = "picdemo"
        components.host = "celebrate"
        return components.url ?? URL(fileURLWithPath: "/")
    }
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScrollingTimerAttributes.self) { context in
            let themeColor = Color(hex: context.attributes.themeColorHex)
            
            // ==========================================
            // 鎖定畫面 (Lock Screen)
            // ==========================================
            VStack(spacing: 12) {
                Text(context.attributes.lockScreenTitle)
                    .font(.headline)
                
                ProgressView(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                    .progressViewStyle(.linear)
                    .tint(themeColor)
                    .padding(.horizontal)
                
                Link(destination: celebrateURL) {
                    Text(context.attributes.actionButtonText)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .activityBackgroundTint(Color.black.opacity(0.8))
            
        } dynamicIsland: { context in
            let themeColor = Color(hex: context.attributes.themeColorHex)
            let theme2Color = Color(hex: context.attributes.theme2ColorHex)

            // ==========================================
            // 動態島 (Dynamic Island)
            // ==========================================
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("island_icon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(theme2Color)
                        .frame(width: 22, height: 22)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                        .monospacedDigit()
                        .foregroundColor(themeColor)
                        .font(.headline)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 16) {
                        ProgressView(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                            .progressViewStyle(.linear)
                            .tint(themeColor)
                        
                        Link(destination: celebrateURL) {
                            HStack {
                                Text(context.attributes.actionButtonText)
                            }
                            .font(.headline)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(themeColor)
                            .foregroundColor(theme2Color)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                Image("island_icon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(theme2Color)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                Text(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                    .frame(width: 40)
                    .monospacedDigit()
                    .foregroundColor(themeColor)
            } minimal: {
                Image("island_icon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(theme2Color)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(themeColor)
        }
    }
}

// 顏色擴充輔助
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}
