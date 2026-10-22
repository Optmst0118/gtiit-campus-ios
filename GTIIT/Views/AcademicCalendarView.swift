import PDFKit
import SwiftUI

struct AcademicCalendarView: View {
    @Environment(\.locale) private var nativeLocale
    @State private var year = AcademicCalendarStore.defaultYear()
    @State private var mode = 0
    @State private var day = Date()
    @State private var showPast = false
    @State private var showPDF = false
    private var events: [AcademicEvent] { AcademicCalendarStore.events.filter { $0.year == year && $0.kind == "holiday" && $0.verified } }
    private var today: Date { CampusDate.calendar.startOfDay(for: Date()) }
    private var visible: [AcademicEvent] {
        if mode == 1 { return events.filter { $0.contains(day) || (!$0.verified && $0.start == CampusDate.key(day)) } }
        if showPast { return events }
        return events.filter { ($0.endDate ?? $0.startDate ?? .distantPast) >= today }
    }
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                Picker(L10n.tr("学年"), selection: $year) { ForEach(AcademicCalendarStore.years, id: \.self) { Text($0).tag($0) } }
                Picker(L10n.tr("显示方式"), selection: $mode) { Text(L10n.tr("近期事项")).tag(0); Text(L10n.tr("月历")).tag(1) }.pickerStyle(.segmented)
                if mode == 0, let holiday = events.first(where: { $0.kind == "holiday" && $0.verified && ($0.endDate ?? .distantPast) >= today }), let start = holiday.startDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(start <= today ? L10n.tr("假期进行中") : L10n.tr("下个假期"), systemImage: "sun.max.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                        Text(holiday.title).font(.title3.weight(.semibold))
                        Text(holiday.dateText).font(.subheadline).foregroundStyle(.secondary)
                        if start > today {
                            Text(L10n.format("还有 %@ 天", String(CampusDate.calendar.dateComponents([.day], from: today, to: start).day ?? 0)))
                                .font(.headline.monospacedDigit()).foregroundStyle(Theme.accent)
                        }
                    }.padding(.vertical, 8).accessibilityElement(children: .combine)
                }
            }
            if mode == 1 {
                Section {
                    AcademicMonthPicker(day: $day, range: yearRange, events: events, locale: nativeLocale)
                        .frame(minHeight: 370)
                        .accessibilityLabel(L10n.tr("月历"))
                }
            }
            Section(mode == 1 ? L10n.tr("当天事项") : L10n.tr("校历安排")) {
                if visible.isEmpty {
                    ContentUnavailableView(L10n.tr("暂无事项"), systemImage: "calendar", description: Text(mode == 1 ? L10n.tr("原表未列出当天事项。") : L10n.tr("本学年近期事项已结束，可查看全部。")))
                }
                ForEach(visible) { event in
                    NavigationLink { AcademicEventView(event: event) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: event.symbol).frame(width: 24).foregroundStyle(event.kind == "adjustment" ? Theme.orange : Theme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.title).font(.headline)
                                Text(event.dateText).font(.caption).foregroundStyle(.secondary)
                                Text(event.verified ? event.category : L10n.tr("原表待核实"))
                                    .font(.caption2.weight(.medium)).foregroundStyle(event.verified ? Color.secondary : Theme.orange)
                            }
                        }.padding(.vertical, 5)
                    }
                }
            }
            Section {
                Label(L10n.tr("仅标注原校历中的国内假期与逾越节假期，红点表示放假。"), systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.tr("校历")).navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Theme.pageBackground)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle(L10n.tr("显示全部事项"), isOn: $showPast)
                Button(L10n.tr("查看原始 PDF"), systemImage: "doc.richtext") { showPDF = true }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel(L10n.tr("校历选项"))
        } }
        .onChange(of: year) { _, _ in
            day = max(yearRange.lowerBound, min(Date(), yearRange.upperBound))
            showPast = year != AcademicCalendarStore.defaultYear()
        }
        .sheet(isPresented: $showPDF) { CalendarPDFSheet(year: year) }
    }
    private var yearRange: ClosedRange<Date> {
        let first = String(year.prefix(4)); let last = String(year.suffix(4))
        return CampusDate.parse("\(first)-07-01")!...CampusDate.parse("\(last)-07-31")!
    }
}
private struct AcademicEventView: View {
    @Environment(\.locale) private var nativeLocale
    let event: AcademicEvent
    @State private var showPDF = false
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                Text(event.title).font(.title2.weight(.semibold))
                Label(event.dateText, systemImage: "calendar")
                Label(event.category, systemImage: event.symbol)
            }
            if !event.verified {
                Section { Label(L10n.tr("原表日期待核实，不用于倒计时或自动安排。"), systemImage: "exclamationmark.triangle").foregroundStyle(Theme.orange) }
            }
            Section(L10n.tr("原文与来源")) {
                Text(event.zh); Text(event.en); Text(event.raw).font(.subheadline.monospaced())
                LabeledContent(L10n.tr("学年"), value: event.year)
                Button(L10n.tr("查看原始 PDF")) { showPDF = true }
            }
            if event.kind == "festival" { Section { Text(L10n.tr("此条为节日或说明，不自动视为放假。")) } }
        }.navigationTitle(L10n.tr("事项详情")).navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPDF) { CalendarPDFSheet(year: event.year) }
    }
}
private struct CalendarPDFSheet: View {
    @Environment(\.locale) private var nativeLocale
    let year: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let _ = nativeLocale.identifier

        NavigationStack {
            Group {
                if let url = AcademicCalendarStore.pdfURL(year: year) { LocalPDFReader(url: url) }
                else { ContentUnavailableView(L10n.tr("原件不可用"), systemImage: "doc") }
            }.navigationTitle(year).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.tr("完成")) { dismiss() } } }
        }
    }
}
struct LocalPDFReader: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url); return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}

/// Native month navigation with source-backed event dots, without text crowding date cells.
private struct AcademicMonthPicker: UIViewRepresentable {
    @Binding var day: Date
    let range: ClosedRange<Date>
    let events: [AcademicEvent]
    let locale: Locale
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = CampusDate.calendar; view.timeZone = CampusDate.calendar.timeZone
        view.locale = locale; view.delegate = context.coordinator
        view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        context.coordinator.apply(self, to: view)
        return view
    }
    func updateUIView(_ view: UICalendarView, context: Context) { context.coordinator.apply(self, to: view) }
    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: AcademicMonthPicker
        private var lower: Date?
        private var selected: Date?
        init(_ parent: AcademicMonthPicker) { self.parent = parent }
        func apply(_ value: AcademicMonthPicker, to view: UICalendarView) {
            parent = value; view.locale = value.locale
            if lower != value.range.lowerBound {
                lower = value.range.lowerBound
                view.availableDateRange = DateInterval(start: value.range.lowerBound, end: value.range.upperBound.addingTimeInterval(86_399))
                view.setVisibleDateComponents(CampusDate.calendar.dateComponents([.year, .month, .day], from: value.day), animated: false)
            }
            if selected != value.day {
                selected = value.day
                (view.selectionBehavior as? UICalendarSelectionSingleDate)?.setSelected(CampusDate.calendar.dateComponents([.year, .month, .day], from: value.day), animated: false)
            }
            let dates = value.events.flatMap { event -> [DateComponents] in
                guard let a = event.startDate, let b = event.endDate, event.verified, event.kind == "holiday" else { return [] }
                let count = min(60, CampusDate.calendar.dateComponents([.day], from: a, to: b).day ?? 0)
                return (0...max(0,count)).compactMap { CampusDate.calendar.date(byAdding: .day, value: $0, to: a) }.map { CampusDate.calendar.dateComponents([.year, .month, .day], from: $0) }
            }
            view.reloadDecorations(forDateComponents: dates, animated: false)
        }
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = CampusDate.calendar.date(from: dateComponents) else { return nil }
            let events = parent.events.filter { $0.kind == "holiday" && $0.contains(date) }
            guard !events.isEmpty else { return nil }
            return .customView {
                let label = UILabel(); label.text = "•"
                label.font = .systemFont(ofSize: 11, weight: .bold)
                label.textColor = .systemRed
                label.accessibilityLabel = events.map(\.title).joined(separator: ", ")
                return label
            }
        }
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let components = dateComponents, let value = CampusDate.calendar.date(from: components) else { return }
            selected = value; parent.day = value
        }
    }
}
