import SwiftUI
import Combine
internal import CoreData
import Darwin

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    var funcionarioViewModel: FuncionarioViewModel!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Core Data
        let context = PersistenceController.shared.container.viewContext
        self.funcionarioViewModel = FuncionarioViewModel(context: context)

        // -----------------------------------------------------------
        // 🔐 APP CHECK
        // Debug no Xcode / App Attest em TestFlight & App Store
        // -----------------------------------------------------------
        #if canImport(FirebaseAppCheck)
        #if DEBUG
        print("[AppCheck] DEBUG MODE ENABLED")
        print("[AppCheck] RELEASE MODE — DEBUG ENABLED")
        print("Devide ID is:", FirestoreMigrator.deviceID )
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        print("[AppCheck] RELEASE MODE — App Attest ENABLED")
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif
        #endif
        // -----------------------------------------------------------

        // -----------------------------------------------------------
        // 🔥 Firebase (configurar UMA ÚNICA VEZ)
        // -----------------------------------------------------------
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
                print("[Firebase] FirebaseApp.configure() called.")
            } else {
                print("[Firebase] GoogleService-Info.plist not found.")
            }
        }
        #endif
        // -----------------------------------------------------------

        return true
    }
}

// MARK: - Helpers

func isRunningFromXcode() -> Bool {
    return isatty(STDOUT_FILENO) != 0 || getenv("XCODE_RUNNING_FOR_PREVIEWS") != nil
}

// MARK: - Main App

@main
struct ListaFuncionariosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared

    @StateObject private var funcionarioVM = FuncionarioViewModel(
        context: PersistenceController.shared.container.viewContext
    )
    @StateObject private var zoomManager = ZoomManager()

    init() {
        // Estilo
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor(.accentColor)]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor(.accentColor)]

        // Core Data warm-up
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
        request.fetchLimit = 1
        _ = try? context.fetch(request)
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .centerFirstTextBaseline) {
                HomeView()
            }
            .task {
                SecurityConfigurator.applyFileProtection()
                let context = persistenceController.container.viewContext

                // -----------------------------------------------------------
                // 🧪 DEBUG: wipe/migrate only when running from Xcode
                // -----------------------------------------------------------
                #if DEBUG
                if isRunningFromXcode() {
                    #if canImport(FirebaseCore)
                    if FirebaseApp.app() != nil {
                        do {
                            await FirestoreMigrator.wipeFuncionariosInFirestore()

                            let migratedCount = try await FirestoreMigrator
                                .migrateFuncionariosToFirestoreAsync(from: context)

                            let didSyncMunicipiosKeyDebug = "didSyncMunicipiosOnLaunchDebug"
                            if !UserDefaults.standard.bool(forKey: didSyncMunicipiosKeyDebug) {
                                let syncedMunicipios = try await FirestoreMigrator.syncMunicipios(context: context)
                                print("[Wipe] Synced municipios (debug). Count: \(syncedMunicipios)")
                                UserDefaults.standard.set(true, forKey: didSyncMunicipiosKeyDebug)
                                let didSyncInfoRegionaisKeyDebug = "didSyncInfoRegionaisOnLaunchDebug"
                            }
                        } catch {
                            print("[Wipe] Error: \(error)")
                        }
                    }
                    #endif

                    // Wipe local Core Data
                    let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Funcionario")
                    let deleteReq = NSBatchDeleteRequest(fetchRequest: fetch)
                    do {
                        try context.execute(deleteReq)
                        try context.save()
                        print("[Wipe] Local Core Data funcionarios wiped.")
                    } catch {
                        print("[Wipe] Failed to wipe local Core Data: \(error)")
                    }
                }
                #endif
                // -----------------------------------------------------------

                // -----------------------------------------------------------
                // 🚀 One-time migration on first launch
                // -----------------------------------------------------------
                let didMigrateKey = "didMigrateFuncionariosToFirestore"
                #if canImport(FirebaseCore)
                if !UserDefaults.standard.bool(forKey: didMigrateKey),
                   FirebaseApp.app() != nil {

                    print("[Migration] Auto-migration started.")
                    FirestoreMigrator.migrateFuncionariosToFirestore(from: context) { result in
                        switch result {
                        case .success(let count):
                            print("[Migration] Completed. Migrated: \(count)")
                            UserDefaults.standard.set(true, forKey: didMigrateKey)
                        case .failure(let error):
                            print("[Migration] Failed: \(error.localizedDescription)")
                        }
                    }

                    let didSyncMunicipiosKey = "didSyncMunicipiosToFirestore"
                    if !UserDefaults.standard.bool(forKey: didSyncMunicipiosKey) {
                        Task {
                            do {
                                let count = try await FirestoreMigrator.syncMunicipios(context: context)
                                print("[Migration] Municipios synced: \(count)")
                                UserDefaults.standard.set(true, forKey: didSyncMunicipiosKey)
                                let didSyncInfoRegionaisKey = "didSyncInfoRegionaisOnLaunchDebug"
                                if !UserDefaults.standard.bool(forKey: didSyncInfoRegionaisKey) {
                                    let syncedInfoRegionais: Int = try await FirestoreMigrator.syncInfoRegionais(context: context)
                                    print("[Wipe] Synced info regionais (debug). Count: \(syncedInfoRegionais)")
                                    UserDefaults.standard.set(true, forKey: didSyncInfoRegionaisKey)
                                }
                            } catch {
                                print("[Migration] Municipios sync failed: \(error)")
                            }
                        }
                    }
                }
                #endif
                // -----------------------------------------------------------

                // -----------------------------------------------------------
                // 🔄 Sync Firestore → Core Data on launch
                // -----------------------------------------------------------
                #if canImport(FirebaseCore)
                if FirebaseApp.app() != nil {
                    FirestoreMigrator.syncFromFirestoreToCoreData(context: context) { result in
                        switch result {
                        case .success(let updated):
                            print("[Sync] Firestore → Core Data OK. Updated: \(updated)")
                        case .failure(let error):
                            print("[Sync] Firestore → Core Data failed: \(error.localizedDescription)")
                        }
                    }
                }
                #endif
                // -----------------------------------------------------------
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(funcionarioVM)
            .environmentObject(zoomManager)
            .accentColor(.accentColor)
            .modifier(AppThemeModifier())
        }
    }
}

