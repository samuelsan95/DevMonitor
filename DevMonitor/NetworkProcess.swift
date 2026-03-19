//
//  NetworkProcess.swift
//  DevMonitor
//
//  Created by Samuel Sánchez López on 12/3/26.
//

import Foundation
import SwiftUI

struct NetworkProcess: Identifiable {
    let id = UUID()
    let pid: Int
    let name: String
    let port: Int
    let command: String   // comando completo con el que se lanzó el proceso
    let workDir: String   // directorio de trabajo desde donde se lanzó
    
    var icon: String {
        let n = name.lowercased()
        if n.contains("node") || n.contains("npm")              { return "server.rack" }
        if n.contains("python")                                  { return "terminal" }
        if n.contains("ruby")                                    { return "diamond.fill" }
        if n.contains("java")                                    { return "cup.and.saucer.fill" }
        if n.contains("nginx") || n.contains("httpd")           { return "globe" }
        if n.contains("postgres") || n.contains("mysql")        { return "cylinder.fill" }
        if n.contains("redis")                                   { return "memorychip.fill" }
        if n.contains("docker")                                  { return "shippingbox.fill" }
        return "network"
    }

    var color: Color {
        let n = name.lowercased()
        if n.contains("node") || n.contains("npm")              { return .green }
        if n.contains("python")                                  { return .blue }
        if n.contains("ruby")                                    { return .red }
        if n.contains("java")                                    { return .orange }
        if n.contains("nginx") || n.contains("httpd")           { return .mint }
        if n.contains("postgres")                                { return .indigo }
        if n.contains("mysql")                                   { return .orange }
        if n.contains("redis")                                   { return .red }
        if n.contains("docker")                                  { return .cyan }
        return .purple
    }
}
