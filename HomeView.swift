import SwiftUI
internal import CoreData

// MARK: - Shared Zoom Environment
private struct AppZoomScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var appZoomScale: CGFloat {
        get { self[AppZoomScaleKey.self] }
        set { self[AppZoomScaleKey.self] = newValue }
    }
}

// MARK: - AppHeaderFooter ViewModifier
struct AppHeaderFooter: ViewModifier {
    @Environment(\.appZoomScale) private var appZoom

    func body(content: Content) -> some View {
        content
            .scaleEffect(appZoom)
            .animation(.easeInOut, value: appZoom)
    }
}

extension View {
    func appHeaderFooter() -> some View {
        modifier(AppHeaderFooter())
    }

    func appZoomScale(_ scale: CGFloat) -> some View {
        environment(\.appZoomScale, scale)
    }
}


// MARK: - Zoom Controls Modifier (top placement)
private struct ZoomControlsModifier: ViewModifier {
    @AppStorage("app_zoom_scale") private var persistedZoom: Double = 1.05

    func body(content: Content) -> some View {
        content
            .scaleEffect(persistedZoom)
            .animation(.default, value: persistedZoom)
            .appZoomScale(CGFloat(persistedZoom))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ZoomMenuButton(persistedZoom: $persistedZoom)
                }
            }
    }
}

extension View {
    func appZoomControls() -> some View {
        modifier(ZoomControlsModifier())
    }
}

// MARK: - Bidirectional Scroll Modifier
private struct BidirectionalScrollModifier: ViewModifier {
    func body(content: Content) -> some View {
        ScrollView([.vertical, .horizontal]) {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

extension View {
    func appBidirectionalScroll() -> some View {
        modifier(BidirectionalScrollModifier())
    }
}

// MARK: - HomeView
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appZoomScale) private var appZoom

    @State private var mostrandoFormulario = false
    @State private var mostrandoSobreSECID = false
    @State private var selectedRegional: String = ""
    @AppStorage("app_zoom_scale") private var persistedZoom: Double = 1.0
    @AppStorage("app_theme_preference") private var themePreference: String = "system"

    let regionais = ["Filtrar lista por regional"]

    private func colorSchemeFromPreference(_ value: String) -> ColorScheme? {
        switch value {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                VStack {
                    VStack(spacing: 20) {
                        // 🔹 Cabeçalho com logo
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(colors: [Color.white],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .overlay(
                                    Image("governo_parana")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                        .padding(.horizontal)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
                        }
                        .padding(.top, 8)

                        // 🔹 Título e subtítulo
                        VStack(spacing: 6) {
                            Text("Lista de Servidores do Estado do Paraná")
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            Text("Encontre informação sobre funcionários e municípios")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                        // 🔹 Botões principais
                        Button(action: {
                            selectedRegional = ""
                            mostrandoFormulario = true
                        }) {
                            HomeRow(icon: "person.badge.plus", color: .white, text: "Adicionar Funcionário")
                        }
                        .sheet(isPresented: $mostrandoFormulario) {
                            NavigationView {
                                FuncionarioFormView(
                                    regional: selectedRegional,
                                    funcionario: Funcionario(context: viewContext),
                                    isEditando: false
                                )
                                .environment(\.managedObjectContext, viewContext)
                            }
                        }

                        NavigationLink(destination: BuscarFuncionarioView().appHeaderFooter()) {
                            HomeRow(icon: "magnifyingglass.circle.fill", color: .blue, text: "Buscar Servidor")
                        }

                        NavigationLink(destination: FavoritesView().appHeaderFooter().appBidirectionalScroll()) {
                            HomeRow(icon: "star.fill", color: .yellow, text: "Favoritos")
                        }

                        NavigationLink(destination: MunicipiosView(context: viewContext).appHeaderFooter()) {
                            HomeRow(icon: "map.fill", color: .orange, text: "Ver Municípios")
                        }

                        Spacer(minLength: 20)
                    }
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                }
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Regionais SECID")
                .navigationBarTitleDisplayMode(.inline)
                .appZoomScale(CGFloat(persistedZoom))
                .scaleEffect(persistedZoom)
                .animation(.easeInOut, value: persistedZoom)
            }
            .toolbar {
                // 🔹 Botão "Sobre a SECID"
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { mostrandoSobreSECID = true }) {
                        Label("Sobre a SECID", systemImage: "info.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $mostrandoSobreSECID) {
                        SobreSECIDView().appHeaderFooter().appZoomControls()
                    }
                }

                // 🔹 Menu de tema
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Theme", selection: $themePreference) {
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Label("Theme", systemImage: "moon.circle")
                    }
                }

                #if DEBUG
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let context = PersistenceController.shared.container.viewContext
                        print("[Migration] Starting Core Data -> Firestore migration to 'employees' collection...")
                        FirestoreMigrator.migrateFuncionariosToFirestore(from: context) { result in
                            switch result {
                            case .success(let count):
                                print("[Migration] Completed successfully. Migrated documents: \(count)")
                            case .failure(let error):
                                print("[Migration] Failed with error: \(error.localizedDescription)")
                            }
                            FirestoreMigrator.migrateMunicipiosToFirestore(from: context) { muniResult in
                                switch muniResult {
                                case .success(let count):
                                    print("[Migration] Municipios migration completed. Migrated: \(count)")
                                case .failure(let error):
                                    print("[Migration] Municipios migration failed: \(error.localizedDescription)")
                                }
                            }
                        }
                    }) {
                        Label("Migrate to Firestore", systemImage: "arrow.up.doc")
                    }
                }
                #endif

                ToolbarItem(placement: .principal) {
                    ZoomMenuButton(persistedZoom: $persistedZoom)
                }
            }
        }
        // 🔹 Garante que o zoom é herdado por toda a NavigationView
        .preferredColorScheme(colorSchemeFromPreference(themePreference))
        .appZoomScale(CGFloat(persistedZoom))
    }
}

// MARK: - HomeRow
struct HomeRow: View {
    var icon: String
    var color: Color
    var text: String

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 32, alignment: .leading)
                Spacer()
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(text)
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 44)
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 16, alignment: .trailing)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                if color == .white {
                    LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else if color == .yellow {
                    LinearGradient(colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    LinearGradient(colors: [color, color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
