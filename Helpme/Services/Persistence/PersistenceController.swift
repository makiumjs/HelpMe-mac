import Foundation
import SwiftData
@MainActor
public final class PersistenceController {

    public static let shared = PersistenceController()
    public let container: ModelContainer
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
    public private(set) static var storeLoadFailure: Error?
    public var isRunningInMemoryFallback: Bool {
        PersistenceController.storeLoadFailure != nil
    }

    // MARK: - Intestazione scuola
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
