//
//  DetalhesFuncionarioView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 28/10/25.
//


import SwiftUI
import UIKit
import CoreData

struct DetalhesFuncionarioView: View {
    let funcionario: Funcionario

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let path = funcionario.imagemURL, let ui = loadUIImage(fromPath: path) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.secondary, lineWidth: 2))
                        .padding(.top, 10)
                } else if let data = funcionario.imagem, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.secondary, lineWidth: 2))
                        .padding(.top, 10)
                }

                Text(funcionario.nome ?? "—")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.1)))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    if let funcao = funcionario.funcao { Text("🧩 Função: \(funcao)") }
                    if let regional = funcionario.regional { Text("🏛 Regional: \(regional)") }
                    if let ramal = funcionario.ramal, !ramal.isEmpty { Text("📞 Ramal: \(ramal)") }
                    if let celular = funcionario.celular, !celular.isEmpty { Text("📱 Celular: \(celular)") }
                    if let email = funcionario.email, !email.isEmpty {
                        Text("✉️ Email: \(email)")
                            .textSelection(.enabled)
                    }
                }
                .font(.system(size: 17))
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.4)))
                .padding(.horizontal, 16)

                Spacer(minLength: 20)
            }
        }
        .navigationTitle("Detalhes do Servidor")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadUIImage(fromPath path: String) -> UIImage? {
        // Attempt to load a local file URL string into a UIImage
        // Supports absolute file paths or file URL strings
        if let url = URL(string: path), url.isFileURL {
            if let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
        }
        // Fallback: treat as a file system path
        let fileURL = URL(fileURLWithPath: path)
        if let data = try? Data(contentsOf: fileURL) {
            return UIImage(data: data)
        }
        return nil
    }
}

