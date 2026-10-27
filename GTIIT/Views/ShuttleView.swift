import SwiftUI

struct ShuttleView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var timetableDirection: ShuttleDirection?
    @State private var showReminders = false
    @State private var appeared = false

    @StateObject private var proximity = CampusLocationRecommendation()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        let _ = nativeLocale.identifier

        NavigationStack {
            ScrollViewReader { proxy in
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 0).id("shuttle.top")
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(L10n.tr("校园动态")).font(.caption2.weight(.semibold)).tracking(2)
                                    .foregroundStyle(Theme.accent)
                                Text(L10n.tr("Shuttle Bus时刻表")).font(.largeTitle.weight(.semibold)).tracking(-1)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            Spacer(minLength: 8)
                            Text(clock(context.date)).font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(L10n.format("北京时间 %@", String(describing: clock(context.date))))
                            Button { showReminders = true } label: {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(width: 36, height: 36)
                                    .background(Theme.orange.opacity(0.12), in: Circle())
                                    .foregroundStyle(Theme.orange)
                            }
                            .accessibilityLabel(L10n.tr("班车提醒"))
                        }
                        Text(L10n.tr("两座校园，轻松往返。"))
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, -12)

                        EqualHeightHStack(spacing: 12) {
                            ForEach(ShuttleDirection.allCases) { direction in
                                Button {
                                    settings.favoriteShuttleDirection = direction
                                    timetableDirection = direction
                                } label: {
                                    DepartureColumn(
                                        direction: direction, now: context.date,
                                        departures: ShuttleSchedule.upcoming(direction, after: context.date,
                                            teachingWeek: settings.shuttleTeachingWeek))
                                        .contentShape(Rectangle())
                                }.buttonStyle(CardPressStyle())
                                    .accessibilityHint(L10n.tr("查看此方向完整时刻表"))
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 10)

                        if let next = ShuttleSchedule.upcoming(
                            proximity.direction ?? settings.favoriteShuttleDirection, after: context.date,
                            teachingWeek: settings.shuttleTeachingWeek, limit: 1
                        ).first {
                            ShuttleLiveActivityCard(direction: proximity.direction ?? settings.favoriteShuttleDirection, departure: next, suggested: proximity.direction != nil)
                            if proximity.authorization == .notDetermined {
                                Button { proximity.activate(requestPermission: true) } label: {
                                    Label(L10n.tr("按位置推荐方向"), systemImage: "location")
                                }.font(.subheadline).buttonStyle(.borderless)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $settings.shuttleTeachingWeek) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.tr("教学周加班车")).font(.subheadline.weight(.semibold))
                                    Text(settings.shuttleTeachingWeek ? L10n.tr("显示 1 号车与当日 2 号车") : L10n.tr("仅显示每日 1 号车"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }

                        }.padding(18).cardBackground()

                        Button { timetableDirection = .southToNorth } label: {
                            HStack {
                                Label(L10n.tr("完整时刻表"), systemImage: "clock")
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.subheadline)
                            }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }.buttonStyle(CardPressStyle()).foregroundStyle(Theme.accent)

                        VStack(alignment: .leading, spacing: 10) {
                            Label(L10n.tr("19:30 后，南校区 9 号门关闭"), systemImage: "door.left.hand.closed")
                                .font(.footnote.weight(.medium)).foregroundStyle(Theme.orange)
                            Text(L10n.tr("关闭期间请使用其他校门进出。南行路线：北校区正门 → 南校区 2 号门 → 9 号门；北行路线相反。"))
                            Text(L10n.format("时刻表：%@", String(describing: ShuttleSchedule.effectiveLabel)))
                        }.font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
                }.background(Theme.pageBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $timetableDirection) { direction in ShuttleTimetableView(initialDirection: direction) }
            .sheet(isPresented: $showReminders) { ShuttleReminderSettingsView() }
            .onAppear {
                proximity.activate()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true }
            }
            .onDisappear { proximity.deactivate() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { proximity.activate() } else { proximity.deactivate() } }
            .onChange(of: app.tabReselectToken) { _, _ in
                guard app.tabReselectTarget == .shuttle else { return }
                withAnimation(PrimaryNavigationMotion.animation(reduceMotion: reduceMotion)) {
                    proxy.scrollTo("shuttle.top", anchor: .top)
                }
            }
            }
        }
    }
    private func clock(_ date: Date) -> String {
        let parts = ShuttleSchedule.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

private struct DepartureColumn: View {
    @Environment(\.locale) private var nativeLocale
    let direction: ShuttleDirection
    let now: Date
    let departures: [ShuttleDeparture]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    private var color: Color { direction == .southToNorth ? Theme.accent : Theme.orange }

    var body: some View {
        let _ = nativeLocale.identifier

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(direction.title).font(.headline)
            }.foregroundStyle(color)
            if let next = departures.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("距计划发车")).font(.caption).foregroundStyle(.secondary)
                    Text(next.countdown(from: now))
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                        .foregroundStyle(color)
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: next.countdown(from: now))
                    HStack(spacing: 4) {
                        Text(ShuttleSchedule.dayLabel(next.date, relativeTo: now))
                        Text(next.trip.time).monospacedDigit()
                    }.font(.subheadline.weight(.semibold))
                    Text(next.trip.serviceLabel).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "bus.fill").font(.title3)
                    Rectangle().frame(height: 1).opacity(0.25)
                    Image(systemName: "mappin.circle.fill").font(.body)
                }.foregroundStyle(color).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.format("%@出发", String(describing: direction.origin))).font(.caption.weight(.semibold))
                    Text(next.trip.route).font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if next.trip.gateClosed {
                        Text(L10n.tr("9 号门已关闭")).font(.caption2).foregroundStyle(Theme.orange)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.tr("随后班次")).font(.caption2).foregroundStyle(.secondary)
                    ForEach(Array(departures.dropFirst())) { departure in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(departure.trip.time).font(.subheadline.weight(.medium)).monospacedDigit()
                                if !ShuttleSchedule.calendar.isDate(departure.date, inSameDayAs: now) {
                                    Text(ShuttleSchedule.dayLabel(departure.date, relativeTo: now)).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(L10n.format("%@ 号", String(describing: departure.trip.bus))).font(.caption2).foregroundStyle(color)
                        }
                    }
                }
            } else {
                Text(L10n.tr("暂无班次")).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(stops: [
                            .init(color: color.opacity(scheme == .dark ? 0.26 : 0.18), location: 0),
                            .init(color: color.opacity(scheme == .dark ? 0.08 : 0.05), location: 0.48),
                            .init(color: color.opacity(0), location: 1)
                        ], startPoint: .top, endPoint: .bottom))
                }
        }
    }
}

enum ShuttleHighlightStyle: String, CaseIterable { case tonal, outline, timeBadge }

struct ShuttleTimetableView: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @State private var direction: ShuttleDirection
    private let highlightStyle: ShuttleHighlightStyle
    private let reviewDate: Date?
    init(initialDirection: ShuttleDirection = .southToNorth, highlightStyle: ShuttleHighlightStyle = .tonal, reviewDate: Date? = nil) {
        _direction = State(initialValue: initialDirection)
        self.highlightStyle = highlightStyle
        self.reviewDate = reviewDate
    }
    private var tint: Color { direction == .southToNorth ? Theme.accent : Theme.orange }

    var body: some View {
        let _ = nativeLocale.identifier
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.tr("行车方向"), selection: $direction) {
                    ForEach(ShuttleDirection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 12)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    timetable(now: reviewDate ?? context.date)
                }
            }
            .background(Theme.pageBackground)
            .navigationTitle(L10n.tr("班车时刻表")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.tr("完成")) { dismiss() } } }
        }.tint(Theme.accent)
    }

    private func timetable(now: Date) -> some View {
        let next = ShuttleSchedule.upcoming(direction, after: now, teachingWeek: settings.shuttleTeachingWeek, limit: 1).first
        let trips = ShuttleSchedule.trips.filter { $0.direction == direction }
        let previousID = next.flatMap { departure in
            trips.firstIndex(where: { $0.id == departure.trip.id }).map { trips[max(0, $0 - 1)].id }
        }
        return GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(direction.origin) → \(direction.destination)")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            ForEach(trips) { trip in
                                tripRow(trip, next: next, now: now)
                                    .id(trip.id)
                                if trip.id != ShuttleSchedule.trips.last(where: { $0.direction == direction })?.id {
                                    Divider().padding(.horizontal, 16)
                                }
                            }
                        }
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        Text(L10n.tr("1 号车每日运行；2 号车仅教学周在标注星期运行。19:30 后南校区 9 号门关闭。"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    // Keep one previous departure above the next trip, including near the end of the day.
                    .padding(.top, 16)
                    .padding(.bottom, max(20, viewport.size.height - 152))
                }
                .task(id: next?.id) {
                    await Task.yield()
                    guard !Task.isCancelled, let next else { return }
                    proxy.scrollTo(previousID ?? next.trip.id, anchor: .top)
                }
            }
        }
    }

    private func tripRow(_ trip: ShuttleTrip, next: ShuttleDeparture?, now: Date) -> some View {
        let highlighted = trip.id == next?.trip.id
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(trip.time).font(.title3.monospacedDigit().weight(highlighted ? .bold : .medium))
                    .padding(.horizontal, highlighted && highlightStyle == .timeBadge ? 10 : 0)
                    .padding(.vertical, highlighted && highlightStyle == .timeBadge ? 6 : 0)
                    .background(highlighted && highlightStyle == .timeBadge ? tint : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(highlighted && highlightStyle == .timeBadge ? Color(uiColor: .systemBackground) : (highlighted ? tint : .primary))
                Text(trip.daysLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                Text(L10n.format("%@ 号", String(trip.bus))).font(.subheadline.weight(.semibold))
                if highlighted, let next {
                    Text(CampusDate.calendar.isDate(next.date, inSameDayAs: now) ? L10n.tr("下一班") : L10n.format("下一班 · %@", ShuttleSchedule.dayLabel(next.date, relativeTo: now)))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(tint.opacity(0.10), in: Capsule())
                }
            }
        }
        .foregroundStyle(highlighted ? tint : .primary)
        .padding(16).frame(maxWidth: .infinity, minHeight: 76)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(highlightStyle == .tonal ? tint.opacity(0.09) : Color.clear)
                    .overlay {
                        if highlightStyle == .outline {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.38), lineWidth: 1)
                        }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(highlighted ? [.isSelected] : [])
    }
}



/// Keeps both departure cards at the height of the taller content.
private struct EqualHeightHStack: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let count = max(1, subviews.count)
        let width = proposal.width ?? 0
        let childWidth = max(0, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
        let height = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: childWidth, height: nil)).height
        }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let count = CGFloat(subviews.count)
        let childWidth = max(0, (bounds.width - spacing * (count - 1)) / count)
        var x = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: childWidth, height: bounds.height)
            )
            x += childWidth + spacing
        }
    }
}
