import SwiftUI

/// 「预约」一级 Tab：一个 Tab 里放两套官方预约系统，
/// 顶部原生分段切换，网页本身保持原样。
struct BookingTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        SiteBrowserView(site: app.bookingSegment == .rooms ? .rooms : .sports)
    }
}

struct BookingSitePicker: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(spacing: 6) {
            if dynamicTypeSize.isAccessibilitySize {
                Menu {
                    Picker(L10n.tr("预约范围"), selection: $app.bookingSegment) {
                        ForEach(BookingSegment.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Label(app.bookingSegment.title, systemImage: "chevron.up.chevron.down")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                Picker(L10n.tr("预约范围"), selection: $app.bookingSegment) {
                    ForEach(BookingSegment.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }

        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .background(.bar)
    }
}
