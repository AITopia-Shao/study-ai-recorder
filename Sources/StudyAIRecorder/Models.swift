import Foundation

enum WorkspaceMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case plan
    case goal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: return "计划模式"
        case .goal: return "目标模式"
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
    case system
    case boulevard
    case starlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .boulevard: return "林荫大道"
        case .starlight: return "星空"
        }
    }

    var subtitle: String {
        switch self {
        case .system: return "使用 macOS 当前外观"
        case .boulevard: return "日间、轻盈、低对比"
        case .starlight: return "夜间、沉静、护眼"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .boulevard: return "sun.max"
        case .starlight: return "moon.stars"
        }
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

struct StudyTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var note: String
    var mode: WorkspaceMode
    var project: String
    var targetDate: Date
    var estimatedMinutes: Int
    var status: TaskStatus
    var priority: TaskPriority
    var createdAt: Date
    var completedAt: Date?

    var isDueToday: Bool {
        Calendar.current.isDateInToday(targetDate)
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
    var visualTheme: AppVisualTheme = .boulevard
    var sampleInterval: TimeInterval = 30
    var includeWindowTitles: Bool = true
    var captureScreenshots: Bool = false
    var screenshotIntervalMinutes: Int = 15
    var maxSamplesPerDay: Int = 2400
    var enabledAgentSkillIDs: [String] = LearningAgentSkill.bestDefaultIDs
    var deterministicScoring: Bool = true
    var compactSummaryStyle: Bool = true

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
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? AppSettings.defaultBaseURL
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? AppSettings.defaultModel
        visualTheme = try container.decodeIfPresent(AppVisualTheme.self, forKey: .visualTheme) ?? .boulevard
        sampleInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .sampleInterval) ?? 30
        includeWindowTitles = try container.decodeIfPresent(Bool.self, forKey: .includeWindowTitles) ?? true
        captureScreenshots = try container.decodeIfPresent(Bool.self, forKey: .captureScreenshots) ?? false
        screenshotIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .screenshotIntervalMinutes) ?? 15
        maxSamplesPerDay = try container.decodeIfPresent(Int.self, forKey: .maxSamplesPerDay) ?? 2400
        enabledAgentSkillIDs = try container.decodeIfPresent([String].self, forKey: .enabledAgentSkillIDs) ?? LearningAgentSkill.bestDefaultIDs
        deterministicScoring = try container.decodeIfPresent(Bool.self, forKey: .deterministicScoring) ?? true
        compactSummaryStyle = try container.decodeIfPresent(Bool.self, forKey: .compactSummaryStyle) ?? true
    }
}

struct AppDatabase: Codable, Hashable {
    var tasks: [StudyTask] = []
    var goals: [StudyGoal] = []
    var samples: [ActivitySample] = []
    var summaries: [DailySummary] = []
    var settings = AppSettings()

    static var starter: AppDatabase {
        let now = Date()
        return AppDatabase(
            tasks: [
                StudyTask(
                    title: "阅读 PPO 与 GRPO 对比笔记",
                    note: "整理关键公式、训练流程和适用场景。",
                    mode: .plan,
                    project: "强化学习",
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
                    createdAt: now
                )
            ],
            samples: [],
            summaries: [],
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
}
