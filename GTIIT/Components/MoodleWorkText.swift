import SwiftUI

struct MoodleWorkText: View {
    @Environment(\.locale) private var nativeLocale
    let item: MoodleWork
    var compact = false
    var body: some View {
        let _ = nativeLocale.identifier
        VStack(alignment: .leading, spacing: compact ? 4 : 5) {
            Text(item.displayName).font(compact ? .subheadline.weight(.semibold) : .headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true).lineLimit(compact ? 2 : nil)
            Text(item.course).font(.caption).foregroundStyle(.secondary).lineLimit(compact ? 1 : 2)
            if let date = item.dueDate {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Label(compact ? date.gtiitFormatted() : L10n.format(date < context.date ? "已截止 · %@" : "截止 · %@", dateLabel(date)), systemImage: "clock")
                        .font(compact ? .caption : .subheadline.weight(.medium))
                        .foregroundStyle(item.hasUrgentDeadline(now: context.date) ? Color(uiColor: .systemRed) : Theme.accent)
                }
            }
            if !compact, let date = item.openedDate {
                Text(L10n.format(date > Date() ? "开放 · %@" : "最近开放 · %@", dateLabel(date))).font(.caption).foregroundStyle(Theme.accent)
            }
            if !compact { Text(L10n.tr(item.status == "notSubmitted" ? "尚未提交" : item.status == "draft" ? "草稿" : item.status == "submitted" ? "已提交" : "提交状态未知"))
                .font(.caption).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = L10n.locale; f.timeZone = CampusDate.calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("MMM d EEE HH:mm"); return f.string(from: date)
    }
}

/// Used by inbox and cached summaries as well as the detailed assignment rows.
struct MoodleDeadlineDate: View {
    let item: MoodleWork
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let due = item.dueDate {
                Text(due.gtiitFormatted(date: .abbreviated, time: .shortened)).font(.caption)
                    .foregroundStyle(item.hasUrgentDeadline(now: context.date) ? Color(uiColor: .systemRed) : Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
