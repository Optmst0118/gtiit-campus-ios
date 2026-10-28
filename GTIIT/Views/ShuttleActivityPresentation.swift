import ActivityKit
import SwiftUI

enum ActivityPalette {
    static let orange = Color(red: 1, green: 0.66, blue: 0.36)
    static let blue = Color(red: 0.35, green: 0.76, blue: 1)
}

/// Both system surfaces use the same information hierarchy. No vehicle-position graphics.
struct ShuttleActivitySummary: View {
    let attributes: ShuttleActivityAttributes
    let state: ShuttleActivityAttributes.ContentState
    var isStale = false
    var island = false
    var body: some View {
        ActivityGlassCard(title: ShuttleActivityWords.compact(attributes),
            caption: attributes.languageCode == "en" ? "Departs in" : "距发车",
            target: state.departureDate, expired: isStale,
            badge: attributes.destination,
            detail: attributes.departureTime + " · " + attributes.busLabel,
            accent: ActivityPalette.orange, language: attributes.languageCode, island: island)
    }
}

struct ActivityGlassCard: View {
    let title: String
    let caption: String
    let target: Date
    var expired = false
    let badge: String
    let detail: String
    let accent: Color
    var language: String?
    var passedText: String? = nil
    var island = false
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: island ? 18 : 20, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(island ? 1 : 2).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text(caption).font(.caption).foregroundStyle(accent)
                    ShuttleActivityCountdown(date: target, expired: expired, language: language, expiredLabel: passedText)
                        .font(.system(size: island ? 38 : 46, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                    Text(detail).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1).minimumScaleFactor(0.75)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(badge).font(.system(size: island ? 30 : 36, weight: .bold, design: .rounded))
                    .lineLimit(2).minimumScaleFactor(0.55).multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.06, green: 0.10, blue: 0.14))
                    .padding(10).frame(width: geometry.size.width * 0.43, height: geometry.size.height)
                    .background(accent, in: RoundedRectangle(cornerRadius: island ? 22 : 26, style: .continuous))
            }
        }.frame(height: island ? 112 : 154)
            .padding(island ? 4 : 16)
            .modifier(ActivityGlassMaterial(enabled: !island))
            .accessibilityElement(children: .combine)
    }
}

struct CourseActivitySummary: View {
    let attributes: CourseActivityAttributes
    let state: CourseActivityAttributes.ContentState
    var isStale = false
    var island = false
    var body: some View {
        ActivityGlassCard(title: attributes.title,
            caption: attributes.language == "en" ? "Starts in" : "距上课",
            target: state.start, expired: isStale,
            badge: attributes.room.isEmpty ? "—" : attributes.room,
            detail: ShuttleActivityWords.time(state.start) + (attributes.building.isEmpty ? "" : " · " + attributes.building),
            accent: ActivityPalette.blue, language: attributes.language,
            passedText: attributes.language == "en" ? "Started" : "已上课", island: island)
    }
}

struct ShuttleActivityCountdown: View {
    let date: Date
    var expired = false
    var language: String?
    var expiredLabel: String? = nil
    var body: some View {
        if expired || date <= Date() {
            Text(expiredLabel ?? ShuttleActivityWords.passed(language)).font(.caption).lineLimit(2)
        } else {
            Text(timerInterval: Date()...date, countsDown: true, showsHours: true)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
enum ShuttleActivityWords {
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
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

private struct ActivityGlassMaterial: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if !enabled { content }
        else if #available(iOS 26.0, *) {
            content.background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 32))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
    }
}
