import SwiftUI
import OhMyBugCore

struct PhaseIndicator: View {
    let currentPhase: ScanPhase

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(ScanPhase.activePhases.enumerated()), id: \.element) { index, phase in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.textSecondary.opacity(0.5))
                }
                phaseLabel(phase)
            }
        }
    }

    private func phaseLabel(_ phase: ScanPhase) -> some View {
        let isCurrent = phase == currentPhase
        let isCompleted = phase.index < currentPhase.index

        return HStack(spacing: 3) {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.accent)
            }
            Text(phase.rawValue)
                .font(.system(size: 10, weight: isCurrent ? .bold : .medium, design: .monospaced))
        }
        .foregroundStyle(
            isCurrent ? Theme.accent :
            isCompleted ? Theme.accent.opacity(0.7) :
            Theme.textSecondary.opacity(0.4)
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            isCurrent
                ? Theme.accent.opacity(0.15)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
