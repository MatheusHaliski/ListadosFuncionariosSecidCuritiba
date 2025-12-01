//
//  AppDataResetter.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 01/12/25.
//


import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
internal import CoreData

/// Handles full data resets when building from Xcode.
///
/// The reset flow is:
/// 1. Detect if the app is running from an Xcode build (DEBUG + attached TTY/previews).
/// 2. Wipe both local Core Data (Funcionario & Municipio) and remote Firestore collections.
/// 3. Reseed defaults using the data embedded in `FuncionarioViewModel` and `MunicipioViewModel`.
///
/// This is intentionally aggressive and should only run during development builds.
enum AppDataResetter {

    @MainActor
    static func resetForXcodeBuildIfNeeded(context: NSManagedObjectContext) {
        #if DEBUG
        guard isRunningFromXcode() else {
            print("[Reset] Skipping reset: not running from Xcode.")
            return
        }

        Task {
            await performFullReset(context: context)
        }
        #else
        print("[Reset] Release build detected; reset skipped.")
        #endif
    }

    @MainActor
    private static func performFullReset(context: NSManagedObjectContext) async {
        do {
            let coreDataDeleted = try resetCoreData(context: context)
            seedDefaults(context: context)

            #if canImport(FirebaseCore)
            guard FirebaseApp.app() != nil else {
                print("[Reset] Firebase not configured; skipping Firestore reset.")
                return
            }

            #if canImport(FirebaseFirestore)
            try await FirestoreMigrator.deleteAllDocuments(in: "employees")
            try await FirestoreMigrator.deleteAllDocuments(in: "municipios")

            let funcionariosCount = try await FirestoreMigrator.migrateFuncionariosToFirestoreAsync(from: context)
            let municipiosCount = try await FirestoreMigrator.migrateMunicipiosToFirestoreAsync(from: context)

            print("[Reset] Core Data wiped (funcionarios: \(coreDataDeleted.funcionarios), municipios: \(coreDataDeleted.municipios)).")
            print("[Reset] Firestore re-seeded (employees: \(funcionariosCount), municipios: \(municipiosCount)).")
            #else
            print("[Reset] FirebaseFirestore not available; remote reset skipped.")
            #endif
            #else
            print("[Reset] FirebaseCore not available; remote reset skipped.")
            #endif
        } catch {
            print("[Reset] ❌ Failed to perform full reset: \(error)")
        }
    }

    @MainActor
    private static func resetCoreData(context: NSManagedObjectContext) throws -> (funcionarios: Int, municipios: Int) {
        let coordinator = context.persistentStoreCoordinator
        let funcionarioRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Funcionario")
        funcionarioRequest.includesPropertyValues = false

        let municipioRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Municipio")
        municipioRequest.includesPropertyValues = false

        let funcionarioDelete = NSBatchDeleteRequest(fetchRequest: funcionarioRequest)
        funcionarioDelete.resultType = .resultTypeCount

        let municipioDelete = NSBatchDeleteRequest(fetchRequest: municipioRequest)
        municipioDelete.resultType = .resultTypeCount

        var funcionariosDeleted = 0
        var municipiosDeleted = 0

        if let result = try coordinator?.execute(funcionarioDelete, with: context) as? NSBatchDeleteResult,
           let count = result.result as? Int {
            funcionariosDeleted = count
        }

        if let result = try coordinator?.execute(municipioDelete, with: context) as? NSBatchDeleteResult,
           let count = result.result as? Int {
            municipiosDeleted = count
        }

        try context.save()
        return (funcionariosDeleted, municipiosDeleted)
    }

    @MainActor
    private static func seedDefaults(context: NSManagedObjectContext) {
        let funcionarioVM = FuncionarioViewModel(context: context)
        funcionarioVM.popularNucleos(context: context)

        let municipioVM = MunicipioViewModel(context: context)
        municipioVM.popularMunicipiosSeNecessario()

        funcionarioVM.salvar()
        municipioVM.fetchMunicipios()
    }
}
