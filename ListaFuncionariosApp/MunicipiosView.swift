import SwiftUI
internal import CoreData
import Combine

struct MunicipiosView: View {
    @StateObject private var viewModel: MunicipioViewModel
    @Environment(\.managedObjectContext) private var viewContext
    private let isFavoritesView: Bool
    
    @State private var filtroTexto: String = ""
    @State private var mostrandoBusca = false
    @State private var regionalSelecionada: String = ""
    @AppStorage("app_zoom_scale") private var persistedZoom: Double = 1.0
    
    @State private var mostrandoAnalytics = false

    private var analyticsData: [MunicipiosPorRegional] {
        AnalyticsAggregator.aggregateMunicipiosByRegional(municipiosFiltrados)
    }
    
    init(context: NSManagedObjectContext, isFavoritesView: Bool = false) {
        _viewModel = StateObject(wrappedValue: MunicipioViewModel(context: context))
        self.isFavoritesView = isFavoritesView
    }
    
    // MARK: - Filters
    var municipiosFiltrados: [Municipio] {
        let todos = viewModel.municipios
        let texto = filtroTexto
        let regional = regionalSelecionada
        
        if texto.isEmpty && regional.isEmpty { return todos }

        return todos.filter { municipio in
            let nome = municipio.nome ?? ""
            let reg = municipio.regional ?? ""
            let nomeMatch = texto.isEmpty || nome.localizedCaseInsensitiveContains(texto)
            let regMatch = regional.isEmpty || reg == regional
            return nomeMatch && regMatch
        }
    }
    
    var regionais: [String] {
        let raw = viewModel.municipios.compactMap { $0.regional }.filter { !$0.isEmpty }
        return Array(Set(raw)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            
            // 🔥 MUNICIPIOSVIEW AGORA É TOTALMENTE ZOOMÁVEL
            ZoomableScrollView4(minZoomScale: 0.5, maxZoomScale: 3.0) {
                
                VStack(alignment: .leading, spacing: 20) {
                    
                    if mostrandoBusca {
                        filtrosView
                    }
                    
                    listaMunicipiosView
                }
                // CANVAS GIGANTE: 5000 × 5000
                .frame(minWidth: 5000, minHeight: 5000, alignment: .topLeading)
                .padding(.top, 20)
                .padding(.leading, 20)
            }
            
            .navigationTitle("Municípios do Paraná")
            .toolbar {
                
                // 🔍 Busca + zoom botão (lado esquerdo)
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        ZoomMenuButton(persistedZoom: $persistedZoom)
                        Button {
                            withAnimation {
                                mostrandoBusca.toggle()
                                if !mostrandoBusca {
                                    filtroTexto = ""
                                    regionalSelecionada = ""
                                }
                            }
                        } label: {
                            Image(systemName: mostrandoBusca ? "xmark.circle.fill" : "magnifyingglass")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 📊 Gráfico no centro da toolbar
                ToolbarItem(placement: .principal) {
                    Button {
                        mostrandoAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            .onAppear {
                mostrandoBusca = true
                viewModel.popularMunicipiosSeNecessario()
                if isFavoritesView { persistedZoom = 0.25 }
            }
            
            .onReceive(NotificationCenter.default.publisher(
                for: .NSManagedObjectContextDidSave)
                .receive(on: RunLoop.main)
            ) { notification in
                guard let userInfo = notification.userInfo else { return }
                
                let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let changed = inserted.union(updated)
                
                for obj in changed where obj is Municipio {
                    FirestoreMigrator.uploadMunicipio(objectID: obj.objectID, context: viewContext) { result in
                        if case let .failure(error) = result {
                            print("[Sync] Failed to upload Municipio: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            .sheet(isPresented: $mostrandoAnalytics) {
                MunicipiosAnalyticsView(
                    data: analyticsData,
                    title: "Municípios por Regional",
                    xValue: \.regional,
                    yValue: \.count
                )
                .presentationDetents([.fraction(0.5), .large])
            }
        }
    }

    // MARK: - Subviews
    
    private var filtrosView: some View {
        VStack(spacing: 12) {
            TextField("Filtrar por nome do município...", text: $filtroTexto)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.blue, lineWidth: 2)
                )
            
            Picker("Filtro regionais", selection: $regionalSelecionada) {
                Text("TODAS AS REGIONAIS").tag("")
                ForEach(regionais, id: \.self, content: Text.init)
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(.background)
                )
        )
        .frame(maxWidth: 600)
    }
    
    
    private var listaMunicipiosView: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Municípios")
                    .font(.headline)
                Text("Regional do Paraná")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            
            VStack(spacing: 0) {
                ForEach(municipiosFiltrados, id: \.objectID) { municipio in
                    NavigationLink(destination: MunicipioDetailView(municipio: municipio)) {
                        MunicipioRow(municipio: municipio, viewContext: viewContext)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 700)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue, lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        )
    }
}


// MARK: - Linha

struct MunicipioRow: View {
    let municipio: Municipio
    let viewContext: NSManagedObjectContext

    init(
        municipio: Municipio,
        viewContext: NSManagedObjectContext
    ) {
        self.municipio = municipio
        self.viewContext = viewContext
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .center, spacing: 8) {
                Text(municipio.nome ?? "No name")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                if let regional = municipio.regional, !regional.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Text(regional)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Regional: \(regional)")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: 1)
        )
    }
}
// MARK: - BASIC ZOOMABLE SCROLLVIEW
struct ZoomableScrollView4<Content: View>: UIViewRepresentable {
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
