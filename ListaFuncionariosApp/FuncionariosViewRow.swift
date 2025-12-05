import SwiftUI
struct FuncionariosViewRow: View {
    let funcionario: Funcionario
    let contactService: ContactService
    let openURL: OpenURLAction
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // 📷 Foto do funcionário
            if let data = funcionario.imagem, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
                    .accessibilityHidden(true)
            }
            
            // 📝 Dados do funcionário
            VStack(alignment: .leading) {
                Text(funcionario.nome ?? "No name").bold()
                Text("Function: \(funcionario.funcao ?? "")")
                Text("Extension: \(funcionario.ramal ?? "")")
                Text("Phone: \(funcionario.celular ?? "")")
                Text("Email: \(funcionario.email ?? "")")
            }
            .accessibilityHidden(true)
            
            Spacer()
            
            // ✏️ Editar / ❌ Deletar
            HStack {
                Button("Edit", action: onEdit)
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Edit employee \(funcionario.nome ?? "")")
                
                Button("Delete", action: onDelete)
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .accessibilityLabel("Delete employee \(funcionario.nome ?? "")")
                    .accessibilityHint("Permanently removes this employee")
            }
            
            // 📞 Contatos
            HStack(spacing: 12) {
                Button {
                    contactService.contact(.call,
                        for: EmployeeContact(name: funcionario.nome,
                                             email: funcionario.email,
                                             phone: funcionario.celular)) { url in
                        let result = openURL(url)
                        return true
                        
                    }
                } label: { Image(systemName: "phone.fill") }
                .accessibilityLabel("Call \(funcionario.nome ?? "")")
                
                Button {
                    contactService.contact(.email,
                        for: EmployeeContact(name: funcionario.nome,
                                             email: funcionario.email,
                                             phone: funcionario.celular)) { url in
                        let result = openURL(url)
                        return true
                    }
                } label: { Image(systemName: "envelope.fill") }
                .accessibilityLabel("Email \(funcionario.nome ?? "")")
                
                Button {
                    contactService.contact(.whatsapp,
                        for: EmployeeContact(name: funcionario.nome,
                                             email: funcionario.email,
                                             phone: funcionario.celular)) { url in
                        let result = openURL(url)
                        return true 
                    }
                } label: { Image(systemName: "message.fill") }
                .accessibilityLabel("WhatsApp \(funcionario.nome ?? "")")
            }
            .buttonStyle(.borderless)
        }
        // 🔑 A célula é um único elemento de acessibilidade
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(funcionario.nome ?? "No name"), function \(funcionario.funcao ?? "not informed"), extension \(funcionario.ramal ?? "not informed"), phone \(funcionario.celular ?? "not informed"), email \(funcionario.email ?? "not informed")"
        )
    }
}
