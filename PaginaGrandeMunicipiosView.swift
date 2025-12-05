import SwiftUI
internal import CoreData
#if os(iOS)
import UIKit
#endif

// MARK: - MAIN VIEW
struct PaginaGrandeMunicipiosView: View {

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Municipio.nome, ascending: true)],
        animation: .default
    ) private var municipios: FetchedResults<Municipio>

    // MARK: - FILTER STATES
    @State private var searchText: String = ""
    @State private var regionalSelecionada: String = ""
    @State private var zoom: CGFloat = 1.0
    @State private var showPurgeConfirmation = false

    // MARK: - REGION LIST
    private var todasRegionais: [String] {
        var set: Set<String> = []
        municipios.forEach { m in
            if let r = m.regional?.trimmingCharacters(in: .whitespacesAndNewlines),
               !r.isEmpty {
                set.insert(r)
            }
        }
        return set.sorted()
    }

    // MARK: - FILTERED LIST
    private var filteredMunicipios: [Municipio] {
        municipios.filter { m in
            
            let nome = m.nome ?? ""
            let regio = m.regional ?? ""
            let regionalTrim = regio.trimmingCharacters(in: .whitespacesAndNewlines)

            let matchesSearch =
                searchText.isEmpty ||
                nome.localizedCaseInsensitiveContains(searchText) ||
                regio.localizedCaseInsensitiveContains(searchText)

            let matchesRegion =
                regionalSelecionada.isEmpty ||
                regionalTrim == regionalSelecionada

            return matchesSearch && matchesRegion
        }
    }

    // MARK: - DELETE HELPERS
    private func deleteMunicipio(_ municipio: Municipio) {
        deleteFromFirebase(entity: "Municipio", id: municipio.objectID.uriRepresentation().absoluteString)
        context.delete(municipio)
        do { try context.save() } catch { print("Erro ao salvar após deletar Município: \(error)") }
    }

    private func deleteFromFirebase(entity: String, id: String) {
        // TODO: Integrate with your Firebase layer. Example:
        // Firestore.firestore().collection(entity).document(id).delete { error in ... }
        print("[Firebase] Deleting \(entity) with id: \(id)")
    }

    // MARK: - BODY
    var body: some View {
        NavigationStack {
            ZoomableScrollView5(minZoomScale: 0.5, maxZoomScale: 3.0) {
                content
            }
            .navigationTitle("Municípios")
#if DEBUG
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        showPurgeConfirmation = true
                    } label: {
                        Text("Limpar Tudo")
                    }
                    .accessibilityLabel("Limpar todas as regionais")
                }
            }
            .confirmationDialog(
                "Deseja deletar a tabela de municipio?",
                isPresented: $showPurgeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Apagar Tabela de Municípios", role: .destructive) {
                    purgeAllMunicipios()
                }
                Button("Cancelar", role: .cancel) { }
            }
#endif
        }
    }

    // MARK: - MAIN CONTENT AREA
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ---------------------- FILTER PANEL ----------------------
            VStack(alignment: .leading, spacing: 20) {

                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text("Filtros de Municípios")
                        .font(.title2.weight(.semibold))
                }

                // SEARCH BAR
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)

                    TextField("Buscar município ou regional…",
                              text: $searchText)
                        .textInputAutocapitalization(.words)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 2)
                )

                // REGIONAL PICKER
                VStack(alignment: .leading, spacing: 8) {
                    Text("Regional")
                        .font(.headline)

                    Picker("Regional", selection: $regionalSelecionada) {
                        Text("Todas").tag("")
                        ForEach(todasRegionais, id: \.self) { reg in
                            Text(reg).tag(reg)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.blue.opacity(0.2), lineWidth: 2)
                    )
                }

            }
            .padding()
            .frame(width: 1000)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.blue.opacity(0.4), lineWidth: 4))

            // ---------------------- MUNICIPALITY LIST ----------------------
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(filteredMunicipios, id: \.objectID) { municipio in
                        MunicipioCardRow(municipio: municipio, zoom: zoom)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteMunicipio(municipio)
                                } label: {
                                    Label("Deletar", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: 1000, height: 1400)

            Spacer()
        }
        .padding(.top, 40)
        .padding(.leading, 40)
        .frame(minWidth: 5000, minHeight: 5000, alignment: .topLeading)
        .background(Color(.systemGray6))
    }
    private func purgeAllMunicipios() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Municipio")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            // Optional: mirror deletion in Firebase if desired
            print("[Firebase] Deleting entire Municipios collection (implement real call if needed)")
            try context.execute(batchDelete)
            try context.save()
        } catch {
            print("[PaginaGrandeView2] Erro ao apagar todos os Municípios: \(error.localizedDescription)")
        }
    }
#if DEBUG
    private func purgeAllRegionais() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            try context.execute(batchDelete)
            try context.save()
        } catch {
            print("[PaginaGrandeMunicipiosView] Erro ao apagar todas as regionais: \(error.localizedDescription)")
        }
    }
#endif
}

struct MunicipioCardRow: View {
    @ObservedObject var municipio: Municipio
    let zoom: CGFloat

    var body: some View {
        HStack(spacing: 16) {

            NavigationLink(destination: MunicipioDetailView(municipio: municipio)) {
                Circle()
                    .fill(Color.teal.opacity(0.25))
                    .frame(width: 55 * zoom, height: 55 * zoom)
                    .overlay(
                        Text(String(municipio.nome?.first ?? "M"))
                            .font(.system(size: 22 * zoom))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(municipio.nome ?? "Sem Nome")
                        .font(.system(size: 18 * zoom, weight: .semibold))

                    Text(municipio.regional ?? "")
                        .font(.system(size: 14 * zoom))
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.black)

            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.blue.opacity(0.15)),
            alignment: .bottom
        )
    }
}
// MARK: - BASIC ZOOMABLE SCROLLVIEW
struct ZoomableScrollView5<Content: View>: UIViewRepresentable {
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

