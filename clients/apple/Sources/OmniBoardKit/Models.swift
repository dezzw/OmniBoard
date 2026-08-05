import Foundation

/// Stable item identity: providerInstanceId + localId.
public struct ItemId: Codable, Hashable, Sendable {
    public var providerInstanceId: String
    public var localId: String

    public init(providerInstanceId: String, localId: String) {
        self.providerInstanceId = providerInstanceId
        self.localId = localId
    }

    public var canonical: String { "\(providerInstanceId):\(localId)" }
}

public struct Item: Codable, Sendable, Identifiable {
    public var id: ItemId
    public var type: String
    public var revision: UInt64
    public var updatedAt: String
    public var payload: [String: JSONValue]
    public var render: RenderDocument?
    public var actions: [String]?
    public var tags: [String]?
    public var asOf: String?
    public var staleAfter: String?

    public init(
        id: ItemId,
        type: String,
        revision: UInt64,
        updatedAt: String,
        payload: [String: JSONValue] = [:],
        render: RenderDocument? = nil,
        actions: [String]? = nil,
        tags: [String]? = nil,
        asOf: String? = nil,
        staleAfter: String? = nil
    ) {
        self.id = id
        self.type = type
        self.revision = revision
        self.updatedAt = updatedAt
        self.payload = payload
        self.render = render
        self.actions = actions
        self.tags = tags
        self.asOf = asOf
        self.staleAfter = staleAfter
    }
}

/// Minimal JSON value tree for opaque payloads.
public enum JSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}
