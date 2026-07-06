import Foundation

enum WorkspaceMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case plan
    case goal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: return "计划"
        case .goal: return "目标"
        }
    }

    var shortTitle: String {
        switch self {
        case .plan: return "计划"
        case .goal: return "目标"
        }
    }

    var systemImage: String {
        switch self {
        case .plan: return "checklist"
        case .goal: return "scope"
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case planned
    case doing
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned: return "待开始"
        case .doing: return "进行中"
        case .done: return "已完成"
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable, Hashable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

enum AppVisualTheme: String, Codable, CaseIterable, Identifiable, Hashable {
    case day
    case night
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "日间"
        case .night: return "暗夜"
        case .custom: return "自定义"
        }
    }

    var subtitle: String {
        switch self {
        case .day: return "明亮、清爽、低对比"
        case .night: return "深色、沉静、护眼"
        case .custom: return "18bit 色深，自由调侧边栏玻璃色"
        }
    }

    var systemImage: String {
        switch self {
        case .day: return "sun.max"
        case .night: return "moon.stars"
        case .custom: return "paintpalette"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "system", "boulevard", "day":
            self = .day
        case "starlight", "night":
            self = .night
        case "custom":
            self = .custom
        default:
            self = .day
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct Color18: Codable, Hashable {
    var red: Int
    var green: Int
    var blue: Int

    init(red: Int = 8, green: Int = 27, blue: Int = 20) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    var redUnit: Double { Double(red) / 63.0 }
    var greenUnit: Double { Double(green) / 63.0 }
    var blueUnit: Double { Double(blue) / 63.0 }

    private static func clamp(_ value: Int) -> Int {
        min(63, max(0, value))
    }
}

enum LearningAgentSkill: String, Codable, CaseIterable, Identifiable, Hashable {
    case evidenceAudit
    case scoringRubric
    case trajectorySynthesis
    case goalAlignment
    case focusRecovery
    case tomorrowPlanning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .evidenceAudit: return "证据审计"
        case .scoringRubric: return "稳定评分"
        case .trajectorySynthesis: return "轨迹归纳"
        case .goalAlignment: return "目标对齐"
        case .focusRecovery: return "专注修复"
        case .tomorrowPlanning: return "明日计划"
        }
    }

    var detail: String {
        switch self {
        case .evidenceAudit: return "先判断数据是否足够，禁止编造活动。"
        case .scoringRubric: return "由本地量规评分，模型只解释证据。"
        case .trajectorySynthesis: return "把应用、窗口、OCR 合并成时间线。"
        case .goalAlignment: return "检查任务是否支撑长期目标。"
        case .focusRecovery: return "识别分心、空转和低证据时段。"
        case .tomorrowPlanning: return "输出短、具体、可执行的下一步。"
        }
    }

    var promptInstruction: String {
        switch self {
        case .evidenceAudit:
            return "证据审计：只使用输入数据；如果证据不足，用“数据不足”说明边界，不用安慰性废话。"
        case .scoringRubric:
            return "稳定评分：评分由 SCORING_LOCK 给出，绝对不要改分；解释只能围绕量规和证据。"
        case .trajectorySynthesis:
            return "轨迹归纳：合并重复窗口，把活动归为阅读、编码、检索、沟通、娱乐、系统操作或空白。"
        case .goalAlignment:
            return "目标对齐：判断今日任务和长期目标是否一致，指出缺失的下一步产出。"
        case .focusRecovery:
            return "专注修复：找出最小的节奏改动，避免泛泛地说少刷手机、少浏览。"
        case .tomorrowPlanning:
            return "明日计划：给出 3 个动作，每个动作有明确对象和完成信号。"
        }
    }

    static let bestDefaultIDs = allCases.map(\.rawValue)
}

struct PlanningLogEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var createdAt: Date
    var body: String

    init(id: UUID = UUID(), title: String = "", createdAt: Date = Date(), body: String) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.defaultTitle(from: body)
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.body = body
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case body
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? Self.defaultTitle(from: body)
    }

    private static func defaultTitle(from body: String) -> String {
        let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "未命名记录" }
        return String(clean.prefix(18))
    }
}

enum CoachMessageRole: String, Codable, CaseIterable, Identifiable, Hashable {
    case user
    case assistant
    case tool
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .user: return "我"
        case .assistant: return "教练"
        case .tool: return "工具"
        case .system: return "系统"
        }
    }
}

struct CoachMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var role: CoachMessageRole
    var content: String
    var createdAt: Date
    var toolName: String?
    var isError: Bool

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        content: String,
        createdAt: Date = Date(),
        toolName: String? = nil,
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.toolName = toolName
        self.isError = isError
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt
        case toolName
        case isError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        role = try container.decodeIfPresent(CoachMessageRole.self, forKey: .role) ?? .assistant
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
    }
}

struct CoachMemory: Codable, Hashable {
    var summary: String = ""
    var keyFacts: [String] = []
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case summary
        case keyFacts
        case updatedAt
    }

    init(summary: String = "", keyFacts: [String] = [], updatedAt: Date? = nil) {
        self.summary = summary
        self.keyFacts = keyFacts
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        keyFacts = try container.decodeIfPresent([String].self, forKey: .keyFacts) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct CoachIdentityProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

struct CoachConversation: Identifiable, Codable, Hashable {
    var id = UUID()
    var identityId: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [CoachMessage]

    init(
        id: UUID = UUID(),
        identityId: UUID,
        title: String = "新对话",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [CoachMessage] = []
    ) {
        self.id = id
        self.identityId = identityId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    enum CodingKeys: String, CodingKey {
        case id
        case identityId
        case title
        case createdAt
        case updatedAt
        case messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        identityId = try container.decodeIfPresent(UUID.self, forKey: .identityId) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "新对话"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        messages = try container.decodeIfPresent([CoachMessage].self, forKey: .messages) ?? []
    }
}

struct CoachConversationArchive: Identifiable, Codable, Hashable {
    var id = UUID()
    var identityId: UUID
    var identityTitle: String
    var title: String
    var createdAt: Date
    var archivedAt: Date
    var messages: [CoachMessage]
    var memorySummary: String
    var keyFacts: [String]
    var filePath: String?

    init(
        id: UUID = UUID(),
        identityId: UUID,
        identityTitle: String,
        title: String,
        createdAt: Date,
        archivedAt: Date = Date(),
        messages: [CoachMessage],
        memorySummary: String,
        keyFacts: [String],
        filePath: String? = nil
    ) {
        self.id = id
        self.identityId = identityId
        self.identityTitle = identityTitle
        self.title = title
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.messages = messages
        self.memorySummary = memorySummary
        self.keyFacts = keyFacts
        self.filePath = filePath
    }

    enum CodingKeys: String, CodingKey {
        case id
        case identityId
        case identityTitle
        case title
        case createdAt
        case archivedAt
        case messages
        case memorySummary
        case keyFacts
        case filePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        identityId = try container.decodeIfPresent(UUID.self, forKey: .identityId) ?? UUID()
        identityTitle = try container.decodeIfPresent(String.self, forKey: .identityTitle) ?? "未设置身份"
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "归档对话"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt) ?? Date()
        messages = try container.decodeIfPresent([CoachMessage].self, forKey: .messages) ?? []
        memorySummary = try container.decodeIfPresent(String.self, forKey: .memorySummary) ?? ""
        keyFacts = try container.decodeIfPresent([String].self, forKey: .keyFacts) ?? []
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
    }
}

struct CoachFileRecord: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let modifiedAt: Date
    let preview: String
}

struct StudyTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var note: String
    var mode: WorkspaceMode
    var project: String
    var startDate: Date
    var targetDate: Date
    var estimatedMinutes: Int
    var status: TaskStatus
    var priority: TaskPriority
    var createdAt: Date
    var completedAt: Date?
    var completionNote: String
    var journal: [PlanningLogEntry]

    var isDueToday: Bool {
        Calendar.current.isDateInToday(targetDate)
    }

    init(
        id: UUID = UUID(),
        title: String,
        note: String,
        mode: WorkspaceMode = .plan,
        project: String,
        startDate: Date = Date(),
        targetDate: Date,
        estimatedMinutes: Int,
        status: TaskStatus = .planned,
        priority: TaskPriority = .medium,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        completionNote: String = "",
        journal: [PlanningLogEntry] = []
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.mode = mode
        self.project = project
        self.startDate = startDate
        self.targetDate = targetDate
        self.estimatedMinutes = estimatedMinutes
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.completionNote = completionNote
        self.journal = journal
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case note
        case mode
        case project
        case startDate
        case targetDate
        case estimatedMinutes
        case status
        case priority
        case createdAt
        case completedAt
        case completionNote
        case journal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        mode = try container.decodeIfPresent(WorkspaceMode.self, forKey: .mode) ?? .plan
        project = try container.decodeIfPresent(String.self, forKey: .project) ?? "学习"
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate) ?? Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? targetDate
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? createdAt
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 45
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .planned
        priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .medium
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        completionNote = try container.decodeIfPresent(String.self, forKey: .completionNote) ?? ""
        journal = try container.decodeIfPresent([PlanningLogEntry].self, forKey: .journal) ?? []
    }
}

struct Milestone: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var isDone: Bool
}

struct StudyGoal: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var purpose: String
    var metric: String
    var targetDate: Date
    var progress: Double
    var milestones: [Milestone]
    var createdAt: Date
    var logs: [PlanningLogEntry]

    init(
        id: UUID = UUID(),
        title: String,
        purpose: String,
        metric: String,
        targetDate: Date,
        progress: Double = 0,
        milestones: [Milestone],
        createdAt: Date = Date(),
        logs: [PlanningLogEntry] = []
    ) {
        self.id = id
        self.title = title
        self.purpose = purpose
        self.metric = metric
        self.targetDate = targetDate
        self.progress = progress
        self.milestones = milestones
        self.createdAt = createdAt
        self.logs = logs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case purpose
        case metric
        case targetDate
        case progress
        case milestones
        case createdAt
        case logs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        metric = try container.decodeIfPresent(String.self, forKey: .metric) ?? "完成可验证产出"
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate) ?? Date()
        progress = try container.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        milestones = try container.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        logs = try container.decodeIfPresent([PlanningLogEntry].self, forKey: .logs) ?? []
    }
}

struct ActivitySample: Identifiable, Codable, Hashable {
    var id = UUID()
    var timestamp: Date
    var appName: String
    var bundleIdentifier: String
    var processID: Int32
    var windowTitle: String?
    var snapshotPath: String?
    var screenText: String?
}

struct DailySummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var dateKey: String
    var generatedAt: Date
    var score: Int
    var body: String
    var model: String
}

struct AppSettings: Codable, Hashable {
    static let defaultBaseURL = "https://api.openai.com/v1"
    static let defaultModel = "gpt-4o-mini"

    var baseURL: String = AppSettings.defaultBaseURL
    var model: String = AppSettings.defaultModel
    var visualTheme: AppVisualTheme = .day
    var sampleInterval: TimeInterval = 30
    var includeWindowTitles: Bool = true
    var captureScreenshots: Bool = false
    var screenshotIntervalMinutes: Int = 15
    var maxSamplesPerDay: Int = 2400
    var enabledAgentSkillIDs: [String] = LearningAgentSkill.bestDefaultIDs
    var deterministicScoring: Bool = true
    var compactSummaryStyle: Bool = true
    var customSidebarColor = Color18()

    enum CodingKeys: String, CodingKey {
        case baseURL
        case model
        case visualTheme
        case sampleInterval
        case includeWindowTitles
        case captureScreenshots
        case screenshotIntervalMinutes
        case maxSamplesPerDay
        case enabledAgentSkillIDs
        case deterministicScoring
        case compactSummaryStyle
        case customSidebarColor
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? AppSettings.defaultBaseURL
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? AppSettings.defaultModel
        visualTheme = try container.decodeIfPresent(AppVisualTheme.self, forKey: .visualTheme) ?? .day
        sampleInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .sampleInterval) ?? 30
        includeWindowTitles = try container.decodeIfPresent(Bool.self, forKey: .includeWindowTitles) ?? true
        captureScreenshots = try container.decodeIfPresent(Bool.self, forKey: .captureScreenshots) ?? false
        screenshotIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .screenshotIntervalMinutes) ?? 15
        maxSamplesPerDay = try container.decodeIfPresent(Int.self, forKey: .maxSamplesPerDay) ?? 2400
        enabledAgentSkillIDs = try container.decodeIfPresent([String].self, forKey: .enabledAgentSkillIDs) ?? LearningAgentSkill.bestDefaultIDs
        deterministicScoring = try container.decodeIfPresent(Bool.self, forKey: .deterministicScoring) ?? true
        compactSummaryStyle = try container.decodeIfPresent(Bool.self, forKey: .compactSummaryStyle) ?? true
        customSidebarColor = try container.decodeIfPresent(Color18.self, forKey: .customSidebarColor) ?? Color18()
    }
}

struct AppDatabase: Codable, Hashable {
    var tasks: [StudyTask] = []
    var goals: [StudyGoal] = []
    var samples: [ActivitySample] = []
    var summaries: [DailySummary] = []
    var coachMessages: [CoachMessage] = []
    var coachIdentity = CoachIdentityProfile()
    var coachConversations: [CoachConversation] = []
    var activeCoachConversationId: UUID?
    var archivedCoachConversations: [CoachConversationArchive] = []
    var coachMemory = CoachMemory()
    var settings = AppSettings()

    init(
        tasks: [StudyTask] = [],
        goals: [StudyGoal] = [],
        samples: [ActivitySample] = [],
        summaries: [DailySummary] = [],
        coachMessages: [CoachMessage] = [],
        coachIdentity: CoachIdentityProfile = CoachIdentityProfile(),
        coachConversations: [CoachConversation] = [],
        activeCoachConversationId: UUID? = nil,
        archivedCoachConversations: [CoachConversationArchive] = [],
        coachMemory: CoachMemory = CoachMemory(),
        settings: AppSettings = AppSettings()
    ) {
        self.tasks = tasks
        self.goals = goals
        self.samples = samples
        self.summaries = summaries
        self.coachMessages = coachMessages
        self.coachIdentity = coachIdentity
        self.coachConversations = coachConversations
        self.activeCoachConversationId = activeCoachConversationId
        self.archivedCoachConversations = archivedCoachConversations
        self.coachMemory = coachMemory
        self.settings = settings
        migrateLegacyCoachMessagesIfNeeded()
    }

    enum CodingKeys: String, CodingKey {
        case tasks
        case goals
        case samples
        case summaries
        case coachMessages
        case coachIdentity
        case coachConversations
        case activeCoachConversationId
        case archivedCoachConversations
        case coachMemory
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([StudyTask].self, forKey: .tasks) ?? []
        goals = try container.decodeIfPresent([StudyGoal].self, forKey: .goals) ?? []
        samples = try container.decodeIfPresent([ActivitySample].self, forKey: .samples) ?? []
        summaries = try container.decodeIfPresent([DailySummary].self, forKey: .summaries) ?? []
        coachMessages = try container.decodeIfPresent([CoachMessage].self, forKey: .coachMessages) ?? []
        coachIdentity = try container.decodeIfPresent(CoachIdentityProfile.self, forKey: .coachIdentity) ?? CoachIdentityProfile()
        coachConversations = try container.decodeIfPresent([CoachConversation].self, forKey: .coachConversations) ?? []
        activeCoachConversationId = try container.decodeIfPresent(UUID.self, forKey: .activeCoachConversationId)
        archivedCoachConversations = try container.decodeIfPresent([CoachConversationArchive].self, forKey: .archivedCoachConversations) ?? []
        coachMemory = try container.decodeIfPresent(CoachMemory.self, forKey: .coachMemory) ?? CoachMemory()
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        migrateLegacyCoachMessagesIfNeeded()
    }

    var currentCoachMessages: [CoachMessage] {
        guard let activeCoachConversationId,
              let conversation = coachConversations.first(where: { $0.id == activeCoachConversationId }) else {
            return coachMessages
        }
        return conversation.messages
    }

    var activeCoachConversation: CoachConversation? {
        guard let activeCoachConversationId else { return coachConversations.first }
        return coachConversations.first { $0.id == activeCoachConversationId } ?? coachConversations.first
    }

    private mutating func migrateLegacyCoachMessagesIfNeeded() {
        if coachIdentity.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            coachIdentity.updatedAt = coachIdentity.createdAt
        }

        if coachConversations.isEmpty {
            let migratedMessages = coachMessages
            let createdAt = migratedMessages.first?.createdAt ?? Date()
            let updatedAt = migratedMessages.last?.createdAt ?? createdAt
            let conversation = CoachConversation(
                identityId: coachIdentity.id,
                title: migratedMessages.isEmpty ? "默认对话" : "旧对话",
                createdAt: createdAt,
                updatedAt: updatedAt,
                messages: migratedMessages
            )
            coachConversations = [conversation]
            activeCoachConversationId = conversation.id
        } else if activeCoachConversationId == nil || !coachConversations.contains(where: { $0.id == activeCoachConversationId }) {
            activeCoachConversationId = coachConversations.first?.id
        }
    }

    static var starter: AppDatabase {
        let now = Date()
        return AppDatabase(
            tasks: [
                StudyTask(
                    title: "阅读 PPO 与 GRPO 对比笔记",
                    note: "整理关键公式、训练流程和适用场景。",
                    mode: .plan,
                    project: "强化学习",
                    startDate: now,
                    targetDate: now,
                    estimatedMinutes: 90,
                    status: .planned,
                    priority: .high,
                    createdAt: now
                ),
                StudyTask(
                    title: "复盘今天的高专注时间段",
                    note: "把分心应用和有效工具分开看。",
                    mode: .plan,
                    project: "每日复盘",
                    startDate: now,
                    targetDate: now,
                    estimatedMinutes: 20,
                    status: .planned,
                    priority: .medium,
                    createdAt: now
                )
            ],
            goals: [
                StudyGoal(
                    title: "两周内完成 PPO 小实验",
                    purpose: "把算法理解从阅读推进到可复现训练。",
                    metric: "能跑通最小环境并写出实验复盘",
                    targetDate: Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now,
                    progress: 0.18,
                    milestones: [
                        Milestone(title: "读完 PPO 代码主流程", isDone: false),
                        Milestone(title: "列出 GRPO 差异点", isDone: false),
                        Milestone(title: "完成一次训练日志复盘", isDone: false)
                    ],
                    createdAt: now,
                    logs: [
                        PlanningLogEntry(body: "目标已建立，下一步先确定最小实验环境。")
                    ]
                )
            ],
            samples: [],
            summaries: [],
            coachMessages: [
                CoachMessage(role: .assistant, content: "我会记住你的计划、目标、日志和活动记录，并在你需要时帮你调整规划。")
            ],
            coachMemory: CoachMemory(summary: "用户正在建立学习规划与活动记录系统。", keyFacts: ["计划是短期战术动作", "目标是长期战略方向"], updatedAt: now),
            settings: AppSettings()
        )
    }
}

struct AppDuration: Identifiable, Hashable {
    var id: String { appName }
    let appName: String
    let minutes: Int
}

extension Date {
    var dayKey: String {
        DateFormatters.dayKey.string(from: self)
    }

    var clockText: String {
        DateFormatters.clock.string(from: self)
    }

    var dayText: String {
        DateFormatters.day.string(from: self)
    }

    var monthDayText: String {
        DateFormatters.monthDay.string(from: self)
    }

    var dateTimeText: String {
        DateFormatters.dateTime.string(from: self)
    }

    var monthKey: String {
        DateFormatters.monthKey.string(from: self)
    }

    var monthText: String {
        DateFormatters.monthTitle.string(from: self)
    }
}

enum DateFormatters {
    static let dayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    static let monthKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter
    }()
}
