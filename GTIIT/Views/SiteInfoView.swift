import SwiftUI

struct SiteInfoView: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.dismiss) private var dismiss
    let site: SiteID
    var body: some View {
        let _ = nativeLocale.identifier

        NavigationStack {
            SiteDataView(site: site)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.tr("完成")) { dismiss() } } }
        }
    }
}
