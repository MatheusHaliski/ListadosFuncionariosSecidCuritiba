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

final class AppDelegate: NSObject, UIApplicationDelegate {

    // Instância CORRETA, não um array
    var funcionarioViewModel: FuncionarioViewModel!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Inicializa o Core Data antes de qualquer ViewModel
        let context = PersistenceController.shared.container.viewContext

        // Agora cria o ViewModel corretamente
        self.funcionarioViewModel = FuncionarioViewModel(context: context)

        // -----------------------------------------------------------
        // 🔥 APP CHECK DEBUG MODE (ATIVAR ANTES DO FIREBASE CONFIGURE)
        // -----------------------------------------------------------
        #if DEBUG
        #if canImport(FirebaseAppCheck)
        print("[AppCheck] DEBUG MODE ENABLED")
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        print("[AppCheck] FirebaseAppCheck not available; skipping AppCheck debug setup.")
        #endif
        // Agora você consegue chamar isto SEM CRASH:
        funcionarioViewModel.resetToDefaultMode()
        print("[Launch] resetToDefaultMode() executed")
        #endif
        // -----------------------------------------------------------

        // Inicializa Firebase (apenas se FirebaseCore estiver disponível)
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            print("[Firebase] FirebaseApp.configure() called.")
        } else {
            print("[Firebase] GoogleService-Info.plist not found.")
        }
        #else
        print("[Firebase] FirebaseCore not available; skipping FirebaseApp.configure().")
        #endif
        AppDataResetter.resetForXcodeBuildIfNeeded(context: context)
        return true
    }
}


func isRunningFromXcode() -> Bool {
    return isatty(STDOUT_FILENO) != 0 || getenv("XCODE_RUNNING_FOR_PREVIEWS") != nil
}

@main
struct ListaFuncionariosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared

    @StateObject private var funcionarioVM = FuncionarioViewModel(
        context: PersistenceController.shared.container.viewContext
    )
    @StateObject private var zoomManager = ZoomManager()

    init() {
        // Estilo do app
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
                // Ensure file protection is applied as a side-effect during app launch
                SecurityConfigurator.applyFileProtection()
                let context = persistenceController.container.viewContext

                // If running from Xcode (debug/dev), wipe Firestore employees and local Core Data to avoid duplicates between runs
                #if DEBUG
                if isRunningFromXcode() {
                    #if canImport(FirebaseCore)
                    if FirebaseApp.app() == nil {
                        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                            FirebaseApp.configure()
                        }
                    }
                    if FirebaseApp.app() != nil {
                        do {
                            await FirestoreMigrator.wipeFuncionariosInFirestore()
                            let context = persistenceController.container.viewContext
                            let migratedCount = try await FirestoreMigrator.migrateFuncionariosToFirestoreAsync(from: context)
                            print("[Wipe] Migrated funcionarios to Firestore (debug run). Count: \(migratedCount)")
                        } catch {
                            print("[Wipe] Error during Firestore wipe/migrate: \(error)")
                        }
                    } else {
                        print("[Wipe] Skipping Firestore wipe: Firebase not configured.")
                    }
                    #else
                    print("[Wipe] FirebaseCore not available; skipping Firestore wipe.")
                    #endif

                    // Also wipe local Core Data funcionarios
                    let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Funcionario")
                    let deleteReq = NSBatchDeleteRequest(fetchRequest: fetch)
                    do {
                        try context.execute(deleteReq)
                        try context.save()
                        print("[Wipe] Local Core Data funcionarios wiped.")
                    } catch {
                        print("[Wipe] Failed to wipe local Core Data funcionarios: \(error)")
                    }
                }
                #endif

                // One-time automatic migration guard using UserDefaults
                let didMigrateKey = "didMigrateFuncionariosToFirestore"
                #if canImport(FirebaseCore)
                if UserDefaults.standard.bool(forKey: didMigrateKey) == false {
                    if FirebaseApp.app() != nil {
                        let context = persistenceController.container.viewContext
                        print("[Migration] Auto-migration started (first launch) -> 'employees'.")
                        FirestoreMigrator.migrateFuncionariosToFirestore(from: context) { result in
                            switch result {
                            case .success(let count):
                                print("[Migration] Auto-migration completed. Migrated: \(count)")
                                UserDefaults.standard.set(true, forKey: didMigrateKey)
                            case .failure(let error):
                                print("[Migration] Auto-migration failed: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        print("[Migration] Skipping auto-migration: Firebase not configured.")
                    }
                } else {
                    print("[Migration] Auto-migration already performed previously. Skipping.")
                }
                #else
                print("[Migration] FirebaseCore not available; skipping auto-migration.")
                #endif

                // After ensuring Firebase is configured, sync Firestore -> Core Data so UI reflects latest remote data on launch
                #if canImport(FirebaseCore)
                if FirebaseApp.app() != nil {
                    let context = persistenceController.container.viewContext
                    FirestoreMigrator.syncFromFirestoreToCoreData(context: context) { result in
                        switch result {
                        case .success(let updated):
                            print("[Sync] Firestore -> Core Data completed. Updated/created employees: \(updated)")
                        case .failure(let error):
                            print("[Sync] Firestore -> Core Data failed: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("[Sync] Skipping Firestore -> Core Data: Firebase not configured.")
                }
                #else
                print("[Sync] FirebaseCore not available; skipping Firestore -> Core Data sync.")
                #endif
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(funcionarioVM)
            .accentColor(.accentColor)
            .modifier(AppThemeModifier())
            .environmentObject(zoomManager)
        }
    }
}
