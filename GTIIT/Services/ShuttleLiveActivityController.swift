import ActivityKit
import Foundation
import UIKit

@MainActor final class ShuttleLiveActivityController: ObservableObject {
    static let shared = ShuttleLiveActivityController()
    @Published private(set) var activity: Activity<ShuttleActivityAttributes>?
    @Published var errorMessage: String?
    private var starting = false
    private var stateTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func restore(now: Date = Date()) async {
        let all = Activity<ShuttleActivityAttributes>.activities
        let valid = all.filter { $0.content.state.departureDate > now && $0.activityState != .ended && $0.activityState != .dismissed }
            .sorted { $0.content.state.departureDate < $1.content.state.departureDate }
        let keep = valid.first
        for item in all where item.id != keep?.id { await item.end(nil, dismissalPolicy: .immediate) }
        activity = keep
        observe()
    }
    func start(direction: ShuttleDirection, departure: ShuttleDeparture) async {
        guard !starting, isSupported, departure.date > Date() else { return }
        starting = true
        defer { starting = false }
        if let existing = Activity<ShuttleActivityAttributes>.activities.first(where: {
            $0.attributes.directionRaw == direction.rawValue && $0.content.state.departureDate == departure.date && $0.content.state.busNumber == departure.trip.bus && $0.attributes.languageCode == L10n.language.rawValue
        }) { activity = existing; await removeDuplicates(except: existing.id); observe(); return }
        await stop()
        let attributes = ShuttleActivityAttributes(directionTitle: direction.title, origin: direction.origin,
            destination: direction.destination, departureTime: departure.trip.time,
            busLabel: L10n.format("%@ 号车", String(departure.trip.bus)), directionRaw: direction.rawValue,
            languageCode: L10n.language.rawValue, departedLabel: L10n.tr("计划时间已过"))
        do {
            activity = try Activity.request(attributes: attributes,
                content: ActivityContent(state: .init(departureDate: departure.date, busNumber: departure.trip.bus), staleDate: departure.date), pushType: nil)
            errorMessage = nil; observe()
        } catch { errorMessage = L10n.tr("未能开启倒计时，请重试。") }
    }
    private func removeDuplicates(except id: String) async {
        for item in Activity<ShuttleActivityAttributes>.activities where item.id != id { await item.end(nil, dismissalPolicy: .immediate) }
    }
    func reconcile(direction: ShuttleDirection, teachingWeek: Bool) async {
        await restore()
        guard let current = activity else { return }
        let valid = ShuttleSchedule.departures(direction, on: current.content.state.departureDate, teachingWeek: teachingWeek)
            .contains { $0.date == current.content.state.departureDate && $0.trip.bus == current.content.state.busNumber }
        if !valid || current.attributes.directionRaw != direction.rawValue || current.attributes.languageCode != L10n.language.rawValue {
            guard UIApplication.shared.applicationState == .active,
                  let next = ShuttleSchedule.upcoming(direction, after: Date(), teachingWeek: teachingWeek, limit: 1).first else { await stop(); return }
            await start(direction: direction, departure: next)
        }
    }
    func stop() async {
        stateTask?.cancel(); expiryTask?.cancel()
        for item in Activity<ShuttleActivityAttributes>.activities { await item.end(nil, dismissalPolicy: .immediate) }
        activity = nil
    }
    private func observe() {
        stateTask?.cancel(); expiryTask?.cancel()
        guard let item = activity else { return }
        stateTask = Task { [weak self] in
            for await state in item.activityStateUpdates {
                guard !Task.isCancelled else { return }
                if state == .ended || state == .dismissed, self?.activity?.id == item.id { self?.activity = nil; return }
            }
        }
        expiryTask = Task { [weak self] in
            let delay = max(0, item.content.state.departureDate.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard self?.activity?.id == item.id else { return }
            await item.end(nil, dismissalPolicy: .immediate); self?.activity = nil
        }
    }
}
