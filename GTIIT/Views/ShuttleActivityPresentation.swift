import ActivityKit
import SwiftUI

/// Shared by WidgetKit and the isolated visual-review app.
struct ShuttleActivitySummary: View {
    let attributes: ShuttleActivityAttributes
    let state: ShuttleActivityAttributes.ContentState
    var isStale = false
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Label(ShuttleActivityWords.route(attributes), systemImage: "bus.fill")
                    .font(.headline).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.75)
                Text("\(attributes.busLabel) · \(attributes.departureTime)")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 5) {
                Text(ShuttleActivityWords.planned(attributes.languageCode))
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                ShuttleActivityCountdown(date: state.departureDate, expired: isStale, language: attributes.languageCode)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(red: 0.38, green: 0.79, blue: 1))
                    .frame(width: 112, alignment: .trailing)
            }
        }.padding(14).accessibilityElement(children: .combine)
    }
}
struct ShuttleActivityCountdown: View {
    let date: Date
    var expired = false
    var language: String?
    var body: some View {
        if expired || date <= Date() {
            Text(ShuttleActivityWords.passed(language)).font(.caption).lineLimit(2)
        } else {
            Text(timerInterval: Date()...date, countsDown: true, showsHours: false)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}
enum ShuttleActivityWords {
    static func route(_ attributes: ShuttleActivityAttributes) -> String {
        if attributes.languageCode == "en" {
            return attributes.origin.replacingOccurrences(of: " Campus", with: "") + " → " + attributes.destination.replacingOccurrences(of: " Campus", with: "")
        }
        return attributes.origin + " → " + attributes.destination
    }
    static func planned(_ language: String?) -> String { language == "en" ? "Departs in" : "距计划发车" }
    static func passed(_ language: String?) -> String { language == "en" ? "Scheduled time passed" : "计划时间已过" }
    static func compact(_ attributes: ShuttleActivityAttributes) -> String {
        let northbound = attributes.directionRaw == ShuttleDirection.southToNorth.rawValue || attributes.destination.contains("北") || attributes.destination.lowercased().contains("north")
        return attributes.languageCode == "en" ? (northbound ? "S→N" : "N→S") : (northbound ? "南→北" : "北→南")
    }
}
