import SwiftUI

/// 「预约」一级 Tab：一个 Tab 里放两套官方预约系统，
/// 顶部原生分段切换，网页本身保持原样。
struct BookingTabView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            segmentBar
            switch app.bookingSegment {
            case .rooms:
                SiteBrowserView(site: .rooms)
            case .sports:
                SiteBrowserView(site: .sports)
            }
        }
    }

    private var segmentBar: some View {
        VStack(spacing: 6) {
            Picker("预约范围", selection: $app.bookingSegment) {
                ForEach(BookingSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)

            Text(app.bookingSegment.site.oneLineBoundary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .background(.bar)
    }
}