import SwiftUI
import CoreData

struct FavoritesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openURL) private var openURL
    private let contactService: ContactService = DefaultContactService.shared
    
    @FetchRequest(
        entity: Funcionario.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Funcionario.nome, ascending: true)],
        predicate: NSPredicate(format: "favorito == YES")
    ) private var favoritos: FetchedResults<Funcionario>
    
    @FetchRequest(
        entity: Municipio.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Municipio.nome, ascending: true)],
        predicate: NSPredicate(format: "favorito == YES")
    ) private var municipiosFavoritos: FetchedResults<Municipio>
    
    @State private var selectedSegment: Segment = .employees
    @State private var funcionarioSelecionado: Funcionario? = nil
    @AppStorage("app_zoom_scale") private var persistedZoom: Double = 1.35
    
    private enum Segment: String, CaseIterable, Identifiable {
        case employees = "Funcionarios"
        case municipios = "Municipios"
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: Picker fixo no topo
            Picker("Segment", selection: $selectedSegment) {
                Text(Segment.employees.rawValue).tag(Segment.employees)
                Text(Segment.municipios.rawValue).tag(Segment.municipios)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .background(Color(.systemGroupedBackground))
            .zIndex(2)
            
            // MARK: Conteúdo Scroll + Zoom
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: selectedSegment == .municipios ? 14 : 10) {
                    
                    // MARK: Funcionários Favoritos
                    if selectedSegment == .employees {
                        if favoritos.isEmpty {
                            emptyState(
                                title: "Sem favoritos",
                                description: "Adicione servidores como favoritos para vê-los aqui."
                            )
                        } else {
                            ForEach(favoritos, id: \.objectID) { f in
                                cardFuncionario(f)
                            }
                        }
                        
                    // MARK: Municípios Favoritos
                    } else {
                        if municipiosFavoritos.isEmpty {
                            emptyState(
                                title: "Sem municípios favoritos",
                                description: "Adicione municípios como favoritos para vê-los aqui."
                            )
                        } else {
                            ForEach(municipiosFavoritos, id: \.objectID) { m in
                                cardMunicipio(m)
                            }
                        }
                    }
                }
                .padding(.vertical, 0)
                .padding(.horizontal, 12)
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle("Favoritos")
        .navigationBarTitleDisplayMode(.inline)
        
        // MARK: Toolbar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if (selectedSegment == .employees && !favoritos.isEmpty)
                    || (selectedSegment == .municipios && !municipiosFavoritos.isEmpty) {
                    Button("Limpar") {
                        if selectedSegment == .employees {
                            removeAllFavorites()
                        } else {
                            removeAllFavoritesMunicipios()
                        }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ZoomMenuButton(persistedZoom: $persistedZoom)
            }
        }
        
        // MARK: Sheet de edição
        .sheet(item: $funcionarioSelecionado) { funcionario in
            NavigationView {
                FuncionarioFormView(
                    regional: funcionario.regional ?? "",
                    funcionario: funcionario,
                    isEditando: true
                )
            }
        }
        
        // MARK: 🔥 Sincronização Core Data → Firestore
        .onReceive(
            NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
                .receive(on: RunLoop.main)
        ) { notification in
            handleCoreDataSaveUpload(notification)
        }
    }
    
    // MARK: - Empty State
    private func emptyState(title: String, description: String) -> some View {
        VStack(spacing: 10) {
            ContentUnavailableView(
                title,
                systemImage: "star",
                description: Text(description)
            )
            Spacer(minLength: 400)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    // MARK: - Card Funcionário
    private func cardFuncionario(_ f: Funcionario) -> some View {
        HStack(spacing: 8) {
            NavigationLink(destination: FuncionarioDetailView(funcionario: f)) {
                FuncionarioRowViewV2(funcionario: f, showsFavorite: false)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                funcionarioSelecionado = f
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Editar funcionário")

            favoriteButton(for: f)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 0.5))
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: 528)
    }
    
    // MARK: - Card Município
    private func cardMunicipio(_ m: Municipio) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(m.nome ?? "—")
                    .font(.system(size: 26, weight: .bold))
                Text(m.regional ?? "—")
                    .font(.system(size: 23, weight: .bold))
            }
            Spacer()
            
            Button {
                withAnimation {
                    m.favorito.toggle()
                    save()
                    NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
                }
            } label: {
                Image(systemName: m.favorito ? "star.fill" : "star")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(m.favorito ? .yellow : .gray)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(.systemBackground)))
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .frame(maxWidth: 528)
    }
    
    
    // MARK: - Favoritos
    private func removeAllFavorites() {
        for f in favoritos { f.favorito = false }
        save()
        NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
    }

    private func toggleFavorite(_ funcionario: Funcionario) {
        funcionario.favorito.toggle()

        do {
            try viewContext.save()
            NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
            FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: viewContext) { result in
                switch result {
                case .success:
                    print("[Favorites] Favorito atualizado no Firestore")
                case .failure(let error):
                    print("[Favorites] Erro ao atualizar favorito: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Erro ao salvar favorito: \(error.localizedDescription)")
        }
    }

    private func favoriteButton(for funcionario: Funcionario) -> some View {
        Button {
            withAnimation { toggleFavorite(funcionario) }
        } label: {
            Image(systemName: funcionario.favorito ? "star.fill" : "star")
                .foregroundColor(funcionario.favorito ? .yellow : .gray)
                .frame(width: 36, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(funcionario.favorito ? "Remover dos favoritos" : "Adicionar aos favoritos")
    }
    
    private func removeAllFavoritesMunicipios() {
        for m in municipiosFavoritos { m.favorito = false }
        save()
        NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
    }
    
    // MARK: Persistência local
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Erro ao salvar favoritos: \(error.localizedDescription)")
        }
    }
    
    // MARK: 🔥 Sincronização Core Data → Firestore
    private func handleCoreDataSaveUpload(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let inserted = (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
        let updated = (userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []
        let changed = inserted.union(updated)
        
        for obj in changed where obj is Funcionario {
            FirestoreMigrator.uploadFuncionario(objectID: obj.objectID, context: viewContext) { result in
                switch result {
                case .success:
                    print("[Favorites Sync] Upload OK: \(obj.objectID)")
                case .failure(let error):
                    print("[Favorites Sync] Upload ERRO: \(error.localizedDescription)")
                }
            }
        }
    }
}


// MARK: - Notifications
extension NSNotification.Name {
    static let funcionarioAtualizado = NSNotification.Name("funcionarioAtualizado")
}

