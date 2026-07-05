import Combine
import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case plan
    case goals
    case monitor
    case summary
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今日轨迹"
        case .plan: return "计划"
        case .goals: return "目标"
        case .monitor: return "监控"
        case .summary: return "AI 总结"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "clock.arrow.circlepath"
        case .plan: return "checklist"
        case .goals: return "scope"
        case .monitor: return "rectangle.on.rectangle"
        case .summary: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var database: AppDatabase
    @Published var selectedSection: AppSection = .today
    @Published var selectedMode: WorkspaceMode = .plan
    @Published var apiKeyDraft: String
    @Published var isGeneratingSummary = false
    @Published var statusMessage: String?

    let store: DataStore
    var monitor: ActivityMonitor
    private var monitorCancellable: AnyCancellable?

    init(store: DataStore = DataStore()) {
        self.store = store
        database = store.load()
        apiKeyDraft = KeychainStore.readAPIKey()

        monitor = ActivityMonitor(
            settingsProvider: { AppSettings() },
            onSample: { _ in }
        )

        monitor = ActivityMonitor(
            settingsProvider: { [weak self] in
                self?.database.settings ?? AppSettings()
            },
            onSample: { [weak self] sample in
                Task { @MainActor in
                    self?.record(sample: sample)
                }
            }
        )
        monitorCancellable = monitor.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    func persist() {
        store.save(database)
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        mutate(&database.settings)
        persist()
    }

    func saveAPIKey() {
        do {
            try KeychainStore.saveAPIKey(apiKeyDraft)
            statusMessage = "API Key 已保存到钥匙串"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addTask(title: String, note: String, mode: WorkspaceMode, project: String, estimatedMinutes: Int, priority: TaskPriority) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        database.tasks.insert(
            StudyTask(
                title: cleanTitle,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                mode: mode,
                project: project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "学习" : project,
                targetDate: Date(),
                estimatedMinutes: max(5, estimatedMinutes),
                status: .planned,
                priority: priority,
                createdAt: Date()
            ),
            at: 0
        )
        persist()
    }

    func setTaskStatus(_ task: StudyTask, status: TaskStatus) {
        guard let index = database.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        database.tasks[index].status = status
        database.tasks[index].completedAt = status == .done ? Date() : nil
        persist()
    }

    func removeTask(_ task: StudyTask) {
        database.tasks.removeAll { $0.id == task.id }
        persist()
    }

    func addGoal(title: String, purpose: String, metric: String, days: Int) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        database.goals.insert(
            StudyGoal(
                title: cleanTitle,
                purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
                metric: metric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "完成可验证产出" : metric,
                targetDate: Calendar.current.date(byAdding: .day, value: max(1, days), to: Date()) ?? Date(),
                progress: 0,
                milestones: [
                    Milestone(title: "明确下一步动作", isDone: false),
                    Milestone(title: "完成一次阶段复盘", isDone: false),
                    Milestone(title: "产出可展示成果", isDone: false)
                ],
                createdAt: Date()
            ),
            at: 0
        )
        persist()
    }

    func updateGoalProgress(_ goal: StudyGoal, progress: Double) {
        guard let index = database.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        database.goals[index].progress = min(1, max(0, progress))
        persist()
    }

    func toggleMilestone(_ milestone: Milestone, in goal: StudyGoal) {
        guard let goalIndex = database.goals.firstIndex(where: { $0.id == goal.id }),
              let milestoneIndex = database.goals[goalIndex].milestones.firstIndex(where: { $0.id == milestone.id }) else { return }
        database.goals[goalIndex].milestones[milestoneIndex].isDone.toggle()
        persist()
    }

    func removeGoal(_ goal: StudyGoal) {
        database.goals.removeAll { $0.id == goal.id }
        persist()
    }

    func record(sample: ActivitySample) {
        database.samples.append(sample)
        trimSamples()
        persist()
    }

    func todaysTasks(mode: WorkspaceMode? = nil, date: Date = Date()) -> [StudyTask] {
        database.tasks
            .filter { $0.targetDate.dayKey == date.dayKey && (mode == nil || $0.mode == mode) }
            .sorted { left, right in
                if left.status == right.status {
                    return left.createdAt > right.createdAt
                }
                return left.status.rawValue < right.status.rawValue
            }
    }

    func todaysSamples(date: Date = Date()) -> [ActivitySample] {
        ActivityAnalyzer.samples(on: date, from: database.samples)
    }

    func appDurations(date: Date = Date()) -> [AppDuration] {
        ActivityAnalyzer.durations(from: todaysSamples(date: date), sampleInterval: database.settings.sampleInterval)
    }

    func latestSummary(for date: Date = Date()) -> DailySummary? {
        database.summaries
            .filter { $0.dateKey == date.dayKey }
            .sorted { $0.generatedAt > $1.generatedAt }
            .first
    }

    func generateSummary(for date: Date = Date()) async {
        isGeneratingSummary = true
        statusMessage = nil
        defer { isGeneratingSummary = false }

        let tasks = todaysTasks(date: date)
        let samples = todaysSamples(date: date)
        let goals = database.goals
        let client = AIClient(settings: database.settings, apiKey: apiKeyDraft)

        do {
            let summary = try await client.generateSummary(date: date, tasks: tasks, goals: goals, samples: samples)
            upsert(summary)
            statusMessage = "AI 总结已生成"
        } catch {
            let fallback = AIClient.localSummary(
                date: date,
                tasks: tasks,
                goals: goals,
                samples: samples,
                settings: database.settings,
                reason: error.localizedDescription
            )
            upsert(fallback)
            statusMessage = "已生成本地总结：\(error.localizedDescription)"
        }
    }

    private func upsert(_ summary: DailySummary) {
        database.summaries.removeAll { $0.dateKey == summary.dateKey }
        database.summaries.append(summary)
        persist()
    }

    private func trimSamples() {
        let grouped = Dictionary(grouping: database.samples, by: { $0.timestamp.dayKey })
        database.samples = grouped.flatMap { _, samples in
            let limit = max(200, database.settings.maxSamplesPerDay)
            return Array(samples.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
        }
    }
}
