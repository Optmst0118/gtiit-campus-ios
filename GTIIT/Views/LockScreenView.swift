import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject private var lock: AppLockController

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(Theme.accent)

                Text("GTIIT 已锁定")
                    .font(.title3.weight(.semibold))

                Text("成绩、考勤与预约页面已隐藏。解锁后继续浏览官方网页。")
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
                            Image(systemName: "faceid")
                        }
                        Text(lock.isAuthenticating ? "正在验证…" : "使用\(lock.biometryLabel)解锁")
                    }
                    .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(lock.isAuthenticating)
            }
            .padding(32)
        }
        .task { await lock.unlock() }
    }
}
