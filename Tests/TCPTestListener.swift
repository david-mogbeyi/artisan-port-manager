import Darwin
import Foundation

/// A bare TCP listener on an ephemeral loopback port that accepts connections but never
/// writes a response. Used to prove the prober reports `.tcpOnly` for a socket that is
/// open but does not speak HTTP.
final class TCPTestListener {
    let port: Int
    private let descriptor: Int32
    private var accepting = true
    private let queue = DispatchQueue(label: "TCPTestListener")

    init() throws {
        // Bind through a local descriptor: the stored properties cannot be referenced from
        // the pointer closures until every member is initialized.
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure.socketUnavailable }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0 // let the kernel pick a free port
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 4) == 0 else {
            close(fd)
            throw Failure.bindFailed
        }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard named == 0 else {
            close(fd)
            throw Failure.bindFailed
        }

        descriptor = fd
        port = Int(assigned.sin_port.bigEndian)
        queue.async { [weak self] in
            while self?.accepting == true {
                let client = accept(fd, nil, nil)
                guard client >= 0 else { return }
                // Hold the connection open briefly without responding, then drop it.
                Thread.sleep(forTimeInterval: 0.2)
                close(client)
            }
        }
    }

    func stop() {
        accepting = false
        close(descriptor)
    }

    enum Failure: Error {
        case socketUnavailable
        case bindFailed
    }
}
