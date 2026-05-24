import SwiftUI

#if DEBUG
#Preview {
    CalendarUnavailableView(
        title: "Calendar Access Needed",
        systemImage: "calendar.badge.exclamationmark",
        detail: "Grant Calendar access in System Settings."
    )
    .frame(width: 640, height: 420)
}
#endif

struct CalendarUnavailableView: View {
    let title: String
    let systemImage: String
    let detail: String
    @Environment(\.readingTextMetrics) private var textMetrics

    private var topSpacer: CGFloat { textMetrics.layoutValue(80) }

    var body: some View {
        VStack {
            Spacer(minLength: topSpacer)

            ContentUnavailableView {
                Label(title, systemImage: systemImage)
                    .font(textMetrics.font(.title3, weight: .semibold))
            } description: {
                Text(detail)
                    .font(textMetrics.font(.body))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
