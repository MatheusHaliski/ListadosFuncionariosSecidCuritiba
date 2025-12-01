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
    // Analytics inline data derived from current filter
    private var analyticsData: [MunicipiosPorRegional] {
        AnalyticsAggregator.aggregateMunicipiosByRegional(municipiosFiltrados)
    }
    
    init(context: NSManagedObjectContext, isFavoritesView: Bool = false) {
        _viewModel = StateObject(wrappedValue: MunicipioViewModel(context: context))
        self.isFavoritesView = isFavoritesView
    }
    
    // MARK: - Filtros
    
    var municipiosFiltrados: [Municipio] {
        let todos: [Municipio] = viewModel.municipios
        let texto: String = filtroTexto
        let regional: String = regionalSelecionada

        if texto.isEmpty && regional.isEmpty {
            return todos
        }

        return todos.filter { (municipio: Municipio) -> Bool in
            let nomeDoMunicipio: String = municipio.nome ?? ""
            let regionalDoMunicipio: String = municipio.regional ?? ""

            let nomeMatch: Bool = texto.isEmpty || nomeDoMunicipio.localizedCaseInsensitiveContains(texto)
            let regionalMatch: Bool = regional.isEmpty || (regionalDoMunicipio == regional)
            return nomeMatch && regionalMatch
        }
    }
    
    var regionais: [String] {
        let municipios: [Municipio] = viewModel.municipios
        var regionaisRaw: [String] = []
        regionaisRaw.reserveCapacity(municipios.count)
        for m in municipios {
            if let r = m.regional, !r.isEmpty {
                regionaisRaw.append(r)
            }
        }
        let conjunto: Set<String> = Set<String>(regionaisRaw)
        let lista: [String] = Array(conjunto)
        let ordenada: [String] = lista.sorted { (a: String, b: String) -> Bool in
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        return ordenada
    }
    
    // MARK: - Corpo
    
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack {
                if mostrandoBusca {
                    filtrosView
                }
                
                ScrollView([.vertical, .horizontal]) {
                    listaMunicipiosView
                }
            }}
        .navigationTitle("Municípios do Paraná")
        .toolbar {
            // 🔍 Lado esquerdo
            ToolbarItem(placement: .topBarLeading) {
                HStack {
                    ZoomMenuButton(persistedZoom: $persistedZoom)
                    
                    Button(action: {
                        withAnimation {
                            mostrandoBusca.toggle()
                            if !mostrandoBusca {
                                filtroTexto = ""
                                regionalSelecionada = ""
                            }
                        }
                    }) {
                        Image(systemName: mostrandoBusca ? "xmark.circle.fill" : "magnifyingglass")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(mostrandoBusca ? "Close filter" : "Filter cities")
                }
            }
            
            // 📊 <-- Botão do gráfico VISÍVEL no lado direito
            ToolbarItem(placement: .principal) {
                Button {
                    mostrandoAnalytics = true
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Mostrar gráfico")
            }
        }
        .onAppear {
            mostrandoBusca = true
            viewModel.popularMunicipiosSeNecessario()
            if isFavoritesView {
                // Force zoom to approximately 25% when entering Favorites
                persistedZoom = 0.25
            }
        }
        .onReceive(NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
        ) { notification in
            guard let userInfo = notification.userInfo else { return }
            let inserted = (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
            let updated = (userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []
            let changed = inserted.union(updated)
            
            // Push Municipio changes immediately to Firestore
            for obj in changed where obj is Municipio {
                FirestoreMigrator.uploadMunicipio(objectID: obj.objectID, context: viewContext) { result in
                    switch result {
                    case .success:
                        print("[Sync] Municipio uploaded after save: \(obj.objectID)")
                    case .failure(let error):
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
            .presentationDragIndicator(.visible)
            .id(UUID())   // força reconstrução completa ao abrir
        }
    }
    
    // MARK: - Subviews
    
    private var filtrosView: some View {
        VStack {
            ScrollView([.vertical, .horizontal]) {
                TextField("Filtrar por nome do município...", text: $filtroTexto)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                ScrollView([.vertical, .horizontal]) {
                    Picker("Filtro regionais", selection: $regionalSelecionada) {
                        Text("TODAS AS REGIONAIS").tag("")
                        ForEach(regionais, id: \.self) { (regional: String) in
                            Text(regional).tag(regional)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                // Inline analytics chart below the segmented picker
                MunicipiosAnalyticsView(
                    data: analyticsData,
                    title: "Municípios por Regional",
                    xValue: \.regional,
                    yValue: \.count
                )
                .frame(height: 220)
                .padding(.top, 8)
            }
            .padding()
            .frame(width: 950)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
            )
            .padding(.vertical, 8)
        }}
    
    private var listaMunicipiosView: some View {
        VStack(spacing: 0) {
            // Cabeçalho
            VStack(alignment: .leading, spacing: 4) {
                Text("Municípios")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Regional do Paraná")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            
            // Linhas
            VStack(spacing: 0) {
                ForEach(municipiosFiltrados, id: \.objectID) { (municipio: Municipio) in
                    MunicipioRow(
                        municipio: municipio,
                        viewContext: viewContext,
                        onToggleFavorite: {
                            handleToggleFavorite(for: municipio)
                        }
                    )
                }
            }
        }
        .frame(width: 950)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
        )
        .padding(.vertical, 8)
    }
    
    // MARK: - Lógica de favorito + Firestore
    
    private func handleToggleFavorite(for municipio: Municipio) {
        withAnimation {
            // 1) Atualiza Core Data localmente
            municipio.favorito = !(municipio.favorito == true)
            do {
                try viewContext.save()
            } catch {
                print("❌ Erro ao salvar Core Data: \(error.localizedDescription)")
                return
            }
            
            // 2) Envia apenas este município para o Firestore
            FirestoreMigrator.uploadMunicipio(
                objectID: municipio.objectID,
                context: viewContext
            ) { result in
                switch result {
                case .success:
                    print("🔥 Município sincronizado imediatamente com Firestore!")
                case .failure(let error):
                    print("❌ Erro ao sincronizar município:", error.localizedDescription)
                }
                
                // 3) Atualiza lista local
                DispatchQueue.main.async {
                    viewModel.fetchMunicipios()
                }
            }
        }
    }
}

// MARK: - Linha

struct MunicipioRow: View {
    let municipio: Municipio
    let viewContext: NSManagedObjectContext
    let onToggleFavorite: () -> Void

    init(
        municipio: Municipio,
        viewContext: NSManagedObjectContext,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.municipio = municipio
        self.viewContext = viewContext
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(municipio.nome ?? "No name")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                
                if let regional = municipio.regional, !regional.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Text(regional)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Regional: \(regional)")
                }
            }
            
            Spacer(minLength: 8)
            
            Button(action: onToggleFavorite) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.6), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                        )
                    Image(systemName: ((municipio.favorito as NSNumber?)?.boolValue == true) ? "star.fill" : "star")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            ((municipio.favorito as NSNumber?)?.boolValue == true)
                            ? Color.red
                            : Color.gray
                        )
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.blue, lineWidth: 1)
        )
    }
}

