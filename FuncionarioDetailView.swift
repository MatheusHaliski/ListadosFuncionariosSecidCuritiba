import SwiftUI

struct FuncionarioDetailView: View {
    let funcionario: Funcionario
    let onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                ZStack {
                    if let data = funcionario.imagem, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        let name = (funcionario.nome ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let initials = name.split(separator: " ").prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
                        Circle().fill(Color(.secondarySystemFill))
                        Text(initials.isEmpty ? "?" : initials)
                            .font(.largeTitle.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                Spacer()
            }
            Text(funcionario.nome ?? "Sem nome").font(.title2).fontWeight(.semibold)
            if let funcao = funcionario.funcao { Text(funcao).foregroundColor(.secondary) }
            Divider()
            if let regional = funcionario.regional { Text("Regional: \(regional)") }
            if let ramal = funcionario.ramal, !ramal.isEmpty { Text("Ramal: \(ramal)") }
            if let celular = funcionario.celular, !celular.isEmpty { Text("Celular: \(celular)") }
            if let email = funcionario.email, !email.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "envelope.fill").foregroundStyle(.secondary)
                    Text("Email: \(email)")
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Detalhes")
        .toolbar {
            if let onEdit = onEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Editar", action: onEdit)
                }
            }
        }
    }
}

