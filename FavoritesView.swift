import SwiftUI
internal import CoreData
import Combine

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
    @State private var didSyncFromFirestore = false

    enum Segment: String, CaseIterable, Identifiable {
        case employees = "Funcionários"
        case municipios = "Municípios"
        var id: String { rawValue }
    }

    var body: some View {

        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            // A flexible container that can grow beyond the screen width to allow horizontal scroll
            VStack(alignment: .center, spacing: 0) {
                VStack(spacing: selectedSegment == .municipios ? 16 : 12) {

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
                // Removed .padding(.top, 60)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .frame(minWidth: 360) // ensure there's a base width for horizontal scroll
            }
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top) {
            StickyPickerBar(
                segment: $selectedSegment,
                employeeCount: favoritos.count,
                municipioCount: municipiosFavoritos.count
            )
            .padding(.top, 20)
            .padding(.horizontal, 12)
            .background(.bar)
        }

        .navigationTitle("Favoritos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)


        // 🟨 BOTTOM BAR – ZOOM CONTROL
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Spacer()
                    ZoomMenuButton(persistedZoom: $persistedZoom)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Capsule().fill(Color(.systemGray6)))
                    Spacer()
                }
            }
        }

        // FORM DE EDIÇÃO
        .sheet(item: $funcionarioSelecionado) { funcionario in
            NavigationStack {
                FuncionarioFormView(
                    regional: funcionario.regional ?? "",
                    funcionario: funcionario,
                    isEditando: true
                )
            }
        }

        // SYNC FIRESTORE
        .task {
            if !didSyncFromFirestore {
                didSyncFromFirestore = true
                let syncContext = PersistenceController.shared.makeBackgroundContext()
                FirestoreMigrator.syncFromFirestoreToCoreData(context: syncContext) { _ in }
            }
        }
    }

    // MARK: - EMPTY STATE
    private func emptyState(title: String, description: String) -> some View {
        VStack(spacing: 10) {
            ContentUnavailableView(
                title,
                systemImage: "star",
                description: Text(description)
            )
            Spacer(minLength: 200)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - CARD FUNCIONARIO
    private func cardFuncionario(_ f: Funcionario) -> some View {
        HStack(spacing: 8) {
            NavigationLink(destination: FuncionarioDetailView(funcionario: f)) {
                FuncionarioRowViewV2(funcionario: f, showsFavorite: false)
            }
            .buttonStyle(.plain)

            Button {
                funcionarioSelecionado = f
            } label: {
                Image(systemName: "pencil")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(width: 44, height: 44) // Control size
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.blue.opacity(0.6), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 0.5))
        .padding(.vertical, 6)
        .frame(width:500)
    }

    // MARK: - CARD MUNICIPIO
    private func cardMunicipio(_ m: Municipio) -> some View {
        NavigationLink(destination: MunicipioDetailView(municipio: m)) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.nome ?? "—")
                        .font(.system(size: 26, weight: .bold))
                    Text(m.regional ?? "—")
                        .font(.system(size: 23, weight: .bold))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
            .frame(maxWidth: .infinity)
            .frame(maxWidth: 528)
        }
        .buttonStyle(.plain)
    }

    // MARK: - REMOVE FAVORITOS
    private func removeAllFavorites() {
        favoritos.forEach { $0.favorito = false }
        save()
    }

    private func removeAllFavoritesMunicipios() {
        municipiosFavoritos.forEach { $0.favorito = false }
        save()
    }

    private func save() {
        do { try viewContext.save() }
        catch { print("Erro ao salvar: \(error.localizedDescription)") }
    }
}

struct StickyPickerBar: View {
    @Binding var segment: FavoritesView.Segment
    let employeeCount: Int
    let municipioCount: Int

    var body: some View {
        VStack(spacing: 10) {
            PillSegmentedControl(
                selection: $segment,
                employeeCount: employeeCount,
                municipioCount: municipioCount
            )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .frame(maxWidth: 420)
    }
}



struct PillSegmentedControl: View {
    @Binding var selection: FavoritesView.Segment
    let employeeCount: Int
    let municipioCount: Int
    
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 8) {

            segmentButton(.employees, title: "Funcionários", count: employeeCount)
            segmentButton(.municipios, title: "Municípios", count: municipioCount)

        }
        .padding(6)
        .background(
            Rectangle()
                .fill(Color(.white).opacity(0.6))
        )
        .frame(maxWidth: .infinity)
        .frame(height:30)
    }

    // MARK: - Segment Button Builder
    private func segmentButton(_ seg: FavoritesView.Segment, title: String, count: Int) -> some View {
        ZStack {
            if selection == seg {
                Rectangle()
                    .fill(Color.blue)
                    .frame(height:120)
                    .matchedGeometryEffect(id: "SLIDE_PILL", in: animation)
                    .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
            }

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Text("(\(count))")
                    .font(.system(size: 14, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(selection == seg ? .white : .primary)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                selection = seg
            }
        }
    }
}

