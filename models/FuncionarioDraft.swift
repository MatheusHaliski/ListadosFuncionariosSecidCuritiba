//
//  FuncionarioDraft.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 03/12/25.
//


import Foundation

public struct FuncionarioDraft: Hashable, Codable {
    public var nome: String = ""
    public var email: String = ""
    public var celular: String = ""
    public var favorito: Bool = false
    public var regional: String = ""
    public var funcao: String = ""
    public var ramal: String = ""

    public init() {}
}