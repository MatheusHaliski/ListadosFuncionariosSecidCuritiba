import SwiftUI
internal import CoreData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Lightweight shim so the file compiles without Firebase installed.
#if !canImport(FirebaseFirestore)
private enum FieldValueShim {
    // Placeholder to mimic FieldValue.delete() usage; unused but here for parity
    static var deleteToken: String { "__DELETE__" }
}
private struct FieldValue {
    static func delete() -> String { FieldValueShim.deleteToken }
}
private final class Firestore {
    static func firestore() -> Firestore { Firestore() }
    func collection(_ name: String) -> Self { self }
    func document(_ id: String) -> Self { self }
    func setData(_ data: [String: Any], merge: Bool = false, completion: ((Error?) -> Void)? = nil) {
        // No-op shim; log so developers know this isn't real Firestore.
        print("[Firestore SHIM] setData called on collection/document with data=\(data), merge=\(merge)")
        completion?(nil)
    }
}
#endif

#if os(iOS)
import UIKit
#endif

// MARK: - MAIN VIEW
struct PaginaGrandeView: View {
    
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Funcionario.nome, ascending: true)],
        animation: .default
    ) private var funcionarios: FetchedResults<Funcionario>

    // MARK: - FILTER STATES
    @State private var searchText: String = ""
    @State private var regionalSelecionada: String = ""
    @State private var zoom: CGFloat = 1.0
    @State private var showPurgeConfirmation = false
    private var listofregionais: [String] { todasRegionais }
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
    // MARK: - FILTERED LIST
    private var filteredFuncionarios: [Funcionario] {
        funcionarios.filter { f in
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

    // Extract only the part after the first vertical bar ("|")
    private func nameAfterPipe(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        if let range = value.range(of: "|") {
            let after = value[range.upperBound...]
            let trimmed = String(after).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func firestoreSafeID(for objectID: NSManagedObjectID) -> String {
        let uri = objectID.uriRepresentation().absoluteString
        let data = Data(uri.utf8)
        var encoded = data.base64EncodedString()
        encoded = encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return encoded
    }

    // MARK: - DELETE HELPERS
    private func deleteFuncionario(_ funcionario: Funcionario) {
        deleteFromFirebase(entity: "Funcionario", id: firestoreSafeID(for: funcionario.objectID))
        context.delete(funcionario)
        do { try context.save() } catch { print("Erro ao salvar após deletar Funcionário: \(error)") }
    }

    private func deleteFromFirebase(entity: String, id: String) {
        // TODO: Integrate with your Firebase layer. Example:
        // Firestore.firestore().collection(entity).document(id).delete { error in ... }
        // Note: 'id' is a Firestore-safe identifier derived from Core Data's objectID.
        print("[Firebase] Deleting \(entity) with id: \(id)")
    }
    
    private func upsertNomerealInFirebase(for funcionario: Funcionario, nomereal: String?) {
        // TODO: Replace with real Firestore code when Firebase is configured.
        let id = firestoreSafeID(for: funcionario.objectID)

        #if canImport(FirebaseFirestore)
        if let nomereal = nomereal, !nomereal.isEmpty {
            print("[Firebase] Upserting Funcionario nomereal id=\(id) nomereal=\(nomereal)")
            Firestore.firestore()
                .collection("Funcionario")
                .document(id)
                .setData(["nomereal": nomereal], merge: true) { error in
                    if let error = error {
                        print("[Firebase] Failed to upsert nomereal: \(error)")
                    }
                }
        } else {
            print("[Firebase] Clearing Funcionario nomereal id=\(id)")
            Firestore.firestore()
                .collection("Funcionario")
                .document(id)
                .setData(["nomereal": FieldValue.delete()], merge: true) { error in
                    if let error = error {
                        print("[Firebase] Failed to clear nomereal: \(error)")
                    }
                }
        }
        #else
        // FirebaseFirestore not available: just log intent.
        if let nomereal = nomereal, !nomereal.isEmpty {
            print("[Firebase SHIM] Would upsert Funcionario nomereal id=\(id) nomereal=\(nomereal)")
        } else {
            print("[Firebase SHIM] Would clear Funcionario nomereal id=\(id)")
        }
        #endif
    }

#if DEBUG
    private func purgeAllRegionais() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            try context.execute(batchDelete)
            try context.save()
        } catch {
            print("[PaginaGrandeView] Erro ao apagar todas as regionais: \(error.localizedDescription)")
        }
    }
#endif

    var body: some View {
        NavigationStack {
            // MASSIVE ZOOMABLE SCROLLVIEW
            ZoomableScrollView22(minZoomScale: 0.5, maxZoomScale: 3.0) {
                content
            }
            .navigationTitle("Pesquisa de Funcionários")
            .onAppear {
                Task { @MainActor in
                    do {
                        print("[PaginaGrandeView] Starting wiping out any unnamed Funcionarios on appear.")
                        let removed = try await FirestoreMigrator.purgeUnnamedFuncionariosAsync(context: context)
                        if removed > 0 {
                            print("[PaginaGrandeView] Purged \(removed) unnamed Funcionarios on appear.")
                        }
                    } catch {
                        print("[PaginaGrandeView] Failed to purge unnamed Funcionarios: \(error)")
                    }
                }
                Task { @MainActor in
                    for f in funcionarios {
                        let parsed = nameAfterPipe(f.nome)
                        upsertNomerealInFirebase(for: f, nomereal: parsed)
                    }
                }
                Task { @MainActor in
                    FirestoreMigrator.schedulePostStartupSanitization(delaySeconds: 8)
                }
            }

        }
    }
    public func purgeAllFuncionarios() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Funcionario")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            // Optional: mirror deletion in Firebase if desired
            print("[Firebase] Deleting entire Funcionarios collection (implement real call if needed)")
            try context.execute(batchDelete)
            try context.save()
        } catch {
            print("[PaginaGrandeView] Erro ao apagar todos os Funcionarios: \(error.localizedDescription)")
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
                    Text("Filtros de Funcionários")
                        .font(.title2.weight(.semibold))
                }

                // SEARCH BAR
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)

                    TextField("Buscar por nome, função ou regional",
                              text: $searchText)
                        .textInputAutocapitalization(.words)
                        .ignoresSafeArea(.keyboard)

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
                        ForEach(todasRegionais, id: \.self) {
                            Text($0).tag($0)
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
            .ignoresSafeArea(.keyboard)

            // ---------------------- TABLE + SCROLL ----------------------
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(filteredFuncionarios, id: \.objectID) { funcionario in
                            if let regional = funcionario.regional, listofregionais.contains(regional) {
                            // Or when listofregionais contains the regional
                            CardRowSimple04(funcionario: funcionario, zoom: zoom)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: 1000, height: 1400)  // largura/tamanho da "tabela"

            Spacer()
        }
        // ÁREA GIGANTE: muito maior que filtro+tabela
        .padding(.top, 40)      // margem pequena do topo
        .padding(.leading, 40)  // margem pequena da esquerda
        .frame(minWidth: 5000, minHeight: 5000, alignment: .topLeading)
        .background(Color(.systemGray6))
    }
}
// MARK: - SIMPLE CARD ROW (standalone)
struct CardRowSimple04: View {
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
struct ZoomableScrollView22<Content: View>: UIViewRepresentable {
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

        let parent: ZoomableScrollView22
        let host: UIHostingController<Content>

        var keyboardVisible = false
        var lockedX: CGFloat = 0

        init(_ parent: ZoomableScrollView22, host: UIHostingController<Content>) {
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

