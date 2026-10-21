import SwiftUI

struct LockScreenView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var lock: AppLockController

    var body: some View {
        let _ = nativeLocale.identifier

        ZStack {
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 46, weight: .light))
                            .foregroundStyle(Theme.accent)

                        Text(L10n.tr("GTIIT 已锁定"))
                            .font(.title3.weight(.semibold))

                        Text(L10n.tr("成绩、考勤与预约页面已隐藏。解锁后继续浏览官方网页。"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let message = lock.lastMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await lock.unlock() }
                        } label: {
                            HStack(spacing: 8) {
                                if lock.isAuthenticating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "lock.open")
                                }
                                Text(lock.isAuthenticating ? L10n.tr("正在验证…") : L10n.format("使用%@解锁", String(describing: lock.biometryLabel)))
                            }
                            .frame(maxWidth: 260)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(lock.isAuthenticating)
                    }
                    .frame(maxWidth: 520)
                    .padding(32)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
        }
        .task { await lock.unlock() }
    }
}
