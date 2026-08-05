import Foundation

/// Declarative Render IR document (docs/architecture/05-rendering-schema.md).
public struct RenderDocument: Codable, Sendable {
    public var schemaVersion: String
    public var surfaceHints: [String]?
    public var root: RenderNode

    public init(schemaVersion: String, surfaceHints: [String]? = nil, root: RenderNode) {
        self.schemaVersion = schemaVersion
        self.surfaceHints = surfaceHints
        self.root = root
    }
}

/// Node tree is a class so recursion (children / fallback / switches) is allowed.
public final class RenderNode: Codable, @unchecked Sendable {
    public var type: String
    public var value: String?
    public var key: String?
    public var style: String?
    public var name: String?
    public var accessibilityLabel: String?
    public var children: [RenderNode]?
    public var actionId: String?
    public var label: RenderLabel?
    public var cases: [String: RenderNode]?
    public var defaultNode: RenderNode?
    public var fallback: RenderNode?
    public var primary: RenderNode?
    public var instant: String?

    public init(type: String) {
        self.type = type
    }

    private enum CodingKeys: String, CodingKey {
        case type, value, key, style, name, accessibilityLabel
        case children, actionId, label, cases
        case defaultNode = "default"
        case fallback, primary, instant
    }
}

public enum RenderLabel: Codable, Sendable {
    case text(String)
    case keyed(key: String)

    public init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(s)
            return
        }
        let obj = try decoder.container(keyedBy: CodingKeys.self)
        if let key = try obj.decodeIfPresent(String.self, forKey: .key) {
            self = .keyed(key: key)
            return
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Invalid label")
        )
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .keyed(let key):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(key, forKey: .key)
        }
    }

    private enum CodingKeys: String, CodingKey { case key }

    public var display: String {
        switch self {
        case .text(let s): return s
        case .keyed(let key): return key
        }
    }
}
