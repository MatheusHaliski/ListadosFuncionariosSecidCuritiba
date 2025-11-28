//
//  FormularioFuncionarioView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 10/09/25.
//

import SwiftUI
import UIKit
// Uses ZoomableScrollView for pinch-to-zoom

struct FormularioFuncionarioView: View {
    let regionais: [String]
    
    @State private var nome = ""
    @State private var funcao = ""
    @State private var regionalSelecionada = ""
    
    @State private var irParaResultado = false
    @FocusState private var focusedField: Field?
    enum Field: Hashable { case nome, funcao }
    @State private var showEmptyFiltersAssistiveText = false
    @AccessibilityFocusState private var focusOnResultsLink: Bool
    
    var body: some View {
        ZoomableScrollView(minZoomScale: 1.0, maxZoomScale: 3.0) {
            Form {
                Section(header:
                    Text("Fill in the fields")
                        .accessibilityAddTraits(.isHeader)
                ) {
                    TextField("Name", text: $nome)
                        .focused($focusedField, equals: .nome)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .funcao }
                        .overlay(alignment: .trailing) {
                            if !nome.isEmpty {
                                Button {
                                    nome.removeAll()
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                }
                                .accessibilityLabel("Clear name")
                                .padding(.trailing, 6)
                            }
                        }
                        .accessibilityLabel("Employee name")
                        .accessibilityHint("Enter the employee's full name")
                    TextField("Function", text: $funcao)
                        .focused($focusedField, equals: .funcao)
                        .submitLabel(.search)
                        .onSubmit { performSearchIfValid() }
                        .overlay(alignment: .trailing) {
                            if !funcao.isEmpty {
                                Button {
                                    funcao.removeAll()
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                }
                                .accessibilityLabel("Clear function")
                                .padding(.trailing, 6)
                            }
                        }
                        .accessibilityLabel("Function or role")
                        .accessibilityHint("Enter the employee's job function")
                    
                    Picker("Region", selection: $regionalSelecionada) {
                        Text("All").tag("")
                        ForEach(regionais, id: \.self) { regional in
                            Text(regional).tag(regional)
                        }
                    }
                    .accessibilityLabel("Region filter")
                    .accessibilityHint("Choose a region to narrow the search results")
                    
                    if showEmptyFiltersAssistiveText {
                        Text("Tip: add a name, function, or choose a region to narrow your search.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Tip: add a name, function, or choose a region to narrow your search")
                    }
                }
                
                Section {
                    Button(action: {
                        hideKeyboard()
                        if filtersAreEmpty() {
                            showEmptyFiltersAssistiveText = true
                            UIAccessibility.post(notification: .announcement, argument: "Please add at least one filter: name, function, or region.")
                        } else {
                            showEmptyFiltersAssistiveText = false
                            irParaResultado = true
                            focusOnResultsLink = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                            Text("Search Employee")
                                .accessibilityHidden(true)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .contentShape(Rectangle())
                    .accessibilityLabel("Search employee")
                    .accessibilityHint("Performs a search with the entered name, function, and region")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("searchEmployeeButton")
                    .disabled(filtersAreEmpty())
                    .tint(.blue)
                }
            }
        }
        .accessibilityLabel("Scrollable form")
        .accessibilityHint("You can pinch with two fingers to zoom the content")
        // 👇 fora do Form, assim não aparece como célula em branco
        .background(
            NavigationLink(
                destination: ResultadoFuncionarioView(
                    nome: nome,
                    regional: regionalSelecionada,
                    funcao: funcao
                ),
                isActive: $irParaResultado
            ) {
                EmptyView()
            }
            .accessibilityLabel("Search results")
            .accessibilityHint("Shows the list of employees that match your filters")
            .accessibilityFocused($focusOnResultsLink)
        )
        .navigationTitle("Form")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Theme", selection: Binding(
                        get: { UserDefaults.standard.string(forKey: "app_theme_preference") ?? "system" },
                        set: { UserDefaults.standard.set($0, forKey: "app_theme_preference") }
                    )) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Theme", systemImage: "moon.circle")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous") { focusedField = .nome }
                    .disabled(focusedField == .nome)
                Button("Next") { focusedField = .funcao }
                    .disabled(focusedField == .funcao)
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
    }
    
    private func filtersAreEmpty() -> Bool {
        nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        funcao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        regionalSelecionada.isEmpty
    }

    private func performSearchIfValid() {
        hideKeyboard()
        if filtersAreEmpty() {
            showEmptyFiltersAssistiveText = true
            UIAccessibility.post(notification: .announcement, argument: "Please add at least one filter: name, function, or region.")
        } else {
            showEmptyFiltersAssistiveText = false
            irParaResultado = true
            focusOnResultsLink = true
        }
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
