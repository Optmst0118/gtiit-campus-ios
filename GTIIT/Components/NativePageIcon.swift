import SwiftUI

/// Shared leading icon used by native landing screens. The icon keeps the same
/// 58pt footprint and 20pt content alignment across Learning and Booking.
struct NativePageIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 58
    var corner: CGFloat = 17

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .accessibilityHidden(true)
    }
}
