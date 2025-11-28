import SwiftUI
import CoreData
#if os(iOS)
import UIKit
import PhotosUI
#endif

struct BuscarFuncionarioView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Funcionario.nome, ascending: true)],
        animation: .default
    ) private var funcionarios: FetchedResults<Funcionario>
    
    @State private var searchText = ""
    @State private var funcionarioParaEditar: Funcionario?
    
    var filteredFuncionarios: [Funcionario] {
        guard !searchText.isEmpty else { return Array(funcionarios) }
        return funcionarios.filter { funcionario in
            (funcionario.nome?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (funcionario.funcao?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (funcionario.regional?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredFuncionarios, id: \.objectID) { funcionario in
                    HStack(spacing: 0) {
                        NavigationLink(destination: FuncionarioDetailView(funcionario: funcionario)) {
                            FuncionarioRowViewV2(funcionario: funcionario, showsFavorite: false)
                        }
                        Button {
                            funcionarioParaEditar = funcionario
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.blue)
                                .frame(width: 36, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Editar funcionário")
                        .padding(.trailing, 4)
                        favoriteButton(for: funcionario)
                            .padding(.trailing, 4)
                    }
                }
                if filteredFuncionarios.isEmpty {
                    Text("Nenhum funcionário encontrado")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Buscar Funcionário")
            .searchable(text: $searchText, prompt: "Buscar por nome, função ou regional")
            .sheet(item: $funcionarioParaEditar) { funcionario in
                // Substitua `EditFuncionarioView` pelo seu editor real, se existir
                EditFuncionarioPlaceholderView(funcionario: funcionario)
                    .presentationDetents([.medium, .large])
            }
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

    private func toggleFavorite(_ funcionario: Funcionario) {
        funcionario.favorito.toggle()

        do {
            try context.save()
            NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
            FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: context) { result in
                switch result {
                case .success:
                    print("[BuscarFuncionario] Favorito atualizado no Firestore")
                case .failure(let error):
                    print("[BuscarFuncionario] Erro ao atualizar favorito: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Erro ao salvar favorito: \(error.localizedDescription)")
        }
    }
}

struct EditFuncionarioPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var funcionario: Funcionario

    @State private var nome: String = ""
    @State private var funcao: String = ""
    @State private var regional: String = ""
    @State private var favorito: Bool = false
    @State private var imagemData: Data? = nil
    #if os(iOS)
    @State private var fotoItem: PhotosPickerItem?
    #endif
    @State private var showingValidationAlert = false

    var body: some View {
        NavigationStack {
            Form {
                #if os(iOS)
                Section("Imagem") {
                    VStack(spacing: 12) {
                        if let imagemData, let uiImage = UIImage(data: imagemData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundStyle(.secondary)
                        }

                        #if canImport(PhotosUI)
                        PhotosPicker(selection: $fotoItem, matching: .images) {
                            Label("Selecionar foto", systemImage: "photo.on.rectangle")
                        }
                        .onChange(of: fotoItem) { newItem in
                            guard let newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        imagemData = data
                                    }
                                }
                            }
                        }
                        #endif
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                #endif

                Section("Informações") {
                    TextField("Nome", text: $nome)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                    TextField("Função", text: $funcao)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                    TextField("Regional", text: $regional)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                }
                Section("Favorito") {
                    Toggle("Marcar como favorito", isOn: $favorito)
                }
            }
            .navigationTitle("Editar Funcionário")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { saveChanges() }
                        .disabled(nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                // Initialize state from the current Core Data object
                nome = funcionario.nome ?? ""
                funcao = funcionario.funcao ?? ""
                regional = funcionario.regional ?? ""
                favorito = funcionario.favorito
                imagemData = funcionario.imagem
            }
            .alert("Preencha o nome", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func saveChanges() {
        let trimmedName = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showingValidationAlert = true
            return
        }

        funcionario.nome = trimmedName
        funcionario.funcao = funcao.trimmingCharacters(in: .whitespacesAndNewlines)
        funcionario.regional = regional.trimmingCharacters(in: .whitespacesAndNewlines)
        funcionario.favorito = favorito
        funcionario.imagem = imagemData

        do {
            try context.save()
            NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
            FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: context) { result in
                switch result {
                case .success:
                    print("[EditarFuncionario] Funcionário atualizado no Firestore")
                case .failure(let error):
                    print("[EditarFuncionario] Erro ao atualizar: \(error.localizedDescription)")
                }
            }
            dismiss()
        } catch {
            print("Erro ao salvar alterações: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BuscarFuncionarioView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
