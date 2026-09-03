import SwiftUI
struct AdminConfigurationSection: View {
    @Bindable var appViewModel: AppViewModel
    @State private var passwordField: String = ""
    @State private var confirmField: String = ""
    @State private var licenseField: String = ""
    @State private var errorMessage: String?

    private var lock: AdminLock { appViewModel.adminLock }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Licenza della scuola", systemImage: "lock.shield.fill")
                .font(.caption)
                .bold()
            licenseStatus
            if !lock.isPasswordSet {
                firstRunSetup
            } else if lock.isUnlocked {
                unlockedPanel
            } else {
                lockedPanel
            }
        }
        .onDisappear {
            lock.lock()
        }
    }

    // MARK: - Licenza
    private var licenseStatus: some View {
        Label {
            Text(appViewModel.licenseState.summary)
                .font(.caption2)
                .foregroundStyle(appViewModel.licenseState.isHealthy ? .secondary : Color.red)
        } icon: {
            Image(systemName: appViewModel.licenseState.isHealthy ? "checkmark.seal" : "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(appViewModel.licenseState.isHealthy ? .secondary : Color.red)
        }
        .accessibilityLabel("Stato licenza: \(appViewModel.licenseState.summary)")
    }
    private var licenseEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Codice licenza")
                .font(.caption2)
                .bold()
            TextField("Incolla qui il codice ricevuto", text: $licenseField, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .font(.system(.caption2, design: .monospaced))
            Button("Attiva licenza") {
                let state = appViewModel.activate(licenseToken: licenseField)
                switch state {
                case .valid:
                    licenseField = ""
                    errorMessage = nil
                default:
                    errorMessage = state.summary
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.institutional)
            .disabled(licenseField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Primo avvio: nessuna password impostata su questa macchina
    private var firstRunSetup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Imposta una password amministratore per questa macchina. Servirà per inserire o cambiare il codice licenza.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            SecureField("Nuova password (min. \(AdminLock.minimumPasswordLength) caratteri)", text: $passwordField)
                .textFieldStyle(.roundedBorder)
            SecureField("Ripeti la password", text: $confirmField)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            Button("Imposta password") {
                guard passwordField == confirmField else {
                    errorMessage = "Le due password non coincidono."
                    return
                }
                do {
                    try lock.setInitialPassword(passwordField)
                    errorMessage = nil
                    passwordField = ""
                    confirmField = ""
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.institutional)
            .disabled(passwordField.isEmpty)
        }
    }

    // MARK: - Bloccato: serve la password per procedere

    private var lockedPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SecureField("Password amministratore", text: $passwordField)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(attemptUnlock)

                Button("Sblocca", action: attemptUnlock)
                    .buttonStyle(.bordered)
                    .disabled(passwordField.isEmpty || lock.state.isBlocked())
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func attemptUnlock() {
        do {
            try lock.unlock(passwordField)
            passwordField = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sbloccato: si può inserire o sostituire la licenza

    private var unlockedPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sbloccato", systemImage: "lock.open.fill")
                .font(.caption2)
                .foregroundStyle(.green)
            licenseEntry
            HStack {
                Spacer()
                Button("Blocca") {
                    lock.lock()
                }
                .buttonStyle(.bordered)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}
