import ActivityKit
import SwiftUI

/// Shared by WidgetKit and the isolated visual-review app.
struct ShuttleActivitySummary: View {
    let attributes: ShuttleActivityAttributes
    let state: ShuttleActivityAttributes.ContentState
    var isStale = false
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(ShuttleActivityWords.route(attributes))
                    .font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Text(ShuttleActivityWords.departure(state.departureDate, language: attributes.languageCode))
                    .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.8).multilineTextAlignment(.trailing)
            }
            HStack {
                Text(attributes.busLabel).font(.caption).foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(ShuttleActivityWords.planned(attributes.languageCode))
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            HStack(alignment: .center, spacing: 20) {
                ShuttleActivityTrack().frame(maxWidth: .infinity).frame(height: 26)
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
                .multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            Text(timerInterval: Date()...date, countsDown: true, showsHours: false)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                .multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
/// Directional illustration only; it does not represent a live vehicle location.
struct ShuttleActivityTrack: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.cyan.opacity(0.25)).frame(height: 2).padding(.horizontal, 4)
                Circle().fill(.cyan.opacity(0.5)).frame(width: 5, height: 5)
                ShuttleActivityBus().padding(.horizontal, 5).background(.black.opacity(0.8), in: Capsule())
                    .offset(x: max(8, proxy.size.width * 0.2))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.cyan).frame(maxWidth: .infinity, alignment: .trailing)
            }.frame(height: proxy.size.height)
        }.accessibilityHidden(true)
    }
}
private struct ShuttleActivityBus: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).strokeBorder(.cyan, lineWidth: 1.5)
                .frame(width: 28, height: 15).offset(y: -1)
            HStack(spacing: 2) {
                ForEach(0..<4) { _ in RoundedRectangle(cornerRadius: 0.5).fill(.cyan).frame(width: 4, height: 5) }
            }.offset(y: -3)
            HStack(spacing: 13) {
                ForEach(0..<2) { _ in Circle().fill(.cyan).frame(width: 5, height: 5) }
            }.offset(y: 7)
        }.frame(width: 30, height: 22)
    }
}
enum ShuttleActivityWords {
    static func departure(_ date: Date, language: String?) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == "en" ? "en_US" : "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = language == "en" ? "MMM d · HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }
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
