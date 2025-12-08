import SwiftUI
internal import CoreData

struct FuncionarioDetailView: View {
    let funcionario: Funcionario
    let onEdit: (() -> Void)?

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var navState: AppNavigationState

    private let contactService: ContactService = DefaultContactService.shared

    @State private var mostrandoEdicao = false
    @State private var isFavorite: Bool
    @State private var mostrandoProjetos = false
    @Environment(\.dismiss) private var dismiss

    init(funcionario: Funcionario, onEdit: (() -> Void)? = nil) {
        self.funcionario = funcionario
        self.onEdit = onEdit
        _isFavorite = State(initialValue: funcionario.favorito)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // MARK: - PHOTO HEADER
                VStack(spacing: 14) {
                    profileImage
                        .padding(.top, 20)

                    Text("Nome: \(funcionario.nome ?? "(Sem nome)")")
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
   

                    if let funcao = funcionario.funcao, !funcao.isEmpty {
                        Text("Função: \(funcionario.funcao ?? "")")
                            .font(.largeTitle.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().padding(.horizontal, 32)

                // MARK: - INFO SECTIONS
                VStack(spacing: 18) {
                    infoSection(title: "Regional", value: funcionario.regional)
                    infoSection(title: "Ramal", value: funcionario.ramal)
                    infoSection(title: "Celular", value: funcionario.celular)
                    emailSection
                }
                .padding(.horizontal, 24)

                Divider().padding(.horizontal, 32)

                // MARK: - CONTACT GRID (CALLING BUTTONS)
                contactGrid
                    .padding(.horizontal, 12)

                // MARK: - FAVORITE TOGGLE
                favoriteToggle
                    .padding(.top, 12)

                Spacer().frame(height: 20)
            }
        }

        .navigationTitle("Detalhes")
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
                    deleteFuncionario()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Deletar funcionário")
            }
        }

        .sheet(isPresented: $mostrandoEdicao) {
                    NavigationStack {
                        FuncionarioFormView(
                            regional: funcionario.regional ?? "",
                            funcionario: funcionario,
                            isEditando: true,
                            onSaved: { navState.screen = .main }
                        )
                    }
                }

        .sheet(isPresented: $mostrandoProjetos) {
            ProjetosModalView(funcionario: funcionario)
        }

        .onChange(of: funcionario.favorito) { newValue in
            isFavorite = newValue
        }
    }

    // MARK: - PROFILE IMAGE
    private var profileImage: some View {
        ZStack {
            if let data = funcionario.imagem,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                let name = funcionario.nome ?? ""
                let initials = name.split(separator: " ").prefix(2)
                    .map { String($0.prefix(1)).uppercased() }.joined()

                Circle().fill(Color(.systemGray5))
                Text(initials.isEmpty ? "?" : initials)
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.blue.opacity(0.25), lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
    }

    // MARK: - CONTACT GRID
    private var contactGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: 16)],
            spacing: 16
        ) {
            ForEach(contactButtons, id: \.id) { btn in
                Button(action: btn.action) {
                    ZStack {
                        Circle().fill(Color(.systemBackground))
                        if btn.isSystem {
                            Image(systemName: btn.icon)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                                .foregroundColor(btn.tint)
                        } else if let ui = UIImage(named: btn.icon) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .padding(.horizontal,40)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    .shadow(radius: 2)
                }
                .buttonStyle(.plain)
            }

            // ⭐ FAVORITO BUTTON
            Button {
                toggleFavorite(!isFavorite)
            } label: {
                ZStack {
                    Circle().fill(Color(.systemBackground))
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
            }

            // GREEN T (PROJETOS)
            Button {
                mostrandoProjetos = true
            } label: {
                ZStack {
                    Circle().fill(Color.green)
                    Text("T")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - CONTACT BUTTON DEFINITIONS
    private typealias ContactButton = (id: String, icon: String, isSystem: Bool, tint: Color, action: () -> Void)

    private var contactButtons: [ContactButton] {
        var buttons: [ContactButton] = []

        if let phone = funcionario.celular, !phone.isEmpty {

            // WhatsApp
            let hasAsset = UIImage(named: "whatsapp") != nil
            buttons.append((
                "whatsapp",
                hasAsset ? "whatsapp" : "message.circle.fill",
                !hasAsset,
                .green,
                {
                    _ = contactService.contact(.whatsapp,
                                               for: EmployeeContact(name: funcionario.nome, email: funcionario.email, phone: phone),
                                               openURL: { url in openURL(url); return true })
                }
            ))

            // Phone call
            buttons.append((
                "call",
                "phone.circle.fill",
                true,
                .blue,
                {
                    _ = contactService.contact(.call,
                                               for: EmployeeContact(name: funcionario.nome, email: funcionario.email, phone: phone),
                                               openURL: { url in openURL(url); return true })
                }
            ))
        }

        if let email = funcionario.email, !email.isEmpty {
            buttons.append((
                "email",
                "envelope.circle.fill",
                true,
                .red,
                {
                    _ = contactService.contact(.email,
                                               for: EmployeeContact(name: funcionario.nome, email: email, phone: funcionario.celular),
                                               openURL: { url in openURL(url); return true })
                }
            ))
        }

        // Edit button
        buttons.append((
            "edit",
            "pencil.circle.fill",
            true,
            .blue,
            { mostrandoEdicao = true }
        ))

        return buttons
    }

    // MARK: - FAVORITE
    private var favoriteToggle: some View {
        Toggle(isOn: Binding(
            get: { isFavorite },
            set: toggleFavorite(_:))
        ) {
            Label("Favorito", systemImage: "star.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .gray)
                .font(.headline)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .toggleStyle(SwitchToggleStyle(tint: .yellow))
        .padding(.horizontal, 32)
    }

    // MARK: - FAVORITE LOGIC
    private func toggleFavorite(_ newValue: Bool) {
        isFavorite = newValue
        funcionario.favorito = newValue

        do {
            try viewContext.save()
            NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)

            FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: viewContext) { result in
                switch result {
                case .success:
                    print("[Detail] Favorito atualizado")
                case .failure(let error):
                    print("[Detail] Erro ao atualizar favorito: \(error.localizedDescription)")
                }
            }

        } catch {
            print("[Detail] Erro ao salvar favorito: \(error.localizedDescription)")
        }
    }

    // MARK: - DELETE
    private func deleteFuncionario() {
        let idString = funcionario.objectID.uriRepresentation().absoluteString
        // Firebase placeholder
        print("[Firebase] Deleting Funcionario with id: \(idString)")
        // Core Data deletion
        viewContext.delete(funcionario)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("[Detail] Erro ao deletar funcionário: \(error.localizedDescription)")
        }
    }

    // MARK: - INFO BOXES
    private func infoSection(title: String, value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.body.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var emailSection: some View {
        Group {
            if let email = funcionario.email, !email.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text(email)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.blue)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

