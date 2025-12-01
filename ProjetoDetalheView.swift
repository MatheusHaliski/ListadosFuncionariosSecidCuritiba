//
//  ProjetoDetalheView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 23/10/25.
//

import SwiftUI
import UIKit
import CloudKit
import CoreLocation
import AVFoundation
import Network
internal import CoreData


struct ProjetoDetalheView: View {
    @ObservedObject var projeto: Projeto
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var nome: String = ""
    @State private var descricao: String = ""
    @State private var status: String = ""
    private let statusOptions = ["Em andamento", "Finalizado", "A fazer"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nome do Projeto").font(.subheadline).foregroundStyle(.secondary)
                        TextField("Nome", text: $nome)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 24, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status").font(.subheadline).foregroundStyle(.secondary)
                        Picker("Status", selection: $status) {
                            ForEach(statusOptions, id: \.self) { s in
                                Text(s).tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Descrição").font(.subheadline).foregroundStyle(.secondary)
                        TextEditor(text: $descricao)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: .secondarySystemFill)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .onAppear {
                    nome = projeto.nome ?? ""
                    status = projeto.status ?? "Em andamento"
                    if let desc = projeto.value(forKey: "descricao") as? String {
                        descricao = desc
                    } else {
                        descricao = ""
                    }
                }
            }
            .navigationTitle("Detalhes do Projeto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        projeto.nome = nome
                        projeto.status = status
                        projeto.setValue(descricao, forKey: "descricao")
                        try? context.save()
                        dismiss()
                        onSave?()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
