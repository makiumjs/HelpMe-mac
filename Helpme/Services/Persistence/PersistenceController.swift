import Foundation
import SwiftData

/// Punto unico di accesso all'archivio SwiftData.
///
/// L'archivio resta sul dispositivo: contiene dati personali e sanitari
/// di minori e non viene sincronizzato su iCloud.
@MainActor
public final class PersistenceController {

    public static let shared = PersistenceController()

    public let container: ModelContainer

    /// Archivio su disco, in Application Support.
    private init() {
        let schema = Schema([StudentProfile.self, GloLogEntry.self, SchoolInfo.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Se l'archivio è illeggibile (disco pieno, migrazione fallita) l'app
            // riparte in memoria: il docente può lavorare, ma va avvisato.
            PersistenceController.storeLoadFailure = error
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                )
            } catch {
                fatalError("Impossibile inizializzare l'archivio dati: \(error)")
            }
        }
    }

    /// Archivio in memoria, per i test.
    public init(inMemory: Bool) {
        let schema = Schema([StudentProfile.self, GloLogEntry.self, SchoolInfo.self])
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)]
            )
        } catch {
            fatalError("Impossibile inizializzare l'archivio dati di test: \(error)")
        }
    }

    /// Valorizzato se l'archivio su disco non si è aperto e si sta lavorando in memoria.
    public private(set) static var storeLoadFailure: Error?

    public var isRunningInMemoryFallback: Bool {
        PersistenceController.storeLoadFailure != nil
    }

    // MARK: - Intestazione scuola

    /// Recupera l'unica intestazione salvata, creandola coi valori di default
    /// al primo avvio.
    public static func loadOrCreateSchoolInfo(in context: ModelContext) -> SchoolInfo {
        let descriptor = FetchDescriptor<SchoolInfo>()
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            return first
        }
        let fresh = SchoolInfo()
        context.insert(fresh)
        try? context.save()
        return fresh
    }
}
