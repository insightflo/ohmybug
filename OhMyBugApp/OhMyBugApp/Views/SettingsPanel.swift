import SwiftUI

struct SettingsPanel: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)

            Toggle("Auto-apply fixes", isOn: $settings.autoApplyFixes)
                .toggleStyle(.switch)
                .tint(Theme.accent)

            Toggle("Run build check", isOn: $settings.runBuildCheck)
                .toggleStyle(.switch)
                .tint(Theme.accent)

            Divider().overlay(Theme.border)

            HStack(spacing: 6) {
                Text("GLM AI Fix")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                Text("codegeex-4")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            SecureField("GLM API Key", text: $settings.glmAPIKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Theme.textPrimary)
    }
}
