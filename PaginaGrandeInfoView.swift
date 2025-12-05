//
//  PaginaGrandeInfoView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 04/12/25.
//

import SwiftUI
internal import CoreData
#if os(iOS)
import UIKit
#endif

// MARK: - MAIN VIEW
struct PaginaGrandeInfoView: View {


    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RegionalInfo5.nome, ascending: true)],
        animation: .default
    ) private var regionalinfo: FetchedResults<RegionalInfo5>

    // MARK: - FILTER STATES
    @State private var searchText: String = ""
    @State private var regionalSelecionada: String = ""
    @State private var zoom: CGFloat = 1.0
    @State private var refreshToken = UUID()
    @State private var showPurgeConfirmation = false

    // MARK: - REGION LIST
    private var todasRegionais: [String] {
        var set: Set<String> = []
        regionalinfo.forEach { f in
            if let r = (f.value(forKey: "nome") as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
               !r.isEmpty {
                set.insert(r)
            }
        }
        return set.sorted()
    }

    // MARK: - FILTERED LIST
    private var filteredRegionalInfo: [NSManagedObject] {
        regionalinfo.filter { f in
            let nome = (f.value(forKey: "nome") as? String) ?? ""
            let chefe = (f.value(forKey: "chefe") as? String) ?? ""
            let ramal = (f.value(forKey: "ramal") as? String) ?? ""
            let regionalTrim = nome.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            let matchesSearch =
                searchText.isEmpty ||
                nome.localizedCaseInsensitiveContains(searchText) ||
                chefe.localizedCaseInsensitiveContains(searchText) ||
                ramal.localizedCaseInsensitiveContains(searchText)

            let matchesRegion =
                regionalSelecionada.isEmpty ||
                regionalTrim == regionalSelecionada

            return matchesSearch && matchesRegion
        }
    }

    var body: some View {
        NavigationStack {
            // MASSIVE ZOOMABLE SCROLLVIEW
            ZoomableScrollView02(minZoomScale: 0.5, maxZoomScale: 3.0) {
                content
            }
            .id(refreshToken)
            .navigationTitle("Pesquisa Avançada")
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)) { notification in
                context.mergeChanges(fromContextDidSave: notification)
                refreshToken = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)) { _ in
                refreshToken = UUID()
            }
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
                "Tem certeza que deseja apagar todas as regionais?",
                isPresented: $showPurgeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Apagar Todas", role: .destructive) {
                    purgeAllRegionais()
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Esta ação removerá todas as entradas de RegionalInfo5 do banco de dados.")
            }
#endif
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

            // ---------------------- TABLE + SCROLL ----------------------
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRegionalInfo, id: \.objectID) { item in
                        CardRowSimple2(regionalinfo: item, zoom: zoom)
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
    // MARK: - DELETE HELPERS
    private func deleteRegionalInfo(_ regional: RegionalInfo5) {
        // Core Data deletion
        context.delete(regional)
        do { try context.save() } catch { print("Erro ao salvar após deletar Funcionário: \(error)") }
    }
#if DEBUG
    private func purgeAllRegionais() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        batchDelete.resultType = .resultTypeObjectIDs
        do {
            let result = try context.execute(batchDelete) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
            try context.save()
            context.reset()
            refreshToken = UUID()
        } catch {
            print("[PaginaGrandeInfoView] Erro ao apagar todas as regionais: \(error)")
        }
    }
#endif
}
// MARK: - SIMPLE CARD ROW (standalone)
struct CardRowSimple2: View {
    let regionalinfo: NSManagedObject
    let zoom: CGFloat

    var body: some View {
        let nome = (regionalinfo.value(forKey: "nome") as? String) ?? "Sem Nome"
        let chefe = (regionalinfo.value(forKey: "chefe") as? String) ?? ""
        let ramal = (regionalinfo.value(forKey: "ramal") as? String) ?? ""

        HStack(spacing: 16) {


            // CARD CONTENT
            NavigationLink(destination: { if let regional = regionalinfo as? RegionalInfo5 { RegionalInfoDetailView(regional: regional) } else { Text("Detalhes indisponíveis") } }) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 55 * zoom, height: 55 * zoom)
                    .overlay(
                        Text(String(nome.first ?? "F"))
                            .font(.system(size: 22 * zoom))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nome da Regional: \(nome)")
                        .font(.system(size: 18 * zoom, weight: .semibold))

                    Text("Chefe (Atual): \(chefe)")
                        .font(.system(size: 14 * zoom))
                        .foregroundColor(.secondary)

                    Text("Ramal da Regional: \(ramal)")
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
struct ZoomableScrollView02<Content: View>: UIViewRepresentable {
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

