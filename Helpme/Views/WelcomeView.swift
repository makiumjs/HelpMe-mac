import SwiftUI

public struct WelcomeView: View {

    private let onCreateStudent: () -> Void
    private let onConfigureSchool: () -> Void

    public init(onCreateStudent: @escaping () -> Void, onConfigureSchool: @escaping () -> Void) {
        self.onCreateStudent = onCreateStudent
        self.onConfigureSchool = onConfigureSchool
    }

    private var accent: Color { Color.institutional }

    public var body: some View {
        VStack(spacing: 26) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(accent)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Benvenuto in HelpMe")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text("Crea la prima scheda alunno per iniziare a generare verifiche equipollenti, formulari e materiali accessibili.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            VStack(spacing: 10) {
                Button(action: onCreateStudent) {
                    Label("Crea la prima scheda alunno", systemImage: "person.crop.circle.badge.plus")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .keyboardShortcut("n", modifiers: .command)

                Button(action: onConfigureSchool) {
                    Label("Configura l'intestazione della scuola", systemImage: "building.columns")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 7) {
                Label("I dati degli alunni restano su questo dispositivo.", systemImage: "lock.fill")
                Label("Verso l'IA vengono inviati solo dati anonimizzati: nome e diagnosi non escono dal Mac.", systemImage: "eye.slash.fill")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: 480, alignment: .leading)
            .background(accent.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
