import Foundation
import Observation

@Observable
@MainActor
class ProcessMonitor {
    var processes: [NetworkProcess] = []
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
                let output = self.runShell("lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null")
                let result = self.parseOutput(output)
                continuation.resume(returning: result)
            }
        }
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

    nonisolated private func parseOutput(_ output: String) -> [NetworkProcess] {
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

            result.append(NetworkProcess(pid: pid, name: name, port: port))
        }
        return result.sorted { $0.port < $1.port }
    }
}
