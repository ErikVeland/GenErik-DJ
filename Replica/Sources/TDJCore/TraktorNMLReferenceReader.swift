import Foundation

#if canImport(FoundationXML)
    import FoundationXML
#endif

public struct TraktorNMLElement: Codable, Equatable, Sendable {
    public let name: String
    public let attributes: [String: String]
    public fileprivate(set) var text: String
    public fileprivate(set) var children: [TraktorNMLElement]
}

public struct TraktorNMLReferenceSummary: Codable, Equatable, Sendable {
    public let version: String
    public let program: String?
    public let entryCount: Int
}

public struct TraktorNMLReadLimits: Sendable {
    public var maximumBytes = 16 * 1024 * 1024
    public var maximumEntries = 250_000
    public var maximumDepth = 32
    public var maximumNodesPerEntry = 512
    public var maximumAttributesPerNode = 64
    public var maximumTextBytesPerEntry = 64 * 1024
    public init() {}
}

public enum TraktorNMLReadError: Error, Equatable, LocalizedError {
    case invalidDocument, unsupportedEncoding, limitExceeded, declarationsNotAllowed, invalidCompression
    public var errorDescription: String? {
        switch self {
        case .invalidCompression: return "Cannot decompress this NML collection."
        case .invalidDocument: return "Cannot read this NML collection."
        case .unsupportedEncoding: return "Use a UTF-8 NML collection."
        case .limitExceeded: return "The NML collection exceeds the import limits."
        case .declarationsNotAllowed: return "The NML collection contains unsupported declarations."
        }
    }
}

/// Reads raw reference fields. It does not infer track identity, units or musical-key mappings.
public enum TraktorNMLReferenceReader {
    /// Stage each entry privately. Commit only after the complete scan succeeds.
    public static func scan(
        _ data: Data, limits: TraktorNMLReadLimits = .init(),
        checkCancellation: @escaping @Sendable () throws -> Void = {},
        entry: @escaping (TraktorNMLElement) throws -> Void
    ) throws -> TraktorNMLReferenceSummary {
        try checkCancellation()
        guard limits.maximumBytes > 0, limits.maximumEntries > 0, limits.maximumDepth > 0,
            limits.maximumNodesPerEntry > 0, limits.maximumAttributesPerNode > 0, limits.maximumTextBytesPerEntry > 0,
            data.count <= limits.maximumBytes
        else { throw TraktorNMLReadError.limitExceeded }
        // NUL is illegal in UTF-8 XML and can make XMLParser infer UTF-16 or UTF-32.
        guard !data.contains(0), let text = String(data: data, encoding: .utf8) else {
            throw TraktorNMLReadError.unsupportedEncoding
        }
        guard !text.contains("<!DOCTYPE"), !text.contains("<!ENTITY") else {
            throw TraktorNMLReadError.declarationsNotAllowed
        }
        if let range = text.range(of: "<\\?xml[^?]*encoding\\s*=\\s*['\"]([^'\"]+)['\"]", options: .regularExpression) {
            let declaration = String(text[range]).lowercased()
            guard
                declaration.hasSuffix("'utf-8'") || declaration.hasSuffix("\"utf-8\"")
                    || declaration.hasSuffix("'utf8'") || declaration.hasSuffix("\"utf8\"")
            else { throw TraktorNMLReadError.unsupportedEncoding }
        }
        try checkCancellation()
        let delegate = NMLReferenceDelegate(limits: limits, check: checkCancellation, entry: entry)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        let parsed = parser.parse()
        if let error = delegate.failure { throw error }
        guard parsed, delegate.collectionSeen, delegate.path.isEmpty, delegate.nodes.isEmpty,
            let version = delegate.version, delegate.declaredCount.map({ $0 == delegate.count }) ?? true
        else { throw TraktorNMLReadError.invalidDocument }
        try checkCancellation()
        return .init(version: version, program: delegate.program, entryCount: delegate.count)
    }
}

private final class NMLReferenceDelegate: NSObject, XMLParserDelegate {
    let limits: TraktorNMLReadLimits
    let check: @Sendable () throws -> Void
    let entry: (TraktorNMLElement) throws -> Void
    var path: [String] = []
    var nodes: [TraktorNMLElement] = []
    var version: String?, program: String?, declaredCount: Int?
    var collectionSeen = false
    var count = 0, nodeCount = 0, textBytes = 0
    var failure: (any Error)?
    init(
        limits: TraktorNMLReadLimits, check: @escaping @Sendable () throws -> Void,
        entry: @escaping (TraktorNMLElement) throws -> Void
    ) {
        self.limits = limits
        self.check = check
        self.entry = entry
    }
    func run(_ parser: XMLParser, _ work: () throws -> Void) {
        guard failure == nil else { return }
        do {
            try check()
            try work()
        } catch {
            failure = error
            parser.abortParsing()
        }
    }
    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String]
    ) {
        run(parser) {
            guard path.count < limits.maximumDepth, attributes.count <= limits.maximumAttributesPerNode else {
                throw TraktorNMLReadError.limitExceeded
            }
            if path.isEmpty {
                guard name == "NML", let value = attributes["VERSION"], !value.isEmpty else {
                    throw TraktorNMLReadError.invalidDocument
                }
                version = value
            } else if path == ["NML"], name == "HEAD" {
                program = attributes["PROGRAM"]
            } else if path == ["NML"], name == "COLLECTION" {
                guard !collectionSeen else { throw TraktorNMLReadError.invalidDocument }
                collectionSeen = true
                if let value = attributes["ENTRIES"] {
                    guard let number = Int(value), number >= 0 else { throw TraktorNMLReadError.invalidDocument }
                    guard number <= limits.maximumEntries else { throw TraktorNMLReadError.limitExceeded }
                    declaredCount = number
                }
            }
            if path == ["NML", "COLLECTION"], name == "ENTRY" {
                guard count < limits.maximumEntries else { throw TraktorNMLReadError.limitExceeded }
                nodeCount = 0
                textBytes = 0
                nodes.append(.init(name: name, attributes: attributes, text: "", children: []))
                nodeCount += 1
            } else if !nodes.isEmpty {
                guard nodeCount < limits.maximumNodesPerEntry else { throw TraktorNMLReadError.limitExceeded }
                nodes.append(.init(name: name, attributes: attributes, text: "", children: []))
                nodeCount += 1
            }
            path.append(name)
        }
    }
    func parser(_ parser: XMLParser, foundCharacters value: String) {
        run(parser) {
            guard !nodes.isEmpty else { return }
            let size = value.utf8.count
            guard size <= limits.maximumTextBytesPerEntry - textBytes else { throw TraktorNMLReadError.limitExceeded }
            textBytes += size
            nodes[nodes.count - 1].text += value
        }
    }
    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        guard let value = String(data: data, encoding: .utf8) else {
            failure = TraktorNMLReadError.unsupportedEncoding
            parser.abortParsing()
            return
        }
        self.parser(parser, foundCharacters: value)
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        run(parser) {
            guard path.last == name else { throw TraktorNMLReadError.invalidDocument }
            if !nodes.isEmpty {
                let node = nodes.removeLast()
                if nodes.isEmpty {
                    try entry(node)
                    count += 1
                } else {
                    nodes[nodes.count - 1].children.append(node)
                }
            }
            path.removeLast()
        }
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { nil }
}
