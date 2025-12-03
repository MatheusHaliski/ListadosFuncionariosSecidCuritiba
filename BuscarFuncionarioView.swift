import SwiftUI
import _PhotosUI_SwiftUI
internal import CoreData
#if os(iOS)
import UIKit
#endif

struct BuscarFuncionarioView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Funcionario.nome, ascending: true)],
        animation: .default
    ) private var funcionarios: FetchedResults<Funcionario>
    @State private var isScrolling = false
    // MARK: - Estados
    @State private var searchText = ""
    @State private var zoom: CGFloat = 1.0
    @State private var regionalSelecionada: String = ""
    @State private var mostrandoGrafico = false
    @State private var funcionarioParaEditar: Funcionario?
    @State private var didSyncFromFirestore = false
    
    // MARK: - Lista filtrada
    var filteredFuncionarios: [Funcionario] {
        funcionarios.filter { f in
            let matchesSearch =
                searchText.isEmpty ||
                f.nome?.localizedCaseInsensitiveContains(searchText) == true ||
                f.funcao?.localizedCaseInsensitiveContains(searchText) == true ||
                f.regional?.localizedCaseInsensitiveContains(searchText) == true
            
            let matchesRegion =
                regionalSelecionada.isEmpty ||
                f.regional == regionalSelecionada
            
            return matchesSearch && matchesRegion
        }
    }
    struct ScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    // MARK: - Regionais dinâmicas
    var todasRegionais: [String] {
        // Build a unique, sorted list of non-empty region strings in a compiler-friendly way
        var unique: Set<String> = []
        for f in funcionarios {
            if let raw = f.regional {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    unique.insert(trimmed)
                }
            }
        }
        let result = Array(unique).sorted()
        return result
    }
    
    var body: some View {
        NavigationStack {
            // OUTER BOX: scrollable container with both axes + visible indicators
            ScrollView([.vertical, .horizontal]) {
                ZStack {
                    // Outer visual box background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.separator), lineWidth: 1)
                        )

                    // Content inside the outer box
                    VStack(spacing: 0) {
                        // HEADER (Formulário)
                        VStack(spacing: 14) {
                            // Campo de busca
                            TextField("Buscar por nome, função ou regional", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            // Picker de regionais
                            Picker("Regional", selection: $regionalSelecionada) {
                                Text("Todas").tag("")
                                ForEach(todasRegionais, id: \.self) { reg in
                                    Text(reg).tag(reg)
                                }
                            }
                            .pickerStyle(.automatic)
                            .padding(.horizontal)

                            // Zoom Slider
                            VStack(alignment: .leading) {
                                Text("Zoom da Lista")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Slider(value: $zoom, in: 0.8...1.6, step: 0.05)
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGroupedBackground))

                        // Some intentional blank space between header and inner box
                        Spacer(minLength: 12)

                        // INNER BOX: contains only the table/list
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )

                            // The table/list content
                            LazyVStack(spacing: 0) {
                                ForEach(filteredFuncionarios, id: \.objectID) { funcionario in
                                    CardRow(
                                        funcionario: funcionario,
                                        zoom: zoom,
                                        isScrolling: isScrolling,
                                        onEdit: { funcionarioParaEditar = funcionario }
                                    )
                                }
                            }
                            .padding(12)
                        }
                        .padding([.horizontal, .bottom], 12)

                        // Extra blank space inside the outer box after the inner table
                        Spacer(minLength: 16)
                    }
                    .padding(16)
                }
                // Minimum size so the box is visible; larger content will expand and scroll
                .frame(minWidth: 1200, minHeight: 900)
            }
            .scrollIndicators(.visible)
            .navigationTitle("Buscar Funcionário")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mostrandoGrafico = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .accessibilityLabel("Mostrar gráfico de regionais")
                }
            }
            .sheet(item: $funcionarioParaEditar) { funcionario in
                EditFuncionarioPlaceholderView(funcionario: funcionario)
            }
            .sheet(isPresented: $mostrandoGrafico) {
                GraficoFuncionariosPorRegionalView(
                    data: AnalyticsAggregator.aggregateFuncionariosByRegional(Array(funcionarios))
                )
            }
            .task(id: "firestoreSyncOnce") {
                guard !didSyncFromFirestore else { return }
                didSyncFromFirestore = true
                FirestoreMigrator.syncFromFirestoreToCoreData(context: context) { _ in }
            }
        }
    }
}

struct EditFuncionarioPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var funcionario: Funcionario

    // MARK: - States for all attributes
    @State private var nome: String = ""
    @State private var funcao: String = ""
    @State private var regional: String = ""
    @State private var favorito: Bool = false
    @State private var celular: String = ""
    @State private var email: String = ""
    @State private var ramal: String = ""
    @State private var imagemURL: String = ""
    @State private var imagemData: Data? = nil
    
    #if os(iOS)
    @State private var fotoItem: PhotosPickerItem?
    #endif

    @State private var showingValidationAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // MARK: - Header Photo + Name
                    VStack(spacing: 14) {
                        
                        photoSection
                        
                        TextField("Nome completo", text: $nome)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 32)
                    }

                    Divider().padding(.horizontal, 32)

                    // MARK: - Main Information
                    Group {
                        sectionLabel("Função / Cargo")
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Ex.: Engenheiro, Gestor Municipal", text: $funcao)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Text("Descreva brevemente a função exercida no órgão.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 32)

                        sectionLabel("Regional")
                        TextField("Ex.: Curitiba, Oeste, Noroeste", text: $regional)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 32)
                    }

                    Divider().padding(.horizontal, 32)

                    // MARK: - Contact
                    Group {
                        sectionLabel("Contato")
                        infoField(title: "Celular", text: $celular, keyboard: .phonePad)
                        infoField(title: "Ramal", text: $ramal, keyboard: .numberPad)
                        infoField(title: "E-mail", text: $email, keyboard: .emailAddress)
                    }

                    // MARK: - Favorite Toggle
                    Toggle("Marcar como favorito", isOn: $favorito)
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))

                    Spacer().frame(height: 20)
                }
                .padding(.top, 24)
            }

            .navigationTitle("Editar Funcionário")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { saveChanges() }
                        .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadValues() }
            .alert("Preencha o nome", isPresented: $showingValidationAlert) {
                Button("OK") { }
            }
        }
    }

    // MARK: - Photo Section
    private var photoSection: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            if let data = imagemData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue.opacity(0.4), lineWidth: 3))
                    .shadow(radius: 6)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .foregroundStyle(.gray.opacity(0.6))
            }

            PhotosPicker(selection: $fotoItem, matching: .images) {
                Text("Alterar foto")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            .onChange(of: fotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run { imagemData = data }
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Section Label
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
    }

    // MARK: - Info Field Builder
    private func infoField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(title, text: text)
                .keyboardType(keyboard)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Load Initial Values
    private func loadValues() {
        nome = funcionario.nome ?? ""
        funcao = funcionario.funcao ?? ""
        regional = funcionario.regional ?? ""
        favorito = funcionario.favorito
        celular = funcionario.celular ?? ""
        email = funcionario.email ?? ""
        ramal = funcionario.ramal ?? ""
        imagemURL = funcionario.imagemURL ?? ""
        imagemData = funcionario.imagem
    }

    // MARK: - Save Changes
    private func saveChanges() {
        guard !nome.trimmingCharacters(in: .whitespaces).isEmpty else {
            showingValidationAlert = true
            return
        }

        funcionario.nome = nome
        funcionario.funcao = funcao
        funcionario.regional = regional
        funcionario.favorito = favorito
        funcionario.celular = celular
        funcionario.email = email
        funcionario.ramal = ramal
        funcionario.imagemURL = imagemURL
        funcionario.imagem = imagemData

        do {
            try context.save()
        } catch {
            print("Erro ao salvar: \(error.localizedDescription)")
        }

        dismiss()
    }
}

#Preview {
    BuscarFuncionarioView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
