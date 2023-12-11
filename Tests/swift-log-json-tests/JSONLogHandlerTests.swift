import XCTest
@testable import JSONLogging
@testable import Logging

final class JSONLogHandlerTests: XCTestCase, Utilities {
    let logFileName = "JSONLogFile.txt"
    
    func testLogToFileUsingBootstrap() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        print("\(logFileURL)")
        let fileLogger = try JSONLogging(to: logFileURL)
        // Using `bootstrapInternal` so that running `swift test` won't fail. If using this in production code, just use `bootstrap`.
        LoggingSystem.bootstrapInternal(fileLogger.handler)

        let logger = Logger(label: "Test")
        
        // Not really an error.
        logger.error("Test Test Test")
        
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLogToFileAppendsAcrossLoggerCalls() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        print("\(logFileURL)")
        let fileLogger = try JSONLogging(to: logFileURL)
        // Using `bootstrapInternal` so that running `swift test` won't fail. If using this in production code, just use `bootstrap`.
        LoggingSystem.bootstrapInternal(fileLogger.handler)
        let logger = Logger(label: "Test")
        
        // Not really an error.
        logger.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)

        logger.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLogToFileAppendsAcrossConstructorCalls() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        print("\(logFileURL)")
        let fileLogger = try JSONLogging(to: logFileURL)

        let logger1 = Logger(label: "Test", factory: fileLogger.handler)
        logger1.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)
        
        let logger2 = Logger(label: "Test", factory: fileLogger.handler)
        logger2.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    // Adapted from https://nshipster.com/swift-log/
    func testLogToBothFileAndConsole() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONLogging(to: logFileURL)

        LoggingSystem.bootstrap { label in
            let handlers:[LogHandler] = [
                JSONLogHandler(label: label, fileLogger: fileLogger),
                StreamLogHandler.standardOutput(label: label)
            ]

            return MultiplexLogHandler(handlers)
        }
        
        let logger = Logger(label: "Test")
        
        // TODO: Manually check that the output also shows up in the Xcode console.
        logger.error("Test Test Test")
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLoggingUsingLoggerFactoryConstructor() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONLogging(to: logFileURL)

        let logger = Logger(label: "Test", factory: fileLogger.handler)
        
        logger.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)
        
        logger.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLoggingUsingConvenienceMethod() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)

        let logger = try JSONLogging.logger(label: "Foobar", localFile: logFileURL)
        
        logger.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)
        
        logger.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testDecodingLog() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let logger = try {
            var logger = try JSONLogging.logger(label: "Debug", localFile: logFileURL)
            logger.logLevel = .trace
//            logger.handler.metadata["test1"] = "testing1"
//            logger.handler.metadata["test2"] = "testing2"
            return logger
        }()
        
        logger.trace("Test trace")
        logger.debug("Test debug")
        logger.info("Test info")
        logger.notice("Test notice")
        logger.warning("Test warning")
        logger.error("Test error")
        logger.critical("Test critical")
        
        let logs: [JSONLogEntry] = try .fromJSON(url: logFileURL)
        print(logs.json)
    }
    
    func testClearLog() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONLogging(to: logFileURL)
        
        let logger = Logger(label: "Test", factory: fileLogger.handler)
        
        logger.error("Test Test Test")
        logger.error("Test Test Test")
        
        fileLogger.stream.clear()
        
        let logs: [JSONLogEntry] = try .fromJSON(url: logFileURL)
        
        XCTAssert(logs.count == 0)
    }
    
    func testLogTruncate() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONLogging(to: logFileURL, maxEntries: 5)
        
        let logger = Logger(label: "Test", factory: fileLogger.handler)
        
        logger.error("Test Test Test 1")
        logger.warning("Test Test Test 2")
        logger.info("Test Test Test 3")
        logger.debug("Test Test Test 4")
        logger.notice("Test Test Test 5")
        logger.trace("Test Test Test 6")
        logger.critical("Test Test Test 7")
        
        fileLogger.stream.truncate()
        
        let logs: [JSONLogEntry] = try .fromJSON(url: logFileURL)
        
        XCTAssert(logs.count == 5)
    }
    
    func testLogThreading() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        
        let logger = try JSONLogging.logger(label: "Thread", localFile: logFileURL)
        
        DispatchQueue.global().async {
            for i in 1...5 {
                DispatchQueue.global().async {
                    logger.error("Test \(i) 1")
                    logger.error("Test \(i) 2")
                    logger.error("Test \(i) 3")
                }
            }
        }
        
        let _: [JSONLogEntry] = try .fromJSON(url: logFileURL)
    }
    
    func testCreateLog() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let _ = try JSONLogging.logger(label: "Foobar", localFile: logFileURL)
        
        let data = try Data(contentsOf: logFileURL).count
        print("data count = \(data)")
        
        XCTAssert(data > 0)
    }
}

private extension Encodable {
    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
