import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Vision

@MainActor
final class ActivityMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var latestSample: ActivitySample?
    @Published private(set) var lastError: String?

    private var timer: Timer?
    private var lastScreenshotAt: Date?
    private let settingsProvider: () -> AppSettings
    private let onSample: (ActivitySample) -> Void

    init(settingsProvider: @escaping () -> AppSettings, onSample: @escaping (ActivitySample) -> Void) {
        self.settingsProvider = settingsProvider
        self.onSample = onSample
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        collectNow()
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func collectNow() {
        let settings = settingsProvider()
        var sample = ActiveWindowReader.currentSample(includeWindowTitle: settings.includeWindowTitles)

        if settings.captureScreenshots, shouldCaptureScreenshot(settings: settings) {
            if let capture = ScreenSnapshotter.capture() {
                sample.snapshotPath = capture.path
                sample.screenText = capture.recognizedText
            }
            lastScreenshotAt = Date()
        }

        latestSample = sample
        onSample(sample)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = max(10, settingsProvider().sampleInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectNow()
            }
        }
    }

    private func shouldCaptureScreenshot(settings: AppSettings) -> Bool {
        guard let lastScreenshotAt else { return true }
        let interval = TimeInterval(max(1, settings.screenshotIntervalMinutes) * 60)
        return Date().timeIntervalSince(lastScreenshotAt) >= interval
    }
}

enum ActiveWindowReader {
    static func currentSample(includeWindowTitle: Bool) -> ActivitySample {
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier ?? 0
        let title = includeWindowTitle ? windowTitle(for: pid) : nil

        return ActivitySample(
            timestamp: Date(),
            appName: app?.localizedName ?? "未知应用",
            bundleIdentifier: app?.bundleIdentifier ?? "",
            processID: pid,
            windowTitle: title,
            snapshotPath: nil,
            screenText: nil
        )
    }

    private static func windowTitle(for pid: pid_t) -> String? {
        guard pid != 0 else { return nil }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for info in windowInfo {
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t
            let layer = info[kCGWindowLayer as String] as? Int
            guard ownerPID == pid, layer == 0 else { continue }

            if let title = info[kCGWindowName as String] as? String,
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return title
            }
        }

        return nil
    }
}

enum ScreenSnapshotter {
    struct Capture {
        let path: String
        let recognizedText: String?
    }

    static func capture() -> Capture? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = support
            .appendingPathComponent("StudyAIRecorder", isDirectory: true)
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent(Date().dayKey, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let file = folder.appendingPathComponent("snapshot-\(Int(Date().timeIntervalSince1970)).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", file.path]

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return Capture(path: file.path, recognizedText: recognizeText(in: file))
        } catch {
            NSLog("Screen snapshot failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func recognizeText(in file: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            let lines = request.results?
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            let joined = lines.prefix(40).joined(separator: " / ")
            return joined.isEmpty ? nil : joined
        } catch {
            NSLog("Screen OCR failed: \(error.localizedDescription)")
            return nil
        }
    }
}

enum ActivityAnalyzer {
    static func samples(on date: Date, from allSamples: [ActivitySample]) -> [ActivitySample] {
        allSamples
            .filter { $0.timestamp.dayKey == date.dayKey }
            .sorted { $0.timestamp < $1.timestamp }
    }

    static func durations(from samples: [ActivitySample], sampleInterval: TimeInterval) -> [AppDuration] {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        var secondsByApp: [String: TimeInterval] = [:]
        for index in sorted.indices {
            let current = sorted[index]
            let seconds: TimeInterval
            if index < sorted.index(before: sorted.endIndex) {
                let next = sorted[sorted.index(after: index)]
                seconds = min(max(next.timestamp.timeIntervalSince(current.timestamp), 0), max(10, sampleInterval * 2))
            } else {
                seconds = sampleInterval
            }
            secondsByApp[current.appName, default: 0] += seconds
        }

        return secondsByApp
            .map { AppDuration(appName: $0.key, minutes: max(1, Int(($0.value / 60).rounded()))) }
            .sorted { $0.minutes > $1.minutes }
    }

    static func totalMinutes(from samples: [ActivitySample], sampleInterval: TimeInterval) -> Int {
        durations(from: samples, sampleInterval: sampleInterval).reduce(0) { $0 + $1.minutes }
    }

    static func timelineBlocks(from samples: [ActivitySample], sampleInterval: TimeInterval) -> [String] {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        var blocks: [String] = []
        var currentApp = sorted[0].appName
        var currentTitle = sorted[0].windowTitle
        var start = sorted[0].timestamp
        var end = sorted[0].timestamp

        for sample in sorted.dropFirst() {
            let titleChanged = normalized(sample.windowTitle) != normalized(currentTitle)
            let appChanged = sample.appName != currentApp
            let gap = sample.timestamp.timeIntervalSince(end) > max(120, sampleInterval * 4)

            if appChanged || titleChanged || gap {
                blocks.append(formatBlock(start: start, end: end, app: currentApp, title: currentTitle))
                currentApp = sample.appName
                currentTitle = sample.windowTitle
                start = sample.timestamp
            }
            end = sample.timestamp
        }

        blocks.append(formatBlock(start: start, end: end, app: currentApp, title: currentTitle))
        return blocks
    }

    private static func normalized(_ text: String?) -> String {
        text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func formatBlock(start: Date, end: Date, app: String, title: String?) -> String {
        let cleanTitle = normalized(title)
        let suffix = cleanTitle.isEmpty ? "" : " · \(cleanTitle)"
        return "\(start.clockText)-\(end.clockText) \(app)\(suffix)"
    }
}
