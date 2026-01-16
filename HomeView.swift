import SwiftUI
import UIKit
internal import CoreData
#if canImport(FirebaseCore)
import FirebaseCore
#endif

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
    @AppStorage("app_zoom_scale") private var persistedZoom: Double = 1.0

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

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appZoomScale) private var appZoom

    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    ) private var municipios: FetchedResults<Municipio>

    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    ) private var funcionarios: FetchedResults<Funcionario>

    @State private var funcionario: Funcionario? = nil
    @State private var mostrandoSobreSECID = false
    @State private var mostrandoGraficoFuncionarios = false
    @State private var mostrandoGraficoMunicipios = false
    @State private var selectedRegional: String = ""
    @State private var exportURLs: [URL] = []
    @State private var showingCSVExport = false
    @State private var exportErrorMessage: String? = nil
    @AppStorage("app_zoom_scale") private var persistedZoom: Double = 1.0
    @StateObject var navState = AppNavigationState()

    let regionais = ["Filtrar lista por regional"]

    var body: some View {
        NavigationStack {
            Group {
                switch navState.screen {
                case .main:
                    ZoomableScrollView3(minZoomScale: 0.5, maxZoomScale: 3.0) {

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
                                    Text("Encontre informação sobre funcionários e municípios")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }

                                Button(action: { exportarTabelasCSV() }) {
                                    Label("Baixar tabelas (.csv)", systemImage: "tray.and.arrow.down")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(
                                            LinearGradient(colors: [Color.blue, Color.indigo],
                                                           startPoint: .topLeading,
                                                           endPoint: .bottomTrailing)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                                }
                                .accessibilityLabel("Baixar tabelas de funcionários e municípios em CSV")

                                // 🔹 Botão Adicionar Funcionário
                                Button(action: {
                                    selectedRegional = ""
                                    self.funcionario = criarFuncionarioVazio()
                                }) {
                                    HomeRow(icon: "person.badge.plus", color: .white, text: "Adicionar Funcionário")
                                }
                                .sheet(item: $funcionario) { funcionarioEmEdicao in
                                    NavigationView {
                                        FuncionarioFormView(
                                            regional: selectedRegional,
                                            funcionario: funcionarioEmEdicao,
                                            isEditando: false
                                        )
                                        .environment(\.managedObjectContext, viewContext)
                                    }
                                }

                                // 🔹 Buscar Servidor
                                NavigationLink(destination: PaginaGrandeView().appHeaderFooter()) {
                                    HomeRow(icon: "magnifyingglass.circle.fill", color: .blue, text: "Buscar Servidor")
                                }

                                // 🔹 Favoritos
                                NavigationLink(destination: PaginaGrandeView2().appHeaderFooter()) {
                                    HomeRow(icon: "star.fill", color: .yellow, text: "Favoritos")
                                }

                                // 🔹 Municípios
                                NavigationLink(destination: PaginaGrandeMunicipiosView().appHeaderFooter()) {
                                    HomeRow(icon: "map.fill", color: .orange, text: "Ver Municípios")
                                }

                                NavigationLink(destination: PaginaGrandeInfoView().appHeaderFooter()) {
                                    HomeRow(icon: "building.2.fill", color: .teal, text: "Informações das Regionais")
                                }

                                Spacer(minLength: 20)
                            }
                            .frame(maxWidth: 700)
                            .padding(.horizontal)
                        }
                        .frame(minWidth: 2500, minHeight: 2500, alignment: .topLeading)
                        .padding(.top, 20)
                        .padding(.leading, 20)

                    }

                case .detail(let funcionario):
                    FuncionarioDetailView(funcionario: funcionario)

                }
            }
            .navigationTitle("Regionais SECID")
            .navigationBarTitleDisplayMode(.inline)
            .appZoomScale(CGFloat(persistedZoom))
            .scaleEffect(persistedZoom)
            .animation(.easeInOut, value: persistedZoom)
            .sheet(isPresented: $showingCSVExport) {
                ActivityView(activityItems: exportURLs)
            }
            .alert("Falha ao exportar CSV",
                   isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { newValue in
                        if !newValue {
                            exportErrorMessage = nil
                        }
                    }
                   )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage ?? "Erro desconhecido.")
            }
            .toolbar {
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { mostrandoGraficoFuncionarios = true }) {
                        Label("Funcionários x Regionais", systemImage: "chart.bar.xaxis")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $mostrandoGraficoFuncionarios) {
                        FuncionariosPorRegionalChartView(funcionarios: Array(funcionarios))
                            .appHeaderFooter()
                            .appZoomControls()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { mostrandoGraficoMunicipios = true }) {
                        Label("Municípios x Regionais", systemImage: "chart.pie.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $mostrandoGraficoMunicipios) {
                        MunicipiosPorRegionalChartView(municipios: Array(municipios))
                            .appHeaderFooter()
                            .appZoomControls()
                    }
                }
            }
        }
        .task { @MainActor in
            // Run municipios migration on app start from HomeView
            #if canImport(FirebaseCore)
            if FirebaseApp.app() == nil {
                if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                    FirebaseApp.configure()
                }
            }
            #endif

            do {
                let migrated = try await FirestoreMigrator.migrateMunicipiosToFirestoreAsync(from: viewContext)
                print("[HomeView] Migrated municipios to Firestore on startup. Count: \(migrated)")
            } catch {
                print("[HomeView] Failed to migrate municipios on startup: \(error)")
            }

            do {
                let regionalCount = try await FirestoreMigrator.migrateRegionalInfotoFirestoreAsync(from: viewContext)
                print("[HomeView] Migrated regional info to Firestore on startup. Count: \(regionalCount)")
            } catch {
                print("[HomeView] Failed to migrate regional info on startup: \(error)")
            }

            FirestoreMigrator.schedulePostStartupSanitization(delaySeconds: 3)
        }
        .environmentObject(navState)
    }

    private func criarFuncionarioVazio() -> Funcionario? {
        guard viewContext.persistentStoreCoordinator != nil else { return nil }

        let funcionario = Funcionario(context: viewContext)
        funcionario.nome = ""
        funcionario.funcao = ""
        funcionario.celular = ""
        funcionario.email = ""
        funcionario.favorito = false
        funcionario.ramal = ""
        funcionario.regional = ""

        return funcionario
    }

    private func exportarTabelasCSV() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let funcionariosCSV = montarCSVFuncionarios(Array(funcionarios))
        let municipiosCSV = montarCSVMunicipios(Array(municipios))

        let tempDir = FileManager.default.temporaryDirectory
        let funcionariosURL = tempDir.appendingPathComponent("funcionarios_\(timestamp).csv")
        let municipiosURL = tempDir.appendingPathComponent("municipios_\(timestamp).csv")

        do {
            try funcionariosCSV.write(to: funcionariosURL, atomically: true, encoding: .utf8)
            try municipiosCSV.write(to: municipiosURL, atomically: true, encoding: .utf8)
            exportURLs = [funcionariosURL, municipiosURL]
            showingCSVExport = true
        } catch {
            exportErrorMessage = "Não foi possível salvar os arquivos CSV. \(error.localizedDescription)"
        }
    }

    private func montarCSVFuncionarios(_ funcionarios: [Funcionario]) -> String {
        let header = [
            "Nome",
            "Função",
            "Regional",
            "Ramal",
            "Celular",
            "Email",
            "Favorito"
        ]
        let rows = funcionarios.map { funcionario in
            [
                valorCSV(funcionario.nome),
                valorCSV(funcionario.funcao),
                valorCSV(funcionario.regional),
                valorCSV(funcionario.ramal),
                valorCSV(funcionario.celular),
                valorCSV(funcionario.email),
                funcionario.favorito ? "Sim" : "Não"
            ].joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + rows).joined(separator: "\n")
    }

    private func montarCSVMunicipios(_ municipios: [Municipio]) -> String {
        let header = [
            "Município",
            "Regional",
            "Favorito",
            "UUID"
        ]
        let rows = municipios.map { municipio in
            let uuidString = (municipio.id as? UUID)?.uuidString
                ?? ((municipio.id as? NSUUID).map { ($0 as UUID).uuidString } ?? "")
            return [
                valorCSV(municipio.nome),
                valorCSV(municipio.regional),
                municipio.favorito ? "Sim" : "Não",
                valorCSV(uuidString)
            ].joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + rows).joined(separator: "\n")
    }

    private func valorCSV(_ valor: String?) -> String {
        let raw = valor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return escaparCSV(raw)
    }

    private func escaparCSV(_ valor: String) -> String {
        var escaped = valor.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\r") || escaped.contains("\"") {
            escaped = "\"\(escaped)\""
        }
        return escaped
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

// MARK: - BASIC ZOOMABLE SCROLLVIEW
struct ZoomableScrollView3<Content: View>: UIViewRepresentable {
    var minZoomScale: CGFloat
    var maxZoomScale: CGFloat
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(host: UIHostingController(rootView: content()))
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = minZoomScale
        scrollView.maximumZoomScale = maxZoomScale
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bouncesZoom = true

        let hostView = context.coordinator.host.view!
        hostView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostView)

        NSLayoutConstraint.activate([
            hostView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Agora, quando searchText/regionalSelecionada mudam,
        // o SwiftUI recalcula `content()` e atualizamos o rootView:
        context.coordinator.host.rootView = content()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let host: UIHostingController<Content>

        init(host: UIHostingController<Content>) {
            self.host = host
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            host.view
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
