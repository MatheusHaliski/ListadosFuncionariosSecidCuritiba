//
//  ProjetosModalView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 23/10/25.
//

import SwiftUI
internal import CoreData

struct ProjetosModalView: View {
    @ObservedObject var funcionario: Funcionario
    @Environment(\.managedObjectContext) private var context

    @State private var novoProjetoNome = ""
    @State private var novoStatus = "Em andamento"
    @State private var novaDescricao = ""
    private let statusOptions = ["Em andamento", "Finalizado", "A fazer"]
    
    // Safely expose the employee's projects as a Swift array for ForEach
    private var projetos: [Projeto] {
        let set = (funcionario.value(forKey: "projetos") as? NSSet) ?? []
        return set.compactMap { $0 as? Projeto }
            .sorted { (a, b) in
                let an = a.nome ?? ""
                let bn = b.nome ?? ""
                return an.localizedCaseInsensitiveCompare(bn) == .orderedAscending
            }
    }
    
    private var projetosFiltrados: [Projeto] {
        if filtroStatus == "Todos" { return projetos }
        return projetos.filter { ($0.status ?? "") == filtroStatus }
    }
    
    @State private var projetoSelecionado: Projeto? = nil
    @State private var filtroStatus: String = "Todos"
    @State private var reloadID = UUID()
    
    private enum ProjetosTab: String, CaseIterable, Identifiable {
        case novo = "Novo Projeto"
        case atuais = "Projetos Atuais"
        var id: String { rawValue }
    }
    @State private var projetosTab: ProjetosTab = .atuais
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                StatusFilterChips(selected: $filtroStatus)
                
                Picker("", selection: $projetosTab) {
                    Text("Novo Projeto").tag(ProjetosTab.novo)
                    Text("Projetos Atuais").tag(ProjetosTab.atuais)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List {
                    if projetosTab == .novo {
                        // Form Section at the top
                        Section {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Novo Projeto")
                                    .font(.headline)

                                VStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Nome")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        TextField("Digite o nome do projeto", text: $novoProjetoNome)
                                            .textInputAutocapitalization(.words)
                                            .autocorrectionDisabled(false)
                                            .submitLabel(.next)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color(uiColor: .secondarySystemFill))
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Status")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Menu {
                                            Picker("Status", selection: $novoStatus) {
                                                ForEach(statusOptions, id: \.self) { s in
                                                    Text(s).tag(s)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(novoStatus.isEmpty ? "Selecione um status" : novoStatus)
                                                    .foregroundStyle(novoStatus.isEmpty ? .secondary : .primary)
                                                Spacer()
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color(uiColor: .secondarySystemFill))
                                            )
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Descrição")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        TextEditor(text: $novaDescricao)
                                            .frame(minHeight: 80)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color(uiColor: .secondarySystemFill))
                                            )
                                    }

                                    Button {
                                        let novo: Projeto = Projeto(context: context)
                                        novo.nome = novoProjetoNome
                                        novo.status = novoStatus
                                        novo.setValue(novaDescricao, forKey: "descricao")
                                        novo.funcionario = funcionario
                                        do {
                                            try context.save()
                                        } catch {
                                            print("Erro ao salvar projeto: \(error)")
                                        }
                                        // Push updated projetos to Firestore
                                        FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: context) { result in
                                            switch result {
                                            case .success:
                                                print("[ProjetosModal] Projetos uploaded to Firestore")
                                            case .failure(let error):
                                                print("[ProjetosModal] Failed to upload projetos: \(error)")
                                            }
                                        }
                                        novoProjetoNome = ""
                                        novoStatus = "Em andamento"
                                        novaDescricao = ""
                                        // After adding, optionally switch to current projects
                                        projetosTab = .atuais
                                        reloadID = UUID()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Adicionar Projeto")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(novoProjetoNome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                                .padding(14)
                                .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    } else {
                        Section(header: Text("Projetos Atuais")) {
                            ForEach(projetosFiltrados, id: \.objectID) { projeto in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(projeto.nome ?? "Sem nome")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Status: \(projeto.status ?? "Indefinido")")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    Spacer()
                                    Button {
                                        context.delete(projeto)
                                        try? context.save()
                                        FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: context) { result in
                                            if case .failure(let error) = result {
                                                print("[ProjetosModal] Failed to upload after delete: \(error)")
                                            }
                                        }
                                        reloadID = UUID()
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                }
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                                .onTapGesture {
                                    projetoSelecionado = projeto
                                }
                            }
                        }
                    }
                }
                .id(reloadID)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .systemGroupedBackground))

                Spacer()
            }
            .tint(.blue)
            .navigationTitle("Projetos de \(funcionario.nome ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $projetoSelecionado) { projeto in
                ProjetoDetalheView(projeto: projeto) {
                    reloadID = UUID()
                    projetoSelecionado = nil
                    FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: context) { result in
                        if case .failure(let error) = result {
                            print("[ProjetosModal] Failed to upload after edit: \(error)")
                        }
                    }
                }
                .environment(\.managedObjectContext, context)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

private struct StatusFilterChips: View {
    @Binding var selected: String
    private let options: [String] = ["Todos", "A fazer", "Em andamento", "Finalizado"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { status in
                Button {
                    selected = status
                } label: {
                    Text(status)
                        .font(.system(size: 14, weight: selected == status ? .bold : .regular))
                        .frame(height: 40)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule().fill(selected == status ? Color.blue.opacity(0.15) : Color(uiColor: .secondarySystemFill))
                        )
                        .overlay(
                            Capsule().stroke(selected == status ? Color.blue : Color.black.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filtro: \(status)")
            }
        }
        .padding(.horizontal)
    }
}

private struct ProjetoIdentifiableWrapper: Identifiable {
    let projeto: Projeto
    var id: NSManagedObjectID { projeto.objectID }
}

