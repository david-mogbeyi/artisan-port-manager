import Foundation

struct CommandResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol CommandRunning: Sendable {
    func run(executable: URL, arguments: [String]) async throws -> CommandResult
}

struct CommandRunner: CommandRunning {
    func run(executable: URL, arguments: [String]) async throws -> CommandResult {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            try process.run()
            process.waitUntilExit()
            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
            return CommandResult(
                stdout: String(decoding: output, as: UTF8.self),
                stderr: String(decoding: error, as: UTF8.self),
                exitCode: process.terminationStatus
            )
        }.value
    }
}
