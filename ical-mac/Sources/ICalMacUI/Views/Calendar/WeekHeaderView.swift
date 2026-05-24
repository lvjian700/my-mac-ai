import SwiftUI

#if DEBUG
#Preview {
    WeekHeaderView()
        .environmentObject(AppModel.preview())
        .padding()
        .frame(width: 760, height: 120)
}

#Preview("Navigation Button") {
    CalendarNavIconButton(systemImage: "chevron.right", accessibilityLabel: "Next Week") {}
        .padding()
}
#endif

struct WeekHeaderView: View {
    @EnvironmentObject private var model: AppModel

    private let headerSpacing: CGFloat = 16
    private let minHeight: CGFloat = 66

    var body: some View {
        HStack(spacing: headerSpacing) {
            calendarTitle
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            navigationControls
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
    }

    private var calendarTitle: Text {
        Text(Self.monthFormatter.string(from: model.displayedWeekStartDate))
            .font(.system(size: 34, weight: .bold))
        + Text(" \(Self.yearFormatter.string(from: model.displayedWeekStartDate))")
            .font(.system(size: 34, weight: .regular))
    }

    private var navigationControls: some View {
        HStack(spacing: 6) {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            HStack(spacing: 4) {
                CalendarNavIconButton(systemImage: "chevron.left", accessibilityLabel: "Previous Week") {
                    Task { await model.moveDisplayedWeek(by: -1) }
                }

                Button {
                    Task { await model.showToday() }
                } label: {
                    Text("Today")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(height: 28)
                        .padding(.horizontal, 17)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Today")

                CalendarNavIconButton(systemImage: "chevron.right", accessibilityLabel: "Next Week") {
                    Task { await model.moveDisplayedWeek(by: 1) }
                }
            }
            .disabled(model.isRefreshing)
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}

struct CalendarNavIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
