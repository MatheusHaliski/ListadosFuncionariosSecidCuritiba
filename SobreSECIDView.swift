//
//  SobreSECIDView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 27/10/25.
//


import SwiftUI

struct SobreSECIDView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // LOGO GOV PR
                    Image("governo_parana")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .padding(.top, 20)
                        .shadow(radius: 4)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Group {
                            Text("🏛 **Visão da Secretaria das Cidades:**")
                                .font(.headline)
                            Text("Promover o desenvolvimento urbano sustentável e integrado, garantindo melhor qualidade de vida aos cidadãos paranaenses.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Group {
                            Text("📱 **Objetivo do Aplicativo:**")
                                .font(.headline)
                            Text("Facilitar o acesso a informações sobre servidores e municípios vinculados à Secretaria das Cidades do Paraná, promovendo transparência e eficiência.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Group {
                            Text("☎️ **Ramal Principal da SECID (Sede):**")
                                .font(.headline)
                            Text("(41) 3250-7200")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Group {
                            Text("📍 **Endereço da Sede:**")
                                .font(.headline)
                            Text("R. Eurípedes Garcez do Nascimento, 1195 - Ahú, Curitiba - PR, 80540-280")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Group {
                            Text("👔 **Secretário das Cidades do Paraná:**")
                                .font(.headline)
                            Text("Guto Silva")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        Group {
                            Text("👔 **Equipe de Desenvolvimento:**")
                                .font(.headline)
                            Text("Matheus Braschi Haliski - Assistente Administrativo da UTS")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("Silvia Rolim - Chefia UTS")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
                .navigationTitle("Sobre a SECID")
                .navigationBarTitleDisplayMode(.inline)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}
