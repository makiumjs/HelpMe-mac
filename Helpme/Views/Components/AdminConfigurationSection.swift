import SwiftUI

/// Il pannello di configurazione IA, riservato a chi installa l'app.
///
/// Tre stati: nessuna password impostata ancora (primo avvio, su questa
/// macchina), bloccato (serve la password per vedere/cambiare la chiave), e
/// sbloccato (si vede l'indizio della chiave e si può sostituirla o
/// toglierla). Il blocco si richiude da solo quando il pannello scompare:
/// lasciarlo aperto dopo che l'amministratore se n'è andato vanificherebbe
/// tutto il resto.
struct AdminConfigurationSection: View {
    @Bindable var appViewModel: AppViewModel

    @State private var passwordField: String = ""
    @State private var confirmField: String = ""
    @State private var newKeyField: String = ""
    @State private var licenseField: String = ""
    @State private var errorMessage: String?

    private var lock: AdminLock { appViewModel.adminLock }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Configurazione IA", systemImage: "lock.shield.fill")
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
            // Il pannello si è chiuso: lo sblocco non deve sopravvivergli.
            lock.lock()
        }
    }

    // MARK: - Licenza

    /// Lo stato si legge senza sbloccare: un docente che si trova la
    /// generazione ferma deve poter capire perché, e poterlo riferire, senza
    /// avere la password di chi ha installato l'app.
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

    /// Inserirla resta dietro il lucchetto: la licenza la mette chi installa.
    private var licenseEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

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
            .buttonStyle(.bordered)
            .disabled(licenseField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Primo avvio: nessuna password impostata su questa macchina

    private var firstRunSetup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Imposta una password amministratore per questa macchina. Servirà per configurare o cambiare la chiave IA.")
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
            if let hint = appViewModel.geminiApiKeyHint {
                Text("Chiave configurata: \(hint)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nessuna chiave configurata.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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

    // MARK: - Sbloccato: si può leggere l'indizio e cambiare la chiave

    private var unlockedPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Sbloccato", systemImage: "lock.open.fill")
                .font(.caption2)
                .foregroundStyle(.green)

            if let hint = appViewModel.geminiApiKeyHint {
                Text("Chiave attuale: \(hint)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SecureField("Nuova API Key Gemini (lascia vuoto per non cambiare)", text: $newKeyField)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Salva chiave") {
                    do {
                        try appViewModel.setGeminiApiKey(newKeyField)
                        newKeyField = ""
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
                .disabled(newKeyField.trimmingCharacters(in: .whitespaces).isEmpty)

                if appViewModel.hasGeminiApiKey {
                    Button("Rimuovi chiave", role: .destructive) {
                        do {
                            try appViewModel.setGeminiApiKey("")
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Blocca") {
                    lock.lock()
                }
                .buttonStyle(.bordered)
            }

            licenseEntry

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}
