//
//  JSONFileHandlerOutputStream.swift
//
//
//  Created by Dana Buehre on 12/8/23.
//

import Foundation

public struct JSONHandlerOutputStream: TextOutputStream {
    public enum FileHandlerOutputStream: Error {
        case couldNotCreateFile
    }

    public enum FlushMode: Sendable {
        case always
        case manual
    }
    
    private let queue = DispatchQueue(label: "JSONFileHandlerOutputStream.queue", attributes: .concurrent)
    private let fileHandle: FileHandle
    private let encoder = JSONEncoder()

    let maxEntries: Int
    let url: URL
    let flushMode: FlushMode

    init(localFile url: URL, maxEntries: Int = 2000, flushMode: FlushMode = .always) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            let contents = try encoder.encode([] as [JSONLogEntry])
            guard FileManager.default.createFile(atPath: url.path, contents: contents, attributes: nil) else {
                throw FileHandlerOutputStream.couldNotCreateFile
            }
        }

        self.url = url
        self.maxEntries = maxEntries
        self.fileHandle = try FileHandle(forWritingTo: url)
        self.flushMode = flushMode
        
        if try fileHandle._seekToEnd() < 9 {
            try fileHandle._truncate(atOffset: 0)
            try fileHandle._write(try encoder.encode([] as [JSONLogEntry]))
        }
        
        try fileHandle._seek(offsetFromEnd: 1)
    
        self.truncate()
    }
    
    /// append the string to the log file
    public func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            queue.async(flags: .barrier) {
                defer {
                    if flushMode == .always {
                        try? fileHandle._synchronize()
                    }
                }
                
                try? fileHandle._write(data)
            }
        }
    }
    
    /// append a `LogFile.Log` to the `LogFile`
    public func write(_ log: JSONLogEntry) {
        if let data = try? encoder.encode(log),
           let string = String(data: data, encoding: .utf8) {
            
            queue.async(flags: .barrier) {
                defer {
                    if flushMode == .always {
                        try? fileHandle._synchronize()
                    }
                }
                
                try? fileHandle._seek(offsetFromEnd: 1)
                
                if let offset = try? fileHandle._offset(),
                   let data = ((offset > 9 ? "," : "") + string + "]").data(using: .utf8) {
                    try? fileHandle._write(data)
                    try? fileHandle._seek(offsetFromEnd: 1)
                }
            }
        }
    }
    
    /// clears the `LogFile`
    public func clear() {
        if let contents = try? encoder.encode([] as [JSONLogEntry]) {
            
            queue.async(flags: .barrier) {
                defer {
                    if flushMode == .always {
                        try? fileHandle._synchronize()
                    }
                }
                
                try? fileHandle._truncate(atOffset: 0)
                try? fileHandle._write(contents)
                try? fileHandle._seek(offsetFromEnd: 1)
            }
        }
    }
    
    /// truncates the `LogFile.logs` to `maxEntries`
    public func truncate() {
        if let logs: [JSONLogEntry] = try? .fromJSON(url: url),
           (logs.count - maxEntries) > 0 {
            
            queue.async(flags: .barrier) {
                defer {
                    if flushMode == .always {
                        try? fileHandle._synchronize()
                    }
                }
    
                let logs = Array(logs.suffix(maxEntries))
                try? encoder.encode(logs).write(to: url)
                try? fileHandle._seek(offsetFromEnd: 1)
            }
        }
    }
    
    /// flush the fileHandle available data to the log file
    private func flush() {
        queue.async(flags: .barrier) {
            try? fileHandle._synchronize()
        }
    }
    
    /// flush the fileHandle available data to the log file and close the file handle
    private func close() {
        queue.async(flags: .barrier) {
            try? fileHandle._synchronize()
            try? fileHandle._close()
        }
    }
}

private extension FileHandle {
    
    func _truncate(atOffset: UInt64) throws {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            return try truncate(atOffset: atOffset)
        } else {
            return truncateFile(atOffset: atOffset)
        }
    }
    
    func _offset() throws -> UInt64 {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            return try offset()
        } else {
            return offsetInFile
        }
    }
    
    @discardableResult func _seekToEnd() throws -> UInt64 {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            return try seekToEnd()
        } else {
            return seekToEndOfFile()
        }
    }
    
    func _seek(toOffset: UInt64) throws {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            return try seek(toOffset: toOffset)
        } else {
            return seek(toFileOffset: toOffset)
        }
    }
    
    func _seek(offsetFromEnd: UInt64) throws {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            return try seek(toOffset: seekToEnd() - offsetFromEnd)
        } else {
            return seek(toFileOffset: seekToEndOfFile() - offsetFromEnd)
        }
    }

    func _write(_ data: Data) throws {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            try write(contentsOf: data)
        } else {
            write(data)
        }
    }
    
    func _synchronize() throws {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            try synchronize()
        } else {
            synchronizeFile()
        }
    }
    
    func _close() throws {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            try close()
        } else {
            closeFile()
        }
    }
}
