//
//  HistoryEntry.swift
//  DevMonitor
//

import Foundation

struct HistoryEntry: Identifiable {
    let id = UUID()
    let name: String
    let pid: Int
    let port: Int
    let command: String   // comando guardado para poder reiniciar
    let workDir: String   // directorio desde donde se lanzó
    let firstSeen: Date
    var lastSeen: Date
    var isActive: Bool

    /// Tiempo total que lleva/estuvo activo
    var duration: String {
        let seconds = Int(lastSeen.timeIntervalSince(firstSeen))
        if seconds < 60   { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}
