import SwiftUI

/// Unobtrusive background-import status. Never takes input and fades when finished.
struct PreparationImportPill: View {
    let progress: PreparationImportProgress
    var body: some View {
        HStack(spacing: 6) {
            Text(progress.text).font(.system(size: 10).monospacedDigit()).lineLimit(1).foregroundStyle(
                progress.message == nil ? Color(white: 0.75) : Color.orange.opacity(0.85))
            if progress.message == nil {
                ProgressView(value: progress.fraction).progressViewStyle(.linear).frame(width: 60).tint(
                    PerformancePalette.cyan)
            }
        }.padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.white.opacity(0.07)))
            .allowsHitTesting(false).accessibilityElement(children: .ignore).accessibilityLabel(progress.text)
    }
}
