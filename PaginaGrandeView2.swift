import SwiftUI
internal import CoreData
import SDWebImageSwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - MAIN VIEW
struct PaginaGrandeView2: View {

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Funcionario.nome, ascending: true)],
        animation: .default
    ) private var funcionarios: FetchedResults<Funcionario>
    
    // Optional: Municipios fetch (only if entity exists)
    #if canImport(SwiftUI)
    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    ) private var municipios: FetchedResults<Municipio>
    #endif

    // MARK: - FILTER STATES
    @State private var searchText: String = ""
    @State private var regionalSelecionada: String = ""
    @State private var zoom: CGFloat = 1.0
    @State private var showFuncionariosPurgeConfirmation = false
    @State private var showMunicipiosPurgeConfirmation = false
    
    private var regionaisFiltradas: [String] {
        switch segmentoSelecionado {
        case .funcionario:
            return todasRegionaisFuncionarios
        case .municipio:
            return todasRegionaisMunicipios
        }
    }
    private var todasRegionaisFuncionarios: [String] {
        var set: Set<String> = []
        funcionarios.forEach { f in
            if let r = f.regional?.trimmingCharacters(in: .whitespacesAndNewlines),
               !r.isEmpty {
                set.insert(r)
            }
        }
        return set.sorted()
    }
    private var todasRegionaisMunicipios: [String] {
        var set: Set<String> = []
        filteredMunicipios.forEach { m in
            if let r = m.regional?.trimmingCharacters(in: .whitespacesAndNewlines),
               !r.isEmpty {
                set.insert(r)
            }
        }
        return set.sorted()
    }

    enum Segmento: String, CaseIterable, Identifiable {
        case funcionario = "Funcionário"
        case municipio = "Município"
        var id: String { rawValue }
    }
    @State private var segmentoSelecionado: Segmento = .funcionario

    // MARK: - FILTERED LISTS
    // Funcionarios filtered + favorites only
    private var filteredFuncionarios: [Funcionario] {
        funcionarios.filter { f in
            guard f.favorito == true else { return false }
            let nome = f.nome ?? ""
            let funcao = f.funcao ?? ""
            let regionalBruta = f.regional ?? ""
            let regionalTrim = regionalBruta.trimmingCharacters(in: .whitespacesAndNewlines)

            let matchesSearch =
                searchText.isEmpty ||
                nome.localizedCaseInsensitiveContains(searchText) ||
                funcao.localizedCaseInsensitiveContains(searchText) ||
                regionalBruta.localizedCaseInsensitiveContains(searchText)

            let matchesRegion =
                regionalSelecionada.isEmpty ||
                regionalTrim == regionalSelecionada

            return matchesSearch && matchesRegion
        }
    }
    
    // Municipios filtered + favorites only (if your Municipio model provides these fields)
    private var filteredMunicipios: [Municipio] {
        #if canImport(SwiftUI)
        return municipios.filter { m in
            // Assuming Municipio has properties: nome (String?), regional (String?), favorito (Bool)
            let nome = (m.value(forKey: "nome") as? String) ?? ""
            let regionalBruta = (m.value(forKey: "regional") as? String) ?? ""
            let favorito = (m.value(forKey: "favorito") as? Bool) ?? false
            guard favorito == true else { return false }

            let regionalTrim = regionalBruta.trimmingCharacters(in: .whitespacesAndNewlines)

            let matchesSearch =
                searchText.isEmpty ||
                nome.localizedCaseInsensitiveContains(searchText) ||
                regionalBruta.localizedCaseInsensitiveContains(searchText)

            let matchesRegion =
                regionalSelecionada.isEmpty ||
                regionalTrim == regionalSelecionada

            return matchesSearch && matchesRegion
        }
        #else
        return []
        #endif
    }

    // MARK: - REGION LIST
    private var todasRegionais: [String] {
        var set: Set<String> = []
        funcionarios.forEach { f in
            if let r = f.regional?.trimmingCharacters(in: .whitespacesAndNewlines),
               !r.isEmpty {
                set.insert(r)
            }
        }
        return set.sorted()
    }
    
    // MARK: - DELETE HELPERS
    private func deleteFuncionario(_ funcionario: Funcionario) {
        // Firebase deletion placeholder — implement your own Firebase call here
        deleteFromFirebase(entity: "Funcionario", id: funcionario.objectID.uriRepresentation().absoluteString)
        // Core Data deletion
        context.delete(funcionario)
        do { try context.save() } catch { print("Erro ao salvar após deletar Funcionário: \(error)") }
    }

    private func deleteMunicipio(_ municipio: Municipio) {
        // Firebase deletion placeholder — implement your own Firebase call here
        deleteFromFirebase(entity: "Municipio", id: municipio.objectID.uriRepresentation().absoluteString)
        // Core Data deletion
        context.delete(municipio)
        do { try context.save() } catch { print("Erro ao salvar após deletar Município: \(error)") }
    }

    private func deleteFromFirebase(entity: String, id: String) {
        // TODO: Integrate with your Firebase layer. Example:
        // Firestore.firestore().collection(entity).document(id).delete { error in ... }
        print("[Firebase] Deleting \(entity) with id: \(id)")
    }

    var body: some View {
        NavigationStack {
            // MASSIVE ZOOMABLE SCROLLVIEW
            ZoomableScrollView23(minZoomScale: 0.5, maxZoomScale: 3.0) {
                content
            }
            .navigationTitle("Favoritos")
        }
    }

    // MARK: - MAIN CONTENT (FILTER + TABLE)
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ---------------------- FILTER PANEL ----------------------
            VStack(alignment: .leading, spacing: 20) {

                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text(segmentoSelecionado == .funcionario ? "Filtros de Funcionários" : "Filtros de Municípios")
                        .font(.title2.weight(.semibold))
                }
                
                Picker("Tipo", selection: $segmentoSelecionado) {
                    ForEach(Segmento.allCases) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)

                // SEARCH BAR
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField(
                        segmentoSelecionado == .funcionario
                            ? "Buscar por nome, função ou regional"
                            : "Buscar por nome ou regional",
                        text: $searchText
                    )



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
                    RoundedRectangle(cornerRadius: 12).stroke(.blue.opacity(0.3), lineWidth: 2)
                )

                // REGIONAL PICKER
                VStack(alignment: .leading, spacing: 8) {
                    Text("Regional")
                        .font(.headline)

                    Picker("Regional", selection: $regionalSelecionada) {
                        Text("Todas").tag("")

                        ForEach(regionaisFiltradas, id: \.self) { regional in
                            Text(regional).tag(regional)
                        }
                    }

                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(.blue.opacity(0.2), lineWidth: 2)
                    )
                }

            }
            .padding()
            .frame(width: 1000)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.blue.opacity(0.4), lineWidth: 4))

            // ---------------------- TABLE + SCROLL ----------------------
            Group {
                if segmentoSelecionado == .funcionario {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredFuncionarios, id: \.objectID) { funcionario in
                                CardRowSimple11(funcionario: funcionario, zoom: zoom)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(width: 1000, height: 1400)
                } else {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredMunicipios, id: \.objectID) { municipio in
                                NavigationLink(destination: MunicipioDetailView(municipio: municipio)) {
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(Color.green.opacity(0.2))
                                            .frame(width: 55 * zoom, height: 55 * zoom)
                                            .overlay(
                                                Text(String((municipio.nome?.first ?? "M")))
                                                    .font(.system(size: 22 * zoom))
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(municipio.nome ?? "Sem Nome")
                                                .font(.system(size: 18 * zoom, weight: .semibold))

                                            Text(municipio.regional ?? "")
                                                .font(.system(size: 14 * zoom))
                                                .foregroundColor(.blue)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.white)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 1)
                                            .foregroundColor(.green.opacity(0.15)),
                                        alignment: .bottom
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                        }
                        .padding(.vertical, 8)
                    }
                    .frame(width: 1000, height: 1400)
                }
            }

            Spacer()
        }
        // ÁREA GIGANTE: muito maior que filtro+tabela
        .padding(.top, 40)      // margem pequena do topo
        .padding(.leading, 40)  // margem pequena da esquerda
        .frame(minWidth: 5000, minHeight: 5000, alignment: .topLeading)
        .background(Color(.systemGray6))
    }
#if DEBUG
    public func purgeAllFuncionarios() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Funcionario")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            // Optional: mirror deletion in Firebase if desired
            print("[Firebase] Deleting entire Funcionarios collection (implement real call if needed)")
            try context.execute(batchDelete)
            try context.save()
        } catch {
            print("[PaginaGrandeView2] Erro ao apagar todos os Funcionarios: \(error.localizedDescription)")
        }
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

    private func purgeAllRegionais() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            try context.execute(batchDelete)
            try context.save()
        } catch {
            print("[PaginaGrandeView2] Erro ao apagar todas as regionais: \(error.localizedDescription)")
        }
    }
#endif
}

// Extract only the part after the first vertical bar ("|")
private func afterPipe(_ value: String?) -> String {
    guard let value = value, !value.isEmpty else { return "" }
    if let range = value.range(of: "|") {
        let after = value[range.upperBound...]
        return String(after).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - SIMPLE CARD ROW (standalone)
struct CardRowSimple11: View {
    @ObservedObject var funcionario: Funcionario
    let zoom: CGFloat

    // Extract only the part after the first vertical bar ("|")
    private func afterPipe(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "" }
        if let range = value.range(of: "|") {
            let after = value[range.upperBound...]
            return String(after).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayNome: String {  afterPipe(funcionario.nome) }
    private var displayFuncao: String { afterPipe(funcionario.funcao) }
    private var displayRegional: String { afterPipe(funcionario.regional) }

    private var profileImage: some View {
        ZStack {
            if let data = funcionario.imagem,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color(.systemGray5))
                Text(String((displayNome.first ?? "F")))
                    .font(.system(size: 22 * zoom))
                    .foregroundColor(.primary)
            }
        }
        .clipShape(Circle())
    }

    var body: some View {
        HStack(spacing: 16) {

            
            // CARD CONTENT
            NavigationLink(destination: FuncionarioDetailView(funcionario: funcionario)) {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 55 * zoom, height: 55 * zoom)
                    .overlay(
                        profileImage
                            .frame(width: 55 * zoom, height: 55 * zoom)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nome: \(displayNome.isEmpty ? "NotIdentified" : displayNome)")
                        .font(.headline)
                    Text("Função: \(displayFuncao)")
                        .font(.headline)

                    Text("Regional: \(displayRegional)")
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


// MARK: - ZOOMABLE SCROLLVIEW WITH KEYBOARD AUTO-SCROLL BLOCKER
struct ZoomableScrollView23<Content: View>: UIViewRepresentable {
    var minZoomScale: CGFloat
    var maxZoomScale: CGFloat
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(self, host: UIHostingController(rootView: content()))
    }

    func makeUIView(context: Context) -> UIScrollView {

        let scroll = UIScrollView()
        scroll.minimumZoomScale = minZoomScale
        scroll.maximumZoomScale = maxZoomScale
        scroll.delegate = context.coordinator
        scroll.showsVerticalScrollIndicator = true
        scroll.showsHorizontalScrollIndicator = true
        scroll.bouncesZoom = true

        scroll.keyboardDismissMode = .interactive
        scroll.contentInsetAdjustmentBehavior = .never   // 👈 impede ajustes automáticos

        // HOST VIEW
        let hostView = context.coordinator.host.view!
        hostView.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(hostView)

        NSLayoutConstraint.activate([
            hostView.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            hostView.topAnchor.constraint(equalTo: scroll.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: scroll.bottomAnchor)
        ])

        // LISTEN TO KEYBOARD
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        return scroll
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.host.rootView = content()
    }

    // MARK: - COORDINATOR
    class Coordinator: NSObject, UIScrollViewDelegate {

        let parent: ZoomableScrollView23
        let host: UIHostingController<Content>

        var keyboardVisible = false
        var lockedX: CGFloat = 0

        init(_ parent: ZoomableScrollView23, host: UIHostingController<Content>) {
            self.parent = parent
            self.host = host
        }

        // MARK: KEYBOARD STATES
        @objc func keyboardWillShow() {
            keyboardVisible = true
        }

        @objc func keyboardWillHide() {
            keyboardVisible = false
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            host.view
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            lockedX = scrollView.contentOffset.x
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            lockedX = scrollView.contentOffset.x
        }

        // MARK: THE FIX: BLOCK AUTO-SCROLL HORIZONTAL WHEN KEYBOARD IS VISIBLE
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard keyboardVisible else { return }

            // If UIKit tries to move horizontally, revert
            let dx = abs(scrollView.contentOffset.x - lockedX)
            if dx > 1 {
                scrollView.contentOffset.x = lockedX
            }
        }
    }
}

