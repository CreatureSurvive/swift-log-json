# swift-log-json

A swift-log backend for storing logs in a json file

[SwiftLog](https://github.com/apple/swift-log) compatible file log handler.

## Example: Just logging to a file

```swift
let logFileURL = URL(/* your local log file here */)
let logger = try JSONLogging.logger(label: "Foobar", localFile: logFileURL)
logger.error("Test Test Test")
```

## Example: Logging to both the standard output (Xcode console if using Xcode) and a file.

```swift
let logFileURL = URL(/* your local log file here */)
let fileLogger = try JSONLogging(to: logFileURL)

LoggingSystem.bootstrap { label in
    let handlers:[LogHandler] = [
        JSONLogHandler(label: label, fileLogger: fileLogger),
        StreamLogHandler.standardOutput(label: label)
    ]

    return MultiplexLogHandler(handlers)
}

let logger = Logger(label: "Test")
```

Note in that last example, if you use `LoggingSystem.bootstrap`, make sure to create your `Logger` *after* the  `LoggingSystem.bootstrap` usage (or you won't get the effects of the `LoggingSystem.bootstrap`).

## Example: Reading the log file

```swift
let logFileURL = URL(/* your local log file here */)
let logs: [JSONLogEntry] = try .fromJSON(url: logFileURL)

for log in logs {
    log.date // do something with the log date
    log.category // do something with the log category
    log.level // do something with the log level
    log.message // do something with the log message
}
```

For more examples, see the unit tests and refer to [apple/swift-log's README](https://github.com/apple/swift-log#the-core-concepts)
