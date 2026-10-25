import PDFKit
import SwiftUI

struct AcademicCalendarView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @AppStorage("calendar.showExams") private var showExams = false
    @State private var year = AcademicCalendarStore.defaultYear()
    @State private var mode = 0
    @State private var day = Date()
    @State private var examRevision = 0
    @State private var showPast = false
    @State private var showPDF = false
    private var events: [AcademicEvent] { AcademicCalendarStore.holidays(year: year) }
    private var today: Date { CampusDate.calendar.startOfDay(for: Date()) }
    private var visible: [AcademicEvent] {
        if mode == 1 { return events.filter { $0.contains(day) || (!$0.verified && $0.start == CampusDate.key(day)) } }
        if showPast { return events }
        return events.filter { ($0.endDate ?? $0.startDate ?? .distantPast) >= today }
    }
    private var calendarExams: [StudentExam] {
        showExams ? CalendarExamSelection.items(app.exams.items, range: yearRange, day: mode == 1 ? day : nil, from: showPast ? nil : today) : []
    }
    var body: some View {
        let _ = nativeLocale.identifier
        let _ = examRevision

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
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
            }.padding(16).cardBackground()
            if mode == 1 {
                VStack {
                    AcademicMonthPicker(day: $day, range: yearRange, year: year, locale: nativeLocale, examDates: showExams ? Set(app.exams.items.map(\.date)) : [])
                        .id(year)
                        .padding(20)
                }.cardBackground()
            }
            Text(mode == 1 ? L10n.tr("当天事项") : L10n.tr("校历安排")).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 16) {
                if visible.isEmpty && calendarExams.isEmpty {
                    if mode == 1, CampusDate.calendar.isDateInWeekend(day) {
                        Label(L10n.tr("周末休息"), systemImage: "sun.max")
                    } else {
                        ContentUnavailableView(L10n.tr("暂无事项"), systemImage: "calendar")
                    }
                }
                ForEach(calendarExams) { exam in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(exam.course, systemImage: "pencil.and.list.clipboard").font(.headline).foregroundStyle(Theme.accent)
                        Text("\(exam.session) · \(CampusDate.display(exam.start!, weekday: true)) · \(exam.time)")
                            .font(.subheadline).monospacedDigit()
                        Label(exam.venue.isEmpty ? L10n.tr("地点待定") : exam.venue, systemImage: "mappin.and.ellipse")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5).accessibilityElement(children: .combine)
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
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 5).foregroundStyle(.primary)
                    }.buttonStyle(.plain)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).cardBackground()
            }.padding(20)
        }
        .navigationTitle(L10n.tr("校历")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
        .scrollContentBackground(.hidden).background(Theme.pageBackground)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle(L10n.tr("显示考试时间"), isOn: $showExams)
                Toggle(L10n.tr("显示全部事项"), isOn: $showPast)
                Button(L10n.tr("查看原始 PDF"), systemImage: "doc.richtext") { showPDF = true }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel(L10n.tr("校历选项"))
        } }
        .onChange(of: year) { _, _ in
            day = max(yearRange.lowerBound, min(Date(), yearRange.upperBound))
            showPast = year != AcademicCalendarStore.defaultYear()
        }
        .task(id: showExams) {
            if showExams { app.exams.refresh(allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData }) }
        }
        .onReceive(app.exams.objectWillChange) { _ in examRevision += 1 }
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
        }.navigationTitle(L10n.tr("事项详情")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
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
            }.navigationTitle(year).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
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

/// A SwiftUI month grid gives date backgrounds a public, accessible rendering path.
private struct AcademicMonthPicker: View {
    @Binding var day: Date
    let range: ClosedRange<Date>
    let year: String
    let locale: Locale
    let examDates: Set<String>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var month: Date?
    private var shown: Date { month ?? startOfMonth(max(range.lowerBound, min(day, range.upperBound))) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private func startOfMonth(_ date: Date) -> Date { CampusDate.calendar.dateInterval(of: .month, for: date)!.start }
    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = locale; f.calendar = CampusDate.calendar
        f.timeZone = CampusDate.calendar.timeZone; f.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return f.string(from: date)
    }
    private var monthSelection: Binding<Date> {
        Binding(get: { shown }, set: { selectMonth($0) })
    }
    private var weekdays: [String] {
        let f = DateFormatter(); f.locale = locale; f.calendar = CampusDate.calendar
        let symbols = f.veryShortStandaloneWeekdaySymbols!
        return Array(symbols.dropFirst()) + [symbols[0]]
    }
    private func cells(for month: Date) -> [Date?] {
        let cal = CampusDate.calendar
        let offset = (cal.component(.weekday, from: month) + 5) % 7
        let count = cal.range(of: .day, in: .month, for: month)!.count
        return (0..<42).map { index in
            guard (offset..<(offset + count)).contains(index) else { return nil }
            return cal.date(byAdding: .day, value: index - offset, to: month)
        }
    }
    private var months: [Date] {
        let first = startOfMonth(range.lowerBound)
        return (0...12).compactMap { CampusDate.calendar.date(byAdding: .month, value: $0, to: first) }
    }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Menu {
                    Picker(L10n.tr("月份"), selection: monthSelection) {
                        ForEach(months, id: \.self) { date in Text(monthTitle(date)).tag(date) }
                    }.pickerStyle(.inline)
                } label: { HStack(spacing: 6) { Text(monthTitle(shown)).font(.headline).lineLimit(1).minimumScaleFactor(0.75); Image(systemName: "chevron.down").font(.caption.weight(.semibold)) } }
                Spacer(minLength: 4)
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .disabled(shown <= startOfMonth(range.lowerBound)).accessibilityLabel(L10n.tr("上个月"))
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(shown >= startOfMonth(range.upperBound)).accessibilityLabel(L10n.tr("下个月"))
            }.foregroundStyle(Theme.accent).buttonStyle(.plain)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7) { index in
                    Text(weekdays[index]).font(.caption.weight(.medium))
                        .foregroundStyle(index >= 5 ? Color.red : Color.secondary)
                        .frame(maxWidth: .infinity).accessibilityHidden(true)
                }
            }
            GeometryReader { geometry in
                ScrollViewReader { reader in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(months, id: \.self) { date in
                                LazyVGrid(columns: columns, spacing: 4) {
                                    ForEach(0..<42) { index in
                                        if let cell = cells(for: date)[index] { dateCell(cell) }
                                        else { Color.clear.frame(height: 44).accessibilityHidden(true) }
                                    }
                                }.frame(width: geometry.size.width).id(date)
                            }
                        }.scrollTargetLayout()
                    }.scrollIndicators(.hidden).scrollTargetBehavior(.paging)
                        .scrollPosition(id: Binding<Date?>(get: { shown }, set: { if let date = $0 { selectMonth(date) } }), anchor: .center)
                        .task { await Task.yield(); reader.scrollTo(shown, anchor: .center) }
                }
            }.frame(height: 284)


        }
    }
    private func dateCell(_ date: Date) -> some View {
        let selected = CampusDate.calendar.isDate(date, inSameDayAs: day)
        let holiday = AcademicCalendarStore.isDayOff(date, year: year)
        let today = CampusDate.calendar.isDateInToday(date)
        return Button { day = date; Haptics.selection() } label: {
            Text(String(CampusDate.calendar.component(.day, from: date)))
                .font(.body.weight(selected || today ? .bold : .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(holiday ? Color(uiColor: .systemRed) : selected || today ? Theme.accent : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    GeometryReader { proxy in
                        let size = min(proxy.size.width, proxy.size.height) - 2
                        Circle().fill(holiday ? Color(uiColor: .systemRed).opacity(0.16) : selected ? Theme.accent.opacity(0.12) : .clear)
                            .overlay { Circle().strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2) }
                            .frame(width: size, height: size).position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    }
                }
                .overlay(alignment: .bottom) {
                    if examDates.contains(CampusDate.key(date)) {
                        Capsule().fill(Theme.accent).frame(width: 14, height: 3).padding(.bottom, 3).accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(CampusDate.display(date, weekday: true))
            .accessibilityValue([holiday ? L10n.tr("放假") : "", examDates.contains(CampusDate.key(date)) ? L10n.tr("考试安排") : ""].filter { !$0.isEmpty }.joined(separator: " · "))
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
    private func selectMonth(_ date: Date) {
        guard date != shown, months.contains(date) else { return }
        month = date
        Haptics.selection()
    }
    private func move(_ offset: Int) {
        guard let next = CampusDate.calendar.date(byAdding: .month, value: offset, to: shown) else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { selectMonth(next) }
    }
}
