import Combine
import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case planning
    case monitor
    case coach
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今日"
        case .planning: return "规划"
        case .monitor: return "监控"
        case .coach: return "教练"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "calendar"
        case .planning: return "point.topleft.down.curvedto.point.bottomright.up"
        case .monitor: return "rectangle.on.rectangle"
        case .coach: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var database: AppDatabase
    @Published var selectedSection: AppSection = .today
    @Published var apiKeyDraft: String
    @Published var isGeneratingSummary = false
    @Published var isCoachThinking = false
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
        archiveStaleCoachConversationIfNeeded()
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

    var activeCoachMessages: [CoachMessage] {
        database.currentCoachMessages
    }

    var activeCoachConversation: CoachConversation? {
        database.activeCoachConversation
    }

    var coachIdentityTitle: String {
        let clean = database.coachIdentity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "未设置身份" : clean
    }

    func startNewCoachConversation() {
        let conversation = CoachConversation(
            identityId: database.coachIdentity.id,
            title: "对话 \(Date().dateTimeText)",
            createdAt: Date(),
            updatedAt: Date(),
            messages: []
        )
        database.coachConversations.insert(conversation, at: 0)
        database.activeCoachConversationId = conversation.id
        persist()
    }

    func selectCoachConversation(_ conversation: CoachConversation) {
        guard database.coachConversations.contains(where: { $0.id == conversation.id }) else { return }
        database.activeCoachConversationId = conversation.id
        persist()
    }

    func renameCoachConversation(_ conversation: CoachConversation, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              let index = database.coachConversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        database.coachConversations[index].title = clean
        database.coachConversations[index].updatedAt = Date()
        persist()
    }

    func deleteCoachConversation(_ conversation: CoachConversation) {
        guard let index = database.coachConversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        let wasActive = database.activeCoachConversationId == conversation.id
        database.coachConversations.remove(at: index)

        if database.coachConversations.isEmpty {
            let fresh = CoachConversation(
                identityId: database.coachIdentity.id,
                title: "新对话",
                messages: []
            )
            database.coachConversations = [fresh]
            database.activeCoachConversationId = fresh.id
        } else if wasActive {
            let next = database.coachConversations.sorted { $0.updatedAt > $1.updatedAt }.first
            database.activeCoachConversationId = next?.id
        }

        if let activeId = database.activeCoachConversationId,
           let active = database.coachConversations.first(where: { $0.id == activeId }) {
            database.coachMessages = active.messages
        } else {
            database.coachMessages = []
        }
        persist()
    }

    func updateCoachIdentity(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let oldTitle = database.coachIdentity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if oldTitle.isEmpty {
            database.coachIdentity.title = clean
            database.coachIdentity.updatedAt = Date()
            for index in database.coachConversations.indices {
                database.coachConversations[index].identityId = database.coachIdentity.id
            }
            persist()
            return
        }

        guard oldTitle != clean else { return }

        archiveAllCoachConversations(reason: "身份信息从“\(oldTitle)”修改为“\(clean)”")
        database.coachIdentity = CoachIdentityProfile(title: clean)
        database.coachMemory = CoachMemory()
        database.coachMessages = []
        let greeting = CoachMessage(
            role: .assistant,
            content: "已切换到“\(clean)”身份。我会基于这个身份重新建立对话记忆。"
        )
        let conversation = CoachConversation(
            identityId: database.coachIdentity.id,
            title: "新身份对话",
            messages: [greeting]
        )
        database.coachConversations = [conversation]
        database.activeCoachConversationId = conversation.id
        persist()
    }

    func addTask(
        title: String,
        note: String,
        project: String,
        startDate: Date,
        targetDate: Date,
        estimatedMinutes: Int,
        priority: TaskPriority
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        database.tasks.insert(
            StudyTask(
                title: cleanTitle,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                mode: .plan,
                project: project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "学习" : project,
                startDate: startDate,
                targetDate: targetDate,
                estimatedMinutes: max(5, estimatedMinutes),
                status: .planned,
                priority: priority,
                createdAt: Date()
            ),
            at: 0
        )
        persist()
    }

    func updateTask(
        _ task: StudyTask,
        title: String? = nil,
        note: String? = nil,
        project: String? = nil,
        startDate: Date? = nil,
        targetDate: Date? = nil,
        estimatedMinutes: Int? = nil,
        priority: TaskPriority? = nil
    ) {
        guard let index = database.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if let title {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { database.tasks[index].title = clean }
        }
        if let note { database.tasks[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let project {
            let clean = project.trimmingCharacters(in: .whitespacesAndNewlines)
            database.tasks[index].project = clean.isEmpty ? "学习" : clean
        }
        if let startDate { database.tasks[index].startDate = startDate }
        if let targetDate { database.tasks[index].targetDate = targetDate }
        if let estimatedMinutes { database.tasks[index].estimatedMinutes = max(5, estimatedMinutes) }
        if let priority { database.tasks[index].priority = priority }
        persist()
    }

    func setTaskStatus(_ task: StudyTask, status: TaskStatus) {
        guard let index = database.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        database.tasks[index].status = status
        database.tasks[index].completedAt = status == .done ? Date() : nil
        persist()
    }

    func completeTask(_ task: StudyTask, title: String, body: String) {
        guard let index = database.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        database.tasks[index].status = .done
        database.tasks[index].completedAt = Date()
        if !cleanTitle.isEmpty || !cleanBody.isEmpty {
            database.tasks[index].completionNote = cleanBody.isEmpty ? cleanTitle : cleanBody
            database.tasks[index].journal.insert(PlanningLogEntry(title: cleanTitle, body: cleanBody), at: 0)
        }
        persist()
    }

    func appendTaskJournal(_ task: StudyTask, title: String, body: String) {
        guard let index = database.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty || !clean.isEmpty else { return }
        database.tasks[index].journal.insert(PlanningLogEntry(title: cleanTitle, body: clean), at: 0)
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

    func updateGoal(
        _ goal: StudyGoal,
        title: String? = nil,
        purpose: String? = nil,
        metric: String? = nil,
        days: Int? = nil
    ) {
        guard let index = database.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        if let title {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { database.goals[index].title = clean }
        }
        if let purpose { database.goals[index].purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let metric {
            let clean = metric.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { database.goals[index].metric = clean }
        }
        if let days {
            database.goals[index].targetDate = Calendar.current.date(byAdding: .day, value: max(1, days), to: Date()) ?? database.goals[index].targetDate
        }
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

    func appendGoalLog(_ goal: StudyGoal, title: String, body: String) {
        guard let index = database.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty || !clean.isEmpty else { return }
        database.goals[index].logs.insert(PlanningLogEntry(title: cleanTitle, body: clean), at: 0)
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

    func todaysTasks(date: Date = Date()) -> [StudyTask] {
        tasksForToday(date: date)
    }

    func tasks(on date: Date) -> [StudyTask] {
        database.tasks
            .filter { $0.targetDate.dayKey == date.dayKey }
            .sorted { left, right in
                if left.status == right.status {
                    return left.createdAt > right.createdAt
                }
                return left.status.rawValue < right.status.rawValue
            }
    }

    func tasksForToday(date: Date = Date()) -> [StudyTask] {
        database.tasks
            .filter { task in
                let isActive = task.startDate.dayKey <= date.dayKey && date.dayKey <= task.targetDate.dayKey && task.status != .done
                let completedToday = task.completedAt?.dayKey == date.dayKey
                let overdue = task.targetDate.dayKey < date.dayKey && task.status != .done
                return isActive || completedToday || overdue
            }
            .sorted { left, right in
                let leftRank = todayTaskRank(left, date: date)
                let rightRank = todayTaskRank(right, date: date)
                if leftRank == rightRank {
                    return left.targetDate < right.targetDate
                }
                return leftRank < rightRank
            }
    }

    func activeGoals() -> [StudyGoal] {
        database.goals.sorted {
            $0.targetDate < $1.targetDate
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
            statusMessage = "教练复盘已生成"
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
            statusMessage = "已生成本地复盘：\(error.localizedDescription)"
        }
    }

    func sendCoachMessage(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        archiveStaleCoachConversationIfNeeded()
        appendCoachMessage(CoachMessage(role: .user, content: clean))
        trimCoachMessages()
        persist()

        isCoachThinking = true
        statusMessage = nil
        defer { isCoachThinking = false }

        let client = AIClient(settings: database.settings, apiKey: apiKeyDraft)
        let response: CoachAgentResponse
        do {
            response = try await client.runPlanningCoach(input: clean, database: database)
        } catch {
            response = PlanningCoachAgent.localFallback(input: clean, database: database, reason: error.localizedDescription)
            statusMessage = "教练使用本地降级：\(error.localizedDescription)"
        }

        let toolResults = applyCoachActions(response.actions)
        for result in toolResults {
            appendCoachMessage(
                CoachMessage(
                    role: .tool,
                    content: result.message,
                    toolName: result.action.rawValue,
                    isError: !result.success
                )
            )
        }

        if let report = response.dailySummary {
            upsertDailySummary(report: report)
        }

        updateCoachMemory(summary: response.memoryUpdate, keyFacts: response.keyFacts)

        appendCoachMessage(CoachMessage(role: .assistant, content: response.reply))
        trimCoachMessages()
        persist()
    }

    func coachFiles() -> [CoachFileRecord] {
        let directory = coachFilesDirectory()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
        ) else {
            return []
        }

        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            guard values?.isDirectory != true else { return nil }
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return CoachFileRecord(
                name: url.lastPathComponent,
                path: url.path,
                modifiedAt: values?.contentModificationDate ?? Date(),
                preview: String(content.prefix(160))
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func applyCoachActions(_ actions: [CoachAction]) -> [CoachToolResult] {
        actions.map { action in
            switch action.type {
            case .addPlan:
                let title = action.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !title.isEmpty else {
                    return CoachToolResult(action: action.type, success: false, message: "新增计划失败：缺少标题。")
                }
                addTask(
                    title: title,
                    note: action.note ?? "",
                    project: action.project ?? "学习",
                    startDate: dateFromDayKey(action.startDate) ?? Date(),
                    targetDate: dateFromDayKey(action.targetDate ?? action.date) ?? dateFromDayKey(action.startDate) ?? Date(),
                    estimatedMinutes: action.estimatedMinutes ?? 45,
                    priority: action.priority ?? .medium
                )
                return CoachToolResult(action: action.type, success: true, message: "已新增计划：\(title)。")

            case .updatePlan:
                guard let task = findTask(action.targetId) else {
                    return CoachToolResult(action: action.type, success: false, message: "更新计划失败：未找到目标计划。")
                }
                updateTask(
                    task,
                    title: action.title,
                    note: action.note,
                    project: action.project,
                    startDate: dateFromDayKey(action.startDate),
                    targetDate: dateFromDayKey(action.targetDate ?? action.date),
                    estimatedMinutes: action.estimatedMinutes,
                    priority: action.priority
                )
                return CoachToolResult(action: action.type, success: true, message: "已更新计划：\(task.title)。")

            case .deletePlan:
                guard let task = findTask(action.targetId) else {
                    return CoachToolResult(action: action.type, success: false, message: "删除计划失败：未找到目标计划。")
                }
                removeTask(task)
                return CoachToolResult(action: action.type, success: true, message: "已删除计划：\(task.title)。")

            case .completePlan:
                guard let task = findTask(action.targetId) else {
                    return CoachToolResult(action: action.type, success: false, message: "完成计划失败：未找到目标计划。")
                }
                completeTask(task, title: action.title ?? "", body: action.body ?? "")
                return CoachToolResult(action: action.type, success: true, message: "已标记完成：\(task.title)。")

            case .addPlanLog:
                guard let task = findTask(action.targetId) else {
                    return CoachToolResult(action: action.type, success: false, message: "添加计划日记失败：未找到目标计划。")
                }
                appendTaskJournal(task, title: action.title ?? "", body: action.body ?? "")
                return CoachToolResult(action: action.type, success: true, message: "已添加计划日记：\(task.title)。")

            case .addGoal:
                let title = action.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !title.isEmpty else {
                    return CoachToolResult(action: action.type, success: false, message: "新增目标失败：缺少标题。")
                }
                addGoal(title: title, purpose: action.purpose ?? "", metric: action.metric ?? "", days: action.days ?? 14)
                return CoachToolResult(action: action.type, success: true, message: "已新增目标：\(title)。")

            case .updateGoal:
                guard let goal = findGoal(action.targetId) else {
                    return CoachToolResult(action: action.type, success: false, message: "更新目标失败：未找到目标。")
                }
                updateGoal(goal, title: action.title, purpose: action.purpose, metric: action.metric, days: action.days)
                return CoachToolResult(action: action.type, success: true, message: "已更新目标：\(goal.title)。")

            case .deleteGoal:
                guard let goal = findGoal(action.targetId) else {
                    return CoachToolResult(action: action.type, success: false, message: "删除目标失败：未找到目标。")
                }
                removeGoal(goal)
                return CoachToolResult(action: action.type, success: true, message: "已删除目标：\(goal.title)。")

            case .updateGoalProgress:
                guard let goal = findGoal(action.targetId), let progress = action.progress else {
                    return CoachToolResult(action: action.type, success: false, message: "更新目标进度失败：缺少目标或进度。")
                }
                updateGoalProgress(goal, progress: progress)
                return CoachToolResult(action: action.type, success: true, message: "已更新目标进度：\(goal.title)。")

            case .addGoalLog:
                guard let goal = findGoal(action.targetId) else {
                    return CoachToolResult(action: action.type, success: false, message: "添加目标日志失败：未找到目标。")
                }
                appendGoalLog(goal, title: action.title ?? "", body: action.body ?? "")
                return CoachToolResult(action: action.type, success: true, message: "已添加目标日志：\(goal.title)。")

            case .readPlanningContext:
                let context = PlanningCoachContext(database: database)
                return CoachToolResult(
                    action: action.type,
                    success: true,
                    message: "已读取上下文：计划 \(database.tasks.count) 个，目标 \(database.goals.count) 个。最近日志：\(String(context.logsText.prefix(500)))"
                )

            case .listCoachFiles:
                let names = coachFiles().map(\.name).joined(separator: "、")
                return CoachToolResult(action: action.type, success: true, message: names.isEmpty ? "教练文件区暂无文件。" : "教练文件：\(names)")

            case .readCoachFile:
                let fileName = safeCoachFileName(action.fileName)
                guard let content = readCoachFile(fileName: fileName) else {
                    return CoachToolResult(action: action.type, success: false, message: "读取文件失败：\(fileName)。")
                }
                return CoachToolResult(action: action.type, success: true, message: "已读取 \(fileName)：\(String(content.prefix(1200)))")

            case .writeCoachFile:
                let fileName = safeCoachFileName(action.fileName)
                let content = action.content ?? action.body ?? ""
                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return CoachToolResult(action: action.type, success: false, message: "写入文件失败：内容为空。")
                }
                do {
                    let url = coachFilesDirectory().appendingPathComponent(fileName)
                    try FileManager.default.createDirectory(at: coachFilesDirectory(), withIntermediateDirectories: true)
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    return CoachToolResult(action: action.type, success: true, message: "已写入教练文件：\(fileName)。")
                } catch {
                    return CoachToolResult(action: action.type, success: false, message: "写入文件失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func upsert(_ summary: DailySummary) {
        database.summaries.removeAll { $0.dateKey == summary.dateKey }
        database.summaries.append(summary)
        persist()
    }

    private func upsertDailySummary(report: StudyAgentReport, date: Date = Date()) {
        let context = LearningDayContext(
            date: date,
            tasks: todaysTasks(date: date),
            goals: database.goals,
            samples: todaysSamples(date: date),
            settings: database.settings
        )
        let score = LearningScoreRubric.evaluate(context)
        let normalized = report.normalized(context: context, score: score)
        let summary = DailySummary(
            dateKey: date.dayKey,
            generatedAt: Date(),
            score: score.score,
            body: LearningSummaryRenderer.render(date: date, score: score, report: normalized, settings: database.settings),
            model: database.settings.model
        )
        upsert(summary)
    }

    @discardableResult
    private func ensureActiveCoachConversationIndex() -> Int {
        if let activeId = database.activeCoachConversationId,
           let index = database.coachConversations.firstIndex(where: { $0.id == activeId }) {
            return index
        }

        if let first = database.coachConversations.first {
            database.activeCoachConversationId = first.id
            return 0
        }

        let conversation = CoachConversation(
            identityId: database.coachIdentity.id,
            title: "对话 \(Date().dateTimeText)",
            messages: []
        )
        database.coachConversations.insert(conversation, at: 0)
        database.activeCoachConversationId = conversation.id
        return 0
    }

    private func appendCoachMessage(_ message: CoachMessage) {
        let index = ensureActiveCoachConversationIndex()
        database.coachConversations[index].messages.append(message)
        database.coachConversations[index].updatedAt = message.createdAt
        if message.role == .user,
           database.coachConversations[index].title.hasPrefix("对话 ") || database.coachConversations[index].title == "新对话" {
            database.coachConversations[index].title = String(message.content.prefix(18))
        }
        database.coachMessages = database.coachConversations[index].messages
    }

    private func archiveStaleCoachConversationIfNeeded() {
        let index = ensureActiveCoachConversationIndex()
        let conversation = database.coachConversations[index]
        guard !conversation.messages.isEmpty,
              conversation.updatedAt.dayKey < Date().dayKey else {
            database.coachMessages = conversation.messages
            return
        }

        archiveConversation(conversation, reason: "每日自动归档")
        database.coachConversations.removeAll { $0.id == conversation.id }

        let fresh = CoachConversation(
            identityId: database.coachIdentity.id,
            title: "今日对话 \(Date().monthDayText)",
            messages: []
        )
        database.coachConversations.insert(fresh, at: 0)
        database.activeCoachConversationId = fresh.id
        database.coachMessages = []
        persist()
    }

    private func archiveAllCoachConversations(reason: String) {
        let conversations = database.coachConversations
        for conversation in conversations where !conversation.messages.isEmpty {
            archiveConversation(conversation, reason: reason)
        }
        database.coachConversations.removeAll()
        database.activeCoachConversationId = nil
        database.coachMessages = []
    }

    private func archiveConversation(_ conversation: CoachConversation, reason: String) {
        guard !database.archivedCoachConversations.contains(where: { $0.id == conversation.id }) else { return }
        var archive = CoachConversationArchive(
            id: conversation.id,
            identityId: database.coachIdentity.id,
            identityTitle: coachIdentityTitle,
            title: conversation.title,
            createdAt: conversation.createdAt,
            messages: conversation.messages,
            memorySummary: database.coachMemory.summary,
            keyFacts: database.coachMemory.keyFacts
        )
        archive.filePath = writeArchiveFile(archive, reason: reason)
        database.archivedCoachConversations.insert(archive, at: 0)
    }

    private func writeArchiveFile(_ archive: CoachConversationArchive, reason: String) -> String? {
        let directory = coachArchiveDirectory(identityTitle: archive.identityTitle)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let shortId = String(archive.id.uuidString.prefix(8))
            let fileName = "\(archive.archivedAt.dayKey)-\(shortId).md"
            let url = directory.appendingPathComponent(fileName)
            let messages = archive.messages.map { message in
                """
                ## \(message.role.title) \(message.createdAt.dateTimeText)

                \(message.content)
                """
            }.joined(separator: "\n\n")
            let body = """
            # \(archive.title)

            身份：\(archive.identityTitle)
            归档时间：\(archive.archivedAt.dateTimeText)
            归档原因：\(reason)

            ## 归档时记忆

            \(archive.memorySummary.isEmpty ? "暂无记忆摘要" : archive.memorySummary)

            \(archive.keyFacts.isEmpty ? "" : "关键事实：\(archive.keyFacts.joined(separator: "；"))")

            \(messages)
            """
            try body.write(to: url, atomically: true, encoding: .utf8)
            return url.path
        } catch {
            statusMessage = "归档文件写入失败：\(error.localizedDescription)"
            return nil
        }
    }

    private func updateCoachMemory(summary: String?, keyFacts: [String]) {
        let cleanSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanSummary.isEmpty {
            database.coachMemory.summary = cleanSummary
            database.coachMemory.updatedAt = Date()
        }

        let merged = (database.coachMemory.keyFacts + keyFacts)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, fact in
                if !result.contains(fact) {
                    result.append(fact)
                }
            }
        database.coachMemory.keyFacts = Array(merged.prefix(20))
        if !keyFacts.isEmpty {
            database.coachMemory.updatedAt = Date()
        }
    }

    private func trimSamples() {
        let grouped = Dictionary(grouping: database.samples, by: { $0.timestamp.dayKey })
        database.samples = grouped.flatMap { _, samples in
            let limit = max(200, database.settings.maxSamplesPerDay)
            return Array(samples.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
        }
    }

    private func trimCoachMessages() {
        let index = ensureActiveCoachConversationIndex()
        database.coachConversations[index].messages = Array(database.coachConversations[index].messages.suffix(240))
        database.coachMessages = database.coachConversations[index].messages
    }

    private func todayTaskRank(_ task: StudyTask, date: Date) -> Int {
        if task.completedAt?.dayKey == date.dayKey { return 2 }
        if task.targetDate.dayKey < date.dayKey && task.status != .done { return 1 }
        return 0
    }

    private func findTask(_ id: String?) -> StudyTask? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        return database.tasks.first { $0.id == uuid }
    }

    private func findGoal(_ id: String?) -> StudyGoal? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        return database.goals.first { $0.id == uuid }
    }

    private func dateFromDayKey(_ value: String?) -> Date? {
        guard let value else { return nil }
        return DateFormatters.dayKey.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func coachFilesDirectory() -> URL {
        store.folderURL.appendingPathComponent("CoachFiles", isDirectory: true)
    }

    private func coachArchiveDirectory(identityTitle: String) -> URL {
        store.folderURL
            .appendingPathComponent("CoachArchives", isDirectory: true)
            .appendingPathComponent(safeArchiveFolderName(identityTitle), isDirectory: true)
    }

    private func safeArchiveFolderName(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "未设置身份" }
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let mapped = clean.unicodeScalars.map { scalar -> Character in
            invalid.contains(scalar) ? "-" : Character(scalar)
        }
        return String(mapped).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func safeCoachFileName(_ value: String?) -> String {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "coach-note.md"
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_. ")
        let filtered = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let name = filtered.isEmpty ? "coach-note.md" : filtered
        return name.contains(".") ? name : "\(name).md"
    }

    private func readCoachFile(fileName: String) -> String? {
        let url = coachFilesDirectory().appendingPathComponent(fileName)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
