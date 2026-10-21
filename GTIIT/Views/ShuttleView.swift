import SwiftUI

struct ShuttleView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTimetable = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("CAMPUS IN MOTION").font(.caption2.weight(.semibold)).tracking(2)
                                    .foregroundStyle(Theme.accent)
                                Text("Shuttle Bus时刻表").font(.largeTitle.weight(.semibold)).tracking(-1)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            Spacer(minLength: 8)
                            Text(clock(context.date)).font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("北京时间 \(clock(context.date))")
                        }
                        Text("两座校园，轻松往返。")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, -12)

                        HStack(alignment: .top, spacing: 12) {
                            ForEach(ShuttleDirection.allCases) { direction in
                                DepartureColumn(
                                    direction: direction, now: context.date,
                                    departures: ShuttleSchedule.upcoming(direction, after: context.date,
                                        teachingWeek: settings.shuttleTeachingWeek))
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 10)

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $settings.shuttleTeachingWeek) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("教学周加班车").font(.subheadline.weight(.semibold))
                                    Text(settings.shuttleTeachingWeek ? "显示 1 号车与当日 2 号车" : "仅显示每日 1 号车")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text("教学周请手动确认；假期、调休请关闭。校方临时通知优先。")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.padding(18).cardBackground()

                        Button { showTimetable = true } label: {
                            HStack {
                                Label("完整时刻表", systemImage: "clock")
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.subheadline)
                            }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }.buttonStyle(.plain).foregroundStyle(Theme.accent)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("19:30 后，南校区 9 号门关闭", systemImage: "door.left.hand.closed")
                                .font(.footnote.weight(.medium)).foregroundStyle(Theme.orange)
                            Text("关闭期间请使用其他校门进出。南行路线：北校区正门 → 南校区 2 号门 → 9 号门；北行路线相反。")
                            Text("按计划发车时间倒计时，非车辆实时到站。时间均为北京时间。")
                            Text("时刻表：\(ShuttleSchedule.effectiveLabel)")
                        }.font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
                }.background(Theme.pageBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showTimetable) { ShuttleTimetableView() }
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true }
            }
        }
    }
    private func clock(_ date: Date) -> String {
        let parts = ShuttleSchedule.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

private struct DepartureColumn: View {
    let direction: ShuttleDirection
    let now: Date
    let departures: [ShuttleDeparture]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var color: Color { direction == .southToNorth ? Theme.accent : Theme.orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(direction.title).font(.headline)
            }.foregroundStyle(color)
            if let next = departures.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("距计划发车").font(.caption).foregroundStyle(.secondary)
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
                    Text("\(direction.origin)出发").font(.caption.weight(.semibold))
                    Text(next.trip.route).font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if next.trip.gateClosed {
                        Text("9 号门已关闭").font(.caption2).foregroundStyle(Theme.orange)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("随后班次").font(.caption2).foregroundStyle(.secondary)
                    ForEach(Array(departures.dropFirst())) { departure in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(departure.trip.time).font(.subheadline.weight(.medium)).monospacedDigit()
                                if !ShuttleSchedule.calendar.isDate(departure.date, inSameDayAs: now) {
                                    Text(ShuttleSchedule.dayLabel(departure.date, relativeTo: now)).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Text("\(departure.trip.bus) 号").font(.caption2).foregroundStyle(color)
                        }
                    }
                }
            } else {
                Text("暂无班次").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 22))
        .overlay(alignment: .top) {
            Capsule().fill(color).frame(width: 28, height: 3)
        }
    }
}

private struct ShuttleTimetableView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var direction = ShuttleDirection.southToNorth
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("行车方向", selection: $direction) {
                        ForEach(ShuttleDirection.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section {
                    ForEach(ShuttleSchedule.trips.filter { $0.direction == direction }) { trip in
                        HStack(spacing: 18) {
                            Text(trip.time).font(.title3.monospacedDigit().weight(.medium)).frame(width: 64, alignment: .leading)
                            Text("\(trip.bus) 号").font(.caption.weight(.semibold))
                                .foregroundStyle(trip.bus == 1 ? Theme.accent : Theme.orange)
                            Spacer()
                            Text(trip.daysLabel).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                } header: { Text("\(direction.origin) → \(direction.destination)") }
                footer: {
                    Text("1 号车每日运行；2 号车仅教学周在标注星期运行。同一时间的两行代表两辆车。19:30 后南校区 9 号门关闭，请使用其他校门。\n\(ShuttleSchedule.effectiveLabel)，以校方最新通知为准。")
                }
            }
            .navigationTitle("班车时刻表").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.tint(Theme.accent)
    }
}
