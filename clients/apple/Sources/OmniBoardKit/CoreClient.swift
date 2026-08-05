import Foundation
import Network

/// Client Protocol over Unix domain socket (Content-Length framed JSON-RPC).
public final class CoreClient: @unchecked Sendable {
    public let socketPath: String
    private let queue = DispatchQueue(label: "omniboard.core-client")

    public init(socketPath: String = "/tmp/omniboard.sock") {
        self.socketPath = socketPath
    }

    public func ping() async throws -> Bool {
        let result = try await request(method: "ping", params: [:])
        return result["ok"]?.boolValue == true
    }

    public func listItems(providerInstanceId: String) async throws -> [Item] {
        let result = try await request(
            method: "items/list",
            params: ["providerInstanceId": .string(providerInstanceId)]
        )
        guard case .array(let arr)? = result["items"] else { return [] }
        let data = try JSONEncoder().encode(arr)
        return try JSONDecoder().decode([Item].self, from: data)
    }

    public func getItem(id: ItemId) async throws -> Item? {
        let result = try await request(
            method: "items/get",
            params: [
                "id": .object([
                    "providerInstanceId": .string(id.providerInstanceId),
                    "localId": .string(id.localId),
                ])
            ]
        )
        guard let itemVal = result["item"], itemVal != .null else { return nil }
        let data = try JSONEncoder().encode(itemVal)
        return try JSONDecoder().decode(Item.self, from: data)
    }

    private func request(method: String, params: [String: JSONValue]) async throws -> [String: JSONValue] {
        let id = Int.random(in: 1...1_000_000)
        let envelope: [String: JSONValue] = [
            "jsonrpc": .string("2.0"),
            "id": .number(Double(id)),
            "method": .string(method),
            "params": .object(params),
        ]
        let body = try JSONEncoder().encode(envelope)
        let frame = Self.encodeFrame(body)
        let responseData = try await send(frame: frame)
        let response = try JSONDecoder().decode([String: JSONValue].self, from: responseData)
        if let error = response["error"] {
            throw CoreClientError.remote(String(describing: error))
        }
        guard case .object(let result)? = response["result"] else {
            throw CoreClientError.invalidResponse
        }
        return result
    }

    private func send(frame: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let endpoint = NWEndpoint.unix(path: socketPath)
            let connection = NWConnection(to: endpoint, using: .tcp)
            let box = FrameBuffer()
            var resumed = false

            func finish(_ result: Result<Data, Error>) {
                queue.async {
                    guard !resumed else { return }
                    resumed = true
                    connection.cancel()
                    continuation.resume(with: result)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: frame, completion: .contentProcessed { error in
                        if let error {
                            finish(.failure(error))
                        }
                    })
                    self.receive(connection: connection, box: box, finish: finish)
                case .failed(let error):
                    finish(.failure(error))
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
    }

    private func receive(
        connection: NWConnection,
        box: FrameBuffer,
        finish: @escaping (Result<Data, Error>) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { content, _, isComplete, error in
            if let error {
                finish(.failure(error))
                return
            }
            if let content {
                box.append(content)
                if let body = box.nextFrame() {
                    finish(.success(body))
                    return
                }
            }
            if isComplete {
                finish(.failure(CoreClientError.invalidResponse))
                return
            }
            self.receive(connection: connection, box: box, finish: finish)
        }
    }

    private static func encodeFrame(_ body: Data) -> Data {
        var data = Data("Content-Length: \(body.count)\r\n\r\n".utf8)
        data.append(body)
        return data
    }
}

private final class FrameBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        lock.unlock()
    }

    func nextFrame() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard let sep = "\r\n\r\n".data(using: .utf8) else { return nil }
        guard let range = buffer.range(of: sep) else { return nil }
        let header = buffer.subdata(in: 0..<range.lowerBound)
        guard let headerStr = String(data: header, encoding: .utf8) else { return nil }
        var length: Int?
        for line in headerStr.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                length = Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        guard let length else { return nil }
        let bodyStart = range.upperBound
        let bodyEnd = bodyStart + length
        guard buffer.count >= bodyEnd else { return nil }
        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        buffer.removeSubrange(0..<bodyEnd)
        return body
    }
}

public enum CoreClientError: Error, Sendable {
    case remote(String)
    case invalidResponse
}

private extension JSONValue {
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
