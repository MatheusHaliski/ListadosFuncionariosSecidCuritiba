//
//  RegionalInfoDetailView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 04/12/25.
//

import SwiftUI
internal import CoreData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct RegionalInfoDetailView: View {
    @ObservedObject var regional: RegionalInfo5  // entidade do Core Data
    let onEdit: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var mostrandoEdicao = false
    @State private var mostrandoEdicaoMunicipio = false
    @State private var showPurgeConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Título Principal
                Text(regional.nome ?? "Regional")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color.blue)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                // Card de Informações
                VStack(spacing: 0) {

                    infoRow(
                        icon: "mappin.and.ellipse",
                        iconColor: .red,
                        title: "Endereço",
                        text: regional.endereco ?? "Não informado"
                    )

                    infoRow(
                        icon: "person.crop.circle.badge.checkmark",
                        iconColor: .green,
                        title: "Chefe",
                        text: regional.chefe ?? "Não informado"
                    )

                    infoRow(
                        icon: "phone.fill",
                        iconColor: .blue,
                        title: "Telefone / Ramal",
                        text: regional.ramal ?? "Não informado"
                    )
                }
                .padding(.top, 4)
                .padding(20)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1.5)
                )
                .cornerRadius(16)
                .padding(.horizontal, 16)

                Spacer(minLength: 40)
            }

        }
        .onAppear {
            #if canImport(FirebaseFirestore)
            FirestoreMigrator.ensureRegionalInfoCollectionExists()
            var data: [String: Any] = [:]
            if let nome = regional.nome { data["nome"] = nome }
            if let chefe = regional.chefe { data["chefe"] = chefe }
            if let ramal = regional.ramal { data["ramal"] = ramal }
            if let endereco = regional.endereco { data["endereco"] = endereco }
            data["updatedAt"] = FieldValue.serverTimestamp()
            var documentID: String
            if let remoteID = regional.value(forKey: "id") as? String, !remoteID.isEmpty {
                documentID = remoteID
            } else {
                documentID = firestoreSafeID(for: regional.objectID)
            }
            FirestoreMigrator.upsertRegionalInfo(id: documentID, data: data, completion: nil)
            #endif
        }
        .background(Color(.systemBackground))
        .navigationTitle("Detalhes da Regional")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onEdit = onEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        mostrandoEdicao = true
                        onEdit()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    deleteRegional()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Deletar regional")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    mostrandoEdicaoMunicipio = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Editar município")
            }
        }
        .sheet(isPresented: $mostrandoEdicao) {
            NavigationStack {
                RegionalFormView(
                    regional: regional,
                    onSaved: { @MainActor in
                        do {
                            if viewContext.hasChanges {
                                try viewContext.save()
                            }
                            // No manual refresh needed when using @ObservedObject
                            mostrandoEdicao = false
                            #if os(iOS)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                        } catch {
                            print("[RegionalDetail] Erro ao salvar alterações: \(error.localizedDescription)")
                        }
                    }
                )
                .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $mostrandoEdicaoMunicipio) {
            NavigationStack {
                RegionalFormView(
                    regional: regional,
                    onSaved: { @MainActor in
                        do {
                            if viewContext.hasChanges {
                                try viewContext.save()
                            }
                            // Dismiss the municipio edit sheet safely on main thread
                            mostrandoEdicaoMunicipio = false
                            #if os(iOS)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                        } catch {
                            print("[RegionalDetail] Erro ao salvar município: \(error.localizedDescription)")
                        }
                    }
                )
                .environment(\.managedObjectContext, viewContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: viewContext)) { _ in
            // Ensure the observed object merges changes; Core Data with @ObservedObject typically updates automatically
            // but this helps when edits come from child contexts.
            viewContext.refresh(regional, mergeChanges: true)
        }
        .onChange(of: regional.hasChanges) { _ in
            // Trigger a minimal state change if needed; usually unnecessary with @ObservedObject
            _ = regional.objectID
        }
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

    @ViewBuilder
    private func infoRow(icon: String, iconColor: Color, title: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(width: 140, alignment: .leading)

            Rectangle()
                .fill(Color.blue.opacity(0.25))
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            Text(text)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .center)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.blue.opacity(0.25))
                .frame(height: 1)
                .offset(x: 0, y: 0)
        }
    }

    // MARK: - DELETE REGIONAL
    private func deleteRegional() {
        // Placeholder: delete regional from Core Data
        viewContext.delete(regional)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("[RegionalDetail] Erro ao deletar regional: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    private func purgeAllRegionais() {
        // Delete all RegionalInfo5 objects from Core Data in DEBUG builds
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            try viewContext.execute(batchDelete)
            try viewContext.save()
        } catch {
            print("[RegionalDetail] Erro ao apagar todas as regionais: \(error.localizedDescription)")
        }
    }
    #endif
}

