import SwiftUI
public struct BadgesModalView: View {
    public let completedSessions: Int
    public let settings: AccessibilitySettings
    public var onClose: () -> Void

    public init(
        completedSessions: Int,
        settings: AccessibilitySettings,
        onClose: @escaping () -> Void
    ) {
        self.completedSessions = completedSessions
        self.settings = settings
        self.onClose = onClose
    }

    private var earned: [FocusBadge] { FocusBadge.earned(afterSessions: completedSessions) }
    private var next: FocusBadge? { FocusBadge.next(afterSessions: completedSessions) }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(FocusBadge.catalog) { badge in
                        row(badge)
                    }
                }
                .padding(20)
            }
            if let next {
                Divider()
                nextGoal(next)
            }
        }
        .themedSurface(settings)
        .frame(minWidth: 400, idealWidth: 460, minHeight: 380, idealHeight: 500)
    }

    // MARK: - Intestazione

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rosette")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(settings.theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("I tuoi traguardi")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(settings.theme.text)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(settings.theme.text.opacity(0.65))
            }

            Spacer()
            Button("Chiudi", action: onClose)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var subtitle: String {
        switch completedSessions {
        case 0:  return "Nessuna sessione completata — il primo badge è a una sessione di distanza"
        case 1:  return "1 sessione completata · \(earned.count) badge su \(FocusBadge.catalog.count)"
        default: return "\(completedSessions) sessioni completate · \(earned.count) badge su \(FocusBadge.catalog.count)"
        }
    }

    // MARK: - Riga di un badge

    private func row(_ badge: FocusBadge) -> some View {
        let unlocked = completedSessions >= badge.requiredSessions

        return HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(unlocked ? settings.theme.accent.opacity(0.16) : settings.theme.text.opacity(0.07))
                    .frame(width: 46, height: 46)
                Image(systemName: unlocked ? badge.symbol : "lock.fill")
                    .font(.system(size: unlocked ? 20 : 16, weight: .semibold))
                    .foregroundStyle(unlocked ? settings.theme.accent : settings.theme.text.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(badge.title)
                    .font(settings.fontFamily.font(size: CGFloat(settings.fontSize) - 1, weight: .semibold))
                    .foregroundStyle(unlocked ? settings.theme.text : settings.theme.text.opacity(0.55))

                Text(unlocked ? badge.caption : "Si sblocca a \(badge.requiredSessions) sessioni completate.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(settings.theme.text.opacity(unlocked ? 0.7 : 0.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(settings.theme.accent)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(unlocked ? settings.theme.accent.opacity(0.06) : settings.theme.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(unlocked ? settings.theme.accent.opacity(0.35) : settings.theme.text.opacity(0.1), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            unlocked
            ? "\(badge.title), conquistato. \(badge.caption)"
            : "\(badge.title), ancora bloccato. Si sblocca a \(badge.requiredSessions) sessioni completate."
        )
    }

    // MARK: - Prossimo obiettivo

    private func nextGoal(_ badge: FocusBadge) -> some View {
        let missing = badge.requiredSessions - completedSessions
        return HStack(spacing: 10) {
            Image(systemName: "target")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(settings.theme.accent)

            Text(missing == 1
                 ? "Manca **una sola sessione** a «\(badge.title)»."
                 : "Mancano **\(missing) sessioni** a «\(badge.title)».")
                .font(.system(size: 12.5))
                .foregroundStyle(settings.theme.text)
            Spacer()
            ProgressView(
                value: Double(completedSessions),
                total: Double(max(1, badge.requiredSessions))
            )
            .tint(settings.theme.accent)
            .frame(width: 110)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prossimo traguardo: \(badge.title), mancano \(missing) sessioni")
    }
}
