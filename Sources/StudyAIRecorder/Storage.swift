import Foundation

struct DataStore {
    let folderURL: URL
    let databaseURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        folderURL = support.appendingPathComponent("StudyAIRecorder", isDirectory: true)
        databaseURL = folderURL.appendingPathComponent("database.json")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func load() -> AppDatabase {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return .starter
        }

        do {
            let data = try Data(contentsOf: databaseURL)
            return try JSONDecoder.study.decode(AppDatabase.self, from: data)
        } catch {
            return .starter
        }
    }

    func save(_ database: AppDatabase) {
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let data = try JSONEncoder.study.encode(database)
            try data.write(to: databaseURL, options: .atomic)
        } catch {
            NSLog("StudyAIRecorder save failed: \(error.localizedDescription)")
        }
    }
}

extension JSONEncoder {
    static var study: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var study: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
