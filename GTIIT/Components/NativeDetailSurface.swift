import SwiftUI

/// Shared appearance for pushed native details. Owns no navigation stack,
/// padding, toolbar or dismissal, so callers keep their current entry/return path.
extension View {
    func nativeDetailSurface(title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .nativeNavigationSurface()
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
    }
}
