import SwiftUI

/// 「预约」一级 Tab：一个 Tab 里放两套官方预约系统。
/// 场所切换放在导航栏左侧，避免覆盖在网页内容上方。
struct BookingTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel

    var body: some View {
        SiteBrowserView(site: app.bookingSegment == .rooms ? .rooms : .sports)
    }
}