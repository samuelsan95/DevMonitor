import Foundation
import Observation

@Observable
@MainActor
class ProcessMonitor {
    var processes: [NetworkProcess] = []
    var history: [HistoryEntry] = []
    var autoRefresh: Bool = false {
        didSet { UserDefaults.standard.set(autoRefresh, forKey: "autoRefresh") }
    }

    var interval: TimeInterval = 5 {
        didSet { UserDefaults.standard.set(interval, forKey: "interval") }
    }

    private var timerTask: Task<Void, Never>?
    
    init() {
        if UserDefaults.standard.object(forKey: "interval") != nil {
            interval = UserDefaults.standard.double(forKey: "interval")
        }
        autoRefresh = UserDefaults.standard.bool(forKey: "autoRefresh")
    }

    func refresh() {
        Task {
            let result = await fetchProcesses()
            processes = result
            updateHistory(with: result)
        }
    }

    func clearHistory() {
        history.removeAll()
    }

    // MARK: - Historia

    /// Compara los procesos nuevos con el historial y lo actualiza
    private func updateHistory(with current: [NetworkProcess]) {
        let now = Date()

        // Marca todos como inactivos; luego los activos los reactivamos
        for i in history.indices {
            history[i].isActive = false
        }

        for process in current {
            // Buscamos si ya existe una entrada para este puerto
            if let idx = history.firstIndex(where: { $0.port == process.port }) {
                // Ya existía → actualizamos lastSeen y lo marcamos activo
                history[idx].lastSeen = now
                history[idx].isActive = true
            } else {
                // Es nuevo → lo añadimos al historial
                let entry = HistoryEntry(
                    name: process.name,
                    pid: process.pid,
                    port: process.port,
                    command: process.command,
                    workDir: process.workDir,
                    firstSeen: now,
                    lastSeen: now,
                    isActive: true
                )
                history.append(entry)
            }
        }

        // Orden: activos primero, luego por hora de aparición más reciente
        history.sort {
            if $0.isActive != $1.isActive { return $0.isActive }
            return $0.firstSeen > $1.firstSeen
        }
    }

    func toggleAutoRefresh() {
        autoRefresh.toggle()
        autoRefresh ? startTimer() : stopTimer()
    }

    func restartTimerIfNeeded() {
        if autoRefresh { startTimer() }
    }

    func stop(_ process: NetworkProcess) {
        runShell("kill -9 \(process.pid)")
        refresh()
    }

    /// Abre Terminal, se mueve al directorio original y ejecuta el comando
    func restart(_ entry: HistoryEntry) {
        guard !entry.command.isEmpty else { return }

        let tempPath = "/tmp/devmonitor_restart_\(entry.port).sh"

        // Si tenemos el directorio de trabajo, hacemos cd antes de ejecutar
        let cdLine   = entry.workDir.isEmpty ? "" : "cd \"\(entry.workDir)\"\n"
        let script   = "#!/bin/zsh\n\(cdLine)\(entry.command)\n"

        try? script.write(toFile: tempPath, atomically: true, encoding: .utf8)
        runShell("chmod +x \(tempPath)")
        runShell("open -a Terminal \(tempPath)")
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if !Task.isCancelled { refresh() }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func fetchProcesses() async -> [NetworkProcess] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let lsofOutput = self.runShell("lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null")

                // Extraemos los PIDs que ya tenemos de lsof y consultamos SOLO esos.
                // Evitamos "ps -ax" (todos los procesos del sistema) que puede bloquearse
                // en apps sandboxed o requerir permisos extra.
                let pids = self.extractPIDs(from: lsofOutput)
                var commands: [Int: String] = [:]
                var workDirs: [Int: String] = [:]
                if !pids.isEmpty {
                    let pidList  = pids.map { "\($0)" }.joined(separator: ",")
                    // Comandos completos
                    let psOutput  = self.runShell("ps -p \(pidList) -o pid= -o args=")
                    commands      = self.parseCommands(psOutput)
                    // Directorios de trabajo: lsof -d cwd devuelve líneas "p<pid>" y "n<path>"
                    let cwdOutput = self.runShell("lsof -a -p \(pidList) -d cwd -Fn 2>/dev/null")
                    workDirs      = self.parseWorkDirs(cwdOutput)
                }

                let result = self.parseOutput(lsofOutput, commands: commands, workDirs: workDirs)
                continuation.resume(returning: result)
            }
        }
    }

    /// Extrae los PIDs únicos de la salida de lsof
    nonisolated private func extractPIDs(from output: String) -> [Int] {
        var pids: [Int] = []
        var seen = Set<Int>()
        for line in output.components(separatedBy: "\n").dropFirst() {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 2, let pid = Int(cols[1]), !seen.contains(pid) else { continue }
            seen.insert(pid)
            pids.append(pid)
        }
        return pids
    }

    /// Parsea "lsof -d cwd -Fn" → [pid: path]
    /// Formato de salida: líneas alternadas "p<pid>" y "n<path>"
    nonisolated private func parseWorkDirs(_ output: String) -> [Int: String] {
        var dict: [Int: String] = [:]
        var currentPid: Int?
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("p"), let pid = Int(line.dropFirst()) {
                currentPid = pid
            } else if line.hasPrefix("n"), let pid = currentPid {
                dict[pid] = String(line.dropFirst())
                currentPid = nil
            }
        }
        return dict
    }

    /// Convierte la salida de `ps` en un diccionario [pid: comando]
    nonisolated private func parseCommands(_ output: String) -> [Int: String] {
        var dict: [Int: String] = [:]
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // El formato es: "<pid> <comando con args>"
            if let spaceIdx = trimmed.firstIndex(of: " ") {
                let pidStr  = String(trimmed[trimmed.startIndex..<spaceIdx])
                let command = String(trimmed[trimmed.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
                if let pid = Int(pidStr) { dict[pid] = command }
            }
        }
        return dict
    }

    @discardableResult
    nonisolated private func runShell(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try? task.run()
        task.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    nonisolated private func parseOutput(_ output: String, commands: [Int: String] = [:], workDirs: [Int: String] = [:]) -> [NetworkProcess] {
        var seen = Set<Int>()
        var result: [NetworkProcess] = []
        let lines = output.components(separatedBy: "\n").dropFirst()

        for line in lines {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 9 else { continue }

            let name    = String(columns[0])
            guard let pid = Int(columns[1]) else { continue }
            let address = String(columns[8])

            guard let portString = address.split(separator: ":").last,
                  let port = Int(portString) else { continue }

            guard !seen.contains(pid) else { continue }
            seen.insert(pid)

            let command = commands[pid] ?? ""
            let workDir = workDirs[pid] ?? ""
            result.append(NetworkProcess(pid: pid, name: name, port: port, command: command, workDir: workDir))
        }
        return result.sorted { $0.port < $1.port }
    }
}
