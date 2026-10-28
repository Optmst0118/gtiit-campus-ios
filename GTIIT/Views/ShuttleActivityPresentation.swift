import ActivityKit
import SwiftUI

/// Shared by WidgetKit and the isolated visual-review app.
struct ShuttleActivitySummary: View {
    let attributes: ShuttleActivityAttributes
    let state: ShuttleActivityAttributes.ContentState
    var isStale = false
    var body: some View {
        ActivityGlassCard(title: ShuttleActivityWords.route(attributes),
            subtitle: attributes.languageCode == "en" ? "Campus shuttle" : "校园班车",
            caption: ShuttleActivityWords.planned(attributes.languageCode),
            target: state.departureDate, expired: isStale,
            badge: attributes.destination, detail: attributes.busLabel, symbol: "bus.fill",
            accent: ActivityPalette.orange, language: attributes.languageCode)
    }
}

/// Shared lock-screen composition: native material, a clear hierarchy and a
/// solid destination/room tile. No simulated vehicle position is shown.
enum ActivityPalette {
    static let orange = Color(red: 1, green: 0.66, blue: 0.36)
    static let blue = Color(red: 0.35, green: 0.76, blue: 1)
}
struct ActivityGlassCard: View {
    let title: String
    let subtitle: String
    let caption: String
    let target: Date
    var expired = false
    let badge: String
    let detail: String
    let symbol: String
    let accent: Color
    var language: String?
    var passedText: String? = nil
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(subtitle).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.65))
                Text(title).font(.headline).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(caption).font(.caption).foregroundStyle(accent)
                    ShuttleActivityCountdown(date: target, expired: expired, language: language, expiredLabel: passedText)
                        .font(.system(size: 27, weight: .semibold, design: .rounded)).foregroundStyle(accent)
                }
                ProgressView(timerInterval: target.addingTimeInterval(-600)...target, countsDown: false)
                    .labelsHidden().tint(accent).frame(height: 4).accessibilityHidden(true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 22, weight: .medium))
                Text(badge).font(.system(size: 24, weight: .bold, design: .rounded)).lineLimit(2).minimumScaleFactor(0.55).multilineTextAlignment(.center)
                Text(detail).font(.caption.weight(.medium)).lineLimit(2).minimumScaleFactor(0.75)
            }.foregroundStyle(Color(red: 0.06, green: 0.10, blue: 0.14))
                .frame(width: 112, height: 128).background(accent.gradient, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        }.padding(16).modifier(ActivityGlassMaterial())
            .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.15), lineWidth: 0.5) }
            .accessibilityElement(children: .combine)
    }
}
struct CourseActivitySummary: View {
    let attributes: CourseActivityAttributes
    let state: CourseActivityAttributes.ContentState
    var isStale = false
    var body: some View {
        ActivityGlassCard(title: attributes.title, subtitle: attributes.language == "en" ? "Next class" : "下一节课",
            caption: isStale ? (attributes.language == "en" ? "Started" : "已上课") : (attributes.language == "en" ? "Starts in" : "距上课"),
            target: state.start, expired: isStale,
            badge: attributes.room.isEmpty ? "—" : attributes.room, detail: attributes.building,
            symbol: "graduationcap.fill", accent: ActivityPalette.blue, language: attributes.language,
            passedText: attributes.language == "en" ? "Class started" : "课程已开始")
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

private struct ActivityGlassMaterial: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }
}
