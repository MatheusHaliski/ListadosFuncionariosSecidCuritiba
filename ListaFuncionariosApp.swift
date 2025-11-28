import SwiftUI
import Combine
import CoreData
import FirebaseCore
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
import FirebaseAppCheck  
import Darwin

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
        print("[AppCheck] DEBUG MODE ENABLED")
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())

        // Agora você consegue chamar isto SEM CRASH:
        funcionarioViewModel.resetToDefaultMode()
        print("[Launch] resetToDefaultMode() executed")
        #endif
        // -----------------------------------------------------------

        // Inicializa Firebase
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            print("[Firebase] FirebaseApp.configure() called.")
        } else {
            print("[Firebase] GoogleService-Info.plist not found.")
        }

        return true
    }
}


fileprivate func isRunningFromXcode() -> Bool {
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
            .task { SecurityConfigurator.applyFileProtection() }
            .task {
                // One-time automatic migration guard using UserDefaults
                let didMigrateKey = "didMigrateFuncionariosToFirestore"
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
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(funcionarioVM)
            .accentColor(.accentColor)
            .modifier(AppThemeModifier())
            .environmentObject(zoomManager)
        }
    }
}

