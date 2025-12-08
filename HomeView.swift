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
    @AppStorage("app_zoom_scale") private var persistedZoom: Double = 1.35

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

