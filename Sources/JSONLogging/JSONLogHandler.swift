//
//  File.swift
//  
//
//  Created by Dana Buehre on 12/8/23.
//

import Logging
import Foundation

public struct JSONLogging {
    public let stream: JSONHandlerOutputStream
    private var localFile: URL
    
    public init(to localFile: URL, maxEntries: Int = 2000) throws {
        self.stream = try JSONHandlerOutputStream(localFile: localFile, maxEntries: maxEntries)
        self.localFile = localFile
    }
    
    public func handler(label: String) -> JSONLogHandler {
        return JSONLogHandler(label: label, fileLogger: self)
    }
    
    public static func logger(label: String, localFile url: URL, maxEntries: Int = 2000) throws -> Logger {
        let logging = try JSONLogging(to: url, maxEntries: maxEntries)
        return Logger(label: label, factory: logging.handler)
    }
}

// Adapted from https://github.com/apple/swift-log.git
        
/// `FileLogHandler` is a simple implementation of `LogHandler` for directing
/// `Logger` output to a local file. Appends log output to this file, even across constructor calls.
public struct JSONLogHandler: LogHandler {
    private let stream: JSONHandlerOutputStream
    private var label: String
    
    public var logLevel: Logger.Level = .info

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }
    
    public init(label: String, fileLogger: JSONLogging, logLevel: Logger.Level = .info) {
        self.label = label
        self.stream = fileLogger.stream
        self.logLevel = logLevel
    }

    public init(label: String, localFile url: URL, logLevel: Logger.Level = .info, maxEntries: Int = 2000) throws {
        self.label = label
        self.stream = try JSONHandlerOutputStream(localFile: url, maxEntries: maxEntries)
        self.logLevel = logLevel
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true
            ? self.prettyMetadata
            : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))

        stream.write(JSONLogEntry(
            date: Date(),
            level: level.rawValue,
            category: self.label,
            message: "\((prettyMetadata != nil) ? "\(prettyMetadata!) " : "")\(message)"
        ))
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }
}

public struct JSONLogEntry: Codable, Hashable {
    public let date: Date
    public let level: String
    public let category: String
    public let message: String
    
    public var composedMessage: String {
        "[\(date)] [\(level)] [\(category)] \(message)"
    }
}

public extension Sequence where Element == JSONLogEntry {
    static func fromJSON(url: URL) throws -> [JSONLogEntry] {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: url)
        return try decoder.decode([JSONLogEntry].self, from: data)
    }
}
