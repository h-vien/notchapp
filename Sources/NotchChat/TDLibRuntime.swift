import Darwin
import Foundation

final class TDLibRuntime: @unchecked Sendable {
    typealias CreateClient = @convention(c) () -> Int32
    typealias Send = @convention(c) (Int32, UnsafePointer<CChar>) -> Void
    typealias Receive = @convention(c) (Double) -> UnsafePointer<CChar>?

    let createClient: CreateClient
    let sendFunction: Send
    let receiveFunction: Receive
    private let handle: UnsafeMutableRawPointer

    init() throws {
        let candidates = Self.libraryCandidates()
        var loaded: UnsafeMutableRawPointer?
        var attempted: [String] = []
        for path in candidates {
            attempted.append(path)
            if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) {
                loaded = handle
                break
            }
        }
        guard let loaded else {
            throw RuntimeError.libraryMissing(attempted)
        }
        handle = loaded
        createClient = try Self.symbol("td_create_client_id", from: loaded, as: CreateClient.self)
        sendFunction = try Self.symbol("td_send", from: loaded, as: Send.self)
        receiveFunction = try Self.symbol("td_receive", from: loaded, as: Receive.self)
    }

    deinit { dlclose(handle) }

    func send(clientID: Int32, object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let json = String(data: data, encoding: .utf8) else { throw RuntimeError.invalidJSON }
        json.withCString { sendFunction(clientID, $0) }
    }

    func receive(timeout: Double) -> Data? {
        guard let pointer = receiveFunction(timeout) else { return nil }
        return Data(bytes: pointer, count: strlen(pointer))
    }

    private static func libraryCandidates() -> [String] {
        var paths: [String] = []
        if let explicit = ProcessInfo.processInfo.environment["TDJSON_PATH"] { paths.append(explicit) }
        if let frameworks = Bundle.main.privateFrameworksURL?.path {
            paths.append((frameworks as NSString).appendingPathComponent("libtdjson.dylib"))
        }
        paths.append(FileManager.default.currentDirectoryPath + "/.build/tdlib/libtdjson.dylib")
        paths.append("/opt/homebrew/lib/libtdjson.dylib")
        paths.append("/usr/local/lib/libtdjson.dylib")
        return paths
    }

    private static func symbol<T>(_ name: String, from handle: UnsafeMutableRawPointer, as type: T.Type) throws -> T {
        guard let raw = dlsym(handle, name) else { throw RuntimeError.symbolMissing(name) }
        return unsafeBitCast(raw, to: type)
    }

    enum RuntimeError: LocalizedError {
        case libraryMissing([String])
        case symbolMissing(String)
        case invalidJSON

        var errorDescription: String? {
            switch self {
            case .libraryMissing: "TDLib is not bundled with this build. Run scripts/build-app.sh."
            case let .symbolMissing(name): "TDLib is missing required symbol \(name)."
            case .invalidJSON: "Could not encode a Telegram request."
            }
        }
    }
}

