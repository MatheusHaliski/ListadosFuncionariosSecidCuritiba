//
//  Persistence.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 01/08/25.
//

import CoreData
import SwiftUI

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // Use a local container to avoid capturing `self` in the escaping closure during init
        let container = NSPersistentCloudKitContainer(name: "ListaFuncionariosApp")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Load stores and perform post-load setup without capturing `self`
        container.loadPersistentStores { (_, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }

            let isPreviewOrInMemory: Bool = {
                #if DEBUG
                // Xcode canvas previews set this environment variable
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return true }
                #endif
                return inMemory
            }()

            if isPreviewOrInMemory {
                // Wipe existing Funcionario data and seed defaults on app initialization
                let viewContext = container.viewContext

                // Batch delete all Funcionario records
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Funcionario")
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs

                do {
                    let result = try container.persistentStoreCoordinator.execute(deleteRequest, with: viewContext) as? NSBatchDeleteResult
                    if let objectIDs = result?.result as? [NSManagedObjectID] {
                        let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
                    }
                } catch {
                    print("Erro ao apagar dados existentes de Funcionario: \(error)")
                }

                // Seed default data using the view model's populate helpers
                // Note: Images should be persisted via a Data attribute on Funcionario and handled in the view model
                let vm = FuncionarioViewModel(context: viewContext)
                vm.popularNucleos(context: viewContext)
            }
        }

        // Assign to the stored property only after configuration
        self.container = container
        self.container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
