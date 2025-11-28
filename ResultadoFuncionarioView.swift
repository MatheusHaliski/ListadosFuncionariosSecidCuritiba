import SwiftUI
import CoreData
import UIKit

struct ResultadoFuncionarioView: View {
    let nome: String
    let regional: String
    let funcao: String
    
    @StateObject private var viewModel = FuncionarioViewModel()
    
    @Environment(\.openURL) private var openURL
    private let contactService: ContactService = DefaultContactService.shared
    
    private var resultadosFiltrados: [Funcionario] {
        viewModel.funcionarios.filter { funcionario in
            let nomeMatch = nome.isEmpty || (funcionario.nome ?? "").localizedCaseInsensitiveContains(nome)
            let funcaoMatch = funcao.isEmpty || (funcionario.funcao ?? "").localizedCaseInsensitiveContains(funcao)
            let regionalMatch = regional.isEmpty || (funcionario.regional ?? "") == regional
            return nomeMatch && funcaoMatch && regionalMatch
        }
    }

    private var groupedByRegion: [(region: String, employees: [Funcionario])] {
        let groups = Dictionary(grouping: resultadosFiltrados) { (f: Funcionario) -> String in
            let r = (f.regional ?? "")
            return r.isEmpty ? "—" : r
        }
        return groups.keys.sorted().map { key in
            (region: key, employees: groups[key] ?? [])
        }
    }

    private var regionIndexTitles: [String] {
        groupedByRegion.map { $0.region }
    }
    
    var body: some View {
        ZoomableScrollView(minZoomScale: 1.0, maxZoomScale: 3.0) {
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    List {
                        ForEach(groupedByRegion, id: \.region) { group in
                            Section(header: Text("\(group.region) • \(group.employees.count)")) {
                                ForEach(group.employees, id: \.objectID) { (funcionario: Funcionario) in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(funcionario.nome ?? "Sem nome")
                                            .fontWeight(.bold)
                                        Text("Função: \(funcionario.funcao ?? "")")
                                        Text("Regional: \(funcionario.regional ?? "")")
                                        Text("Email: \(funcionario.email ?? "")")
                                            .foregroundColor(.blue)
                                            .font(.footnote)

                                        HStack(spacing: 12) {
                                            if let celular = funcionario.celular {
                                                Button {
                                                    contactService.contact(
                                                        .call,
                                                        for: EmployeeContact(name: funcionario.nome,
                                                                             email: funcionario.email,
                                                                             phone: celular),
                                                        openURL: { (url: URL) -> Bool in
                                                            openURL(url)
                                                            return true
                                                        }
                                                    )
                                                } label: {
                                                    Image(systemName: "phone.fill")
                                                }
                                            }

                                            if let email = funcionario.email {
                                                Button {
                                                    contactService.contact(
                                                        .email,
                                                        for: EmployeeContact(name: funcionario.nome,
                                                                             email: email,
                                                                             phone: funcionario.celular),
                                                        openURL: { (url: URL) -> Bool in
                                                            openURL(url)
                                                            return true
                                                        }
                                                    )
                                                } label: {
                                                    Image(systemName: "envelope.fill")
                                                }
                                            }

                                            if let celular = funcionario.celular {
                                                Button {
                                                    contactService.contact(
                                                        .whatsapp,
                                                        for: EmployeeContact(name: funcionario.nome,
                                                                             email: funcionario.email,
                                                                             phone: celular),
                                                        openURL: { (url: URL) -> Bool in
                                                            openURL(url)
                                                            return true
                                                        }
                                                    )
                                                } label: {
                                                    Image(systemName: "message.fill")
                                                }
                                            }
                                        }
                                        .foregroundColor(.blue)
                                        .font(.footnote)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .id(group.region)
                        }
                    }

                    // Fast region index on the right
                    if regionIndexTitles.count > 1 {
                        VStack(spacing: 6) {
                            ForEach(regionIndexTitles, id: \.self) { title in
                                Button(action: { withAnimation { proxy.scrollTo(title, anchor: .top) } }) {
                                    Text(String(title.prefix(3)))
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                                }
                                .accessibilityLabel("Jump to region \(title)")
                            }
                        }
                        .padding(.trailing, 6)
                    }
                }
            }
        }
        .navigationTitle("Search Results")
        .onAppear {
            viewModel.fetchFuncionarios()
        }
    }
}
