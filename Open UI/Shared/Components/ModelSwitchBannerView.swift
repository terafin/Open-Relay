import SwiftUI

/// A slim banner shown above the chat input field while the backend is
/// loading a different model (SGLang / vLLM model-switch in progress).
///
/// Visibility is driven entirely by `ChatViewModel.modelSwitchStatus`:
/// - `nil`                  → banner is hidden (zero-height, no layout impact)
/// - non-nil + isSwitching  → banner appears with model name + time estimate
///
/// The banner dismisses automatically once the switch completes (polling
/// detects `loading_model == nil`) or streaming ends (stopSwitchStatusPolling).
struct ModelSwitchBannerView: View {
    let status: ModelSwitchStatus
    @Environment(\.theme) private var theme

    // MARK: - Derived text

    private var modelLabel: String {
        status.loadingModel ?? status.activeModel ?? "model"
    }

    private var timeLabel: String? {
        if let remaining = status.remainingSeconds, remaining > 0 {
            let secs = Int(remaining.rounded())
            return "~\(secs)s left"
        }
        if let estimate = status.estimateSeconds, estimate > 0 {
            let secs = Int(estimate.rounded())
            return "~\(secs)s"
        }
        return nil
    }

    private var progressFraction: Double? {
        guard let p = status.progress, p > 0, p <= 1 else { return nil }
        return p
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Spinning indicator
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .tint(theme.brandPrimary)

            // Main label
            Group {
                Text("Loading ")
                    .foregroundStyle(theme.textSecondary)
                + Text(modelLabel)
                    .foregroundStyle(theme.textPrimary)
                    .fontWeight(.medium)
                + (timeLabel.map { Text("  \($0)").foregroundStyle(theme.textTertiary) } ?? Text(""))
            }
            .font(.system(size: 12))
            .lineLimit(1)

            Spacer(minLength: 0)

            // Optional progress bar
            if let fraction = progressFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(theme.brandPrimary)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(theme.surfaceContainer)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
