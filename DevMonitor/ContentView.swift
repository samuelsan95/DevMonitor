//
//  ContentView.swift
//  DevMonitor
//
//  Created by Samuel Sánchez López on 12/3/26.
//

import SwiftUI
import ServiceManagement

struct ContentView: View {
    @State private var monitor = ProcessMonitor()
    @State private var launchAtStartup: Bool = SMAppService.mainApp.status == .enabled
    @State private var showSettings: Bool = false
    @State private var searchText: String = ""
    @State private var showHistory: Bool = false
    
    private var filteredProcesses: [NetworkProcess] {
        if searchText.isEmpty {
            return monitor.processes
        }
        return monitor.processes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            String($0.port).contains(searchText)
        }
    }

    private func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func toggleLaunchAtStartup(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Si falla, revertimos el toggle
            launchAtStartup = !enable
            print("Error al cambiar inicio automático: \(error)")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DevMonitor")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                
                if monitor.autoRefresh {
                    Text("\(Int(monitor.interval))s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button(action: { monitor.toggleAutoRefresh() }) {
                    Image(systemName: monitor.autoRefresh ? "pause.circle.fill" : "play.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(monitor.autoRefresh ? .green : .secondary)

                Button(action: { monitor.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                
                Button(action: { withAnimation { showHistory.toggle(); showSettings = false } }) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(showHistory ? .primary : .secondary)

                Button(action: { withAnimation { showSettings.toggle(); showHistory = false } }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(showSettings ? .primary : .secondary)
                
                // Botón salir
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            .padding()

            Divider()
            
            TextField("Buscar por nombre o puerto...", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            if showHistory {
                // ── Vista de historial ──
                HStack {
                    Text("Historial de sesión")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !monitor.history.isEmpty {
                        Button("Limpiar") { monitor.clearHistory() }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)

                if monitor.history.filter({ !$0.isActive }).isEmpty {
                    Spacer()
                    Text("Ningún servicio detenido todavía")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(monitor.history.filter { !$0.isActive }) { entry in
                        HStack(spacing: 10) {
                            // Dot de estado
                            Circle()
                                .fill(entry.isActive ? Color.green : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .fontWeight(.medium)
                                Text(entry.isActive ? "Activo" : "Detenido")
                                    .font(.caption)
                                    .foregroundStyle(entry.isActive ? .green : .secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(":\(entry.port)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Text("⏱ \(entry.duration)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            // Botón reiniciar — solo visible si está detenido y tenemos comando
                            if !entry.isActive && !entry.command.isEmpty {
                                Button(action: { monitor.restart(entry) }) {
                                    Image(systemName: "play.circle.fill")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.green)
                                .help(entry.command)  // tooltip con el comando completo
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .frame(minWidth: 420, minHeight: 300)
                }
            } else {
                // ── Vista de procesos activos ──
                if filteredProcesses.isEmpty {
                    Spacer()
                    Text("No hay servicios corriendo")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(filteredProcesses) { process in
                        HStack {
                            Image(systemName: process.icon)
                                .foregroundStyle(process.color)
                                .frame(width: 20, height: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(process.name)
                                    .fontWeight(.medium)
                                Text("PID: \(process.pid)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(":\(process.port)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.blue)

                            Button(action: { openInBrowser(port: process.port) }) {
                                Image(systemName: "safari")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)

                            Button("Stop") {
                                monitor.stop(process)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minWidth: 420, minHeight: 300)
                }
            }
        }
        .onAppear {
            monitor.refresh()
        }
        if showSettings {
            Divider()
            
            VStack(spacing: 12) {
                Toggle(isOn: $launchAtStartup) {
                    Label("Iniciar al encender el Mac", systemImage: "power")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .onChange(of: launchAtStartup) { _, enabled in
                    toggleLaunchAtStartup(enabled)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("Intervalo de refresco", systemImage: "clock")
                        .font(.subheadline)

                    Picker("", selection: $monitor.interval) {
                        Text("5s").tag(5.0)
                        Text("10s").tag(10.0)
                        Text("30s").tag(30.0)
                        Text("60s").tag(60.0)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: monitor.interval) { _, _ in
                        monitor.restartTimerIfNeeded()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

