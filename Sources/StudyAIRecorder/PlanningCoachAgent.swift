import Foundation

enum CoachActionType: String, Codable, CaseIterable, Hashable {
    case addPlan = "add_plan"
    case updatePlan = "update_plan"
    case deletePlan = "delete_plan"
    case completePlan = "complete_plan"
    case addPlanLog = "add_plan_log"
    case addGoal = "add_goal"
    case updateGoal = "update_goal"
    case deleteGoal = "delete_goal"
    case updateGoalProgress = "update_goal_progress"
    case addGoalLog = "add_goal_log"
    case readPlanningContext = "read_planning_context"
    case listCoachFiles = "list_coach_files"
    case readCoachFile = "read_coach_file"
    case writeCoachFile = "write_coach_file"
}

struct CoachAction: Identifiable, Codable, Hashable {
    var id = UUID()
    var type: CoachActionType
    var targetId: String?
    var title: String?
    var note: String?
    var project: String?
    var date: String?
    var startDate: String?
    var targetDate: String?
    var estimatedMinutes: Int?
    var priority: TaskPriority?
    var purpose: String?
    var metric: String?
    var days: Int?
    var progress: Double?
    var body: String?
    var fileName: String?
    var content: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case targetId = "target_id"
        case title
        case note
        case project
        case date
        case startDate = "start_date"
        case targetDate = "target_date"
        case estimatedMinutes = "estimated_minutes"
        case priority
        case purpose
        case metric
        case days
        case progress
        case body
        case fileName = "file_name"
        case content
    }

    init(
        id: UUID = UUID(),
        type: CoachActionType,
        targetId: String? = nil,
        title: String? = nil,
        note: String? = nil,
        project: String? = nil,
        date: String? = nil,
        startDate: String? = nil,
        targetDate: String? = nil,
        estimatedMinutes: Int? = nil,
        priority: TaskPriority? = nil,
        purpose: String? = nil,
        metric: String? = nil,
        days: Int? = nil,
        progress: Double? = nil,
        body: String? = nil,
        fileName: String? = nil,
        content: String? = nil
    ) {
        self.id = id
        self.type = type
        self.targetId = targetId
        self.title = title
        self.note = note
        self.project = project
        self.date = date
        self.startDate = startDate
        self.targetDate = targetDate
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
        self.purpose = purpose
        self.metric = metric
        self.days = days
        self.progress = progress
        self.body = body
        self.fileName = fileName
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try container.decode(CoachActionType.self, forKey: .type)
        targetId = try container.decodeIfPresent(String.self, forKey: .targetId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        targetDate = try container.decodeIfPresent(String.self, forKey: .targetDate)
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose)
        metric = try container.decodeIfPresent(String.self, forKey: .metric)
        days = try container.decodeIfPresent(Int.self, forKey: .days)
        progress = try container.decodeIfPresent(Double.self, forKey: .progress)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        content = try container.decodeIfPresent(String.self, forKey: .content)
    }
}

struct CoachToolResult: Hashable {
    let action: CoachActionType
    let success: Bool
    let message: String
}

struct CoachAgentResponse: Codable, Hashable {
    var reply: String
    var actions: [CoachAction]
    var memoryUpdate: String?
    var keyFacts: [String]
    var dailySummary: StudyAgentReport?

    enum CodingKeys: String, CodingKey {
        case reply
        case actions
        case memoryUpdate = "memory_update"
        case keyFacts = "key_facts"
        case dailySummary = "daily_summary"
    }

    init(
        reply: String,
        actions: [CoachAction] = [],
        memoryUpdate: String? = nil,
        keyFacts: [String] = [],
        dailySummary: StudyAgentReport? = nil
    ) {
        self.reply = reply
        self.actions = actions
        self.memoryUpdate = memoryUpdate
        self.keyFacts = keyFacts
        self.dailySummary = dailySummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reply = try container.decodeIfPresent(String.self, forKey: .reply) ?? ""
        actions = try container.decodeIfPresent([CoachAction].self, forKey: .actions) ?? []
        memoryUpdate = try container.decodeIfPresent(String.self, forKey: .memoryUpdate)
        keyFacts = try container.decodeIfPresent([String].self, forKey: .keyFacts) ?? []
        dailySummary = try container.decodeIfPresent(StudyAgentReport.self, forKey: .dailySummary)
    }

    func normalized(fallbackReply: String) -> CoachAgentResponse {
        CoachAgentResponse(
            reply: clean(reply, fallback: fallbackReply, limit: 900),
            actions: Array(actions.prefix(12)),
            memoryUpdate: memoryUpdate.map { clean($0, fallback: "", limit: 600) },
            keyFacts: Array(keyFacts.map { clean($0, fallback: "", limit: 80) }.filter { !$0.isEmpty }.prefix(8)),
            dailySummary: dailySummary
        )
    }

    private func clean(_ value: String, fallback: String, limit: Int) -> String {
        let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = stripped.isEmpty ? fallback : stripped
        return String(selected.prefix(limit))
    }
}

struct PlanningCoachContext: Hashable {
    let date: Date
    let plansText: String
    let goalsText: String
    let logsText: String
    let activityText: String
    let summariesText: String
    let memoryText: String
    let identityText: String
    let recentMessagesText: String

    init(database: AppDatabase, date: Date = Date()) {
        self.date = date
        let cleanIdentity = database.coachIdentity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        identityText = cleanIdentity.isEmpty ? L("未设置身份") : cleanIdentity

        let plans = database.tasks.sorted {
            if $0.targetDate == $1.targetDate {
                return $0.createdAt > $1.createdAt
            }
            return $0.targetDate < $1.targetDate
        }
        plansText = plans.isEmpty ? L("无计划") : plans.map { task in
            let done = task.completedAt.map { "\(L("完成")):\($0.dateTimeText)" } ?? L("未完成")
            let journal = task.journal.suffix(3).map { "\($0.createdAt.dateTimeText)：\($0.title) - \($0.body)" }.joined(separator: "；")
            return """
            - id=\(task.id.uuidString) | \(L("开始")):\(task.startDate.dayKey) | \(L("完成")):\(task.targetDate.dayKey) | [\(task.status.title)] \(task.title) | \(L("项目")):\(task.project) | \(L("预计")):\(task.estimatedMinutes) \(L("分钟")) | \(L("优先级")):\(task.priority.title) | \(done) | \(L("备注")):\(task.note) | \(L("完成记录")):\(task.completionNote) | \(L("日记")):\(journal)
            """
        }.joined(separator: "\n")

        goalsText = database.goals.isEmpty ? L("无目标") : database.goals.map { goal in
            let milestones = goal.milestones.map { "\($0.isDone ? L("已完成") : L("未完成"))-\($0.title)" }.joined(separator: "；")
            let logs = goal.logs.suffix(5).map { "\($0.createdAt.dateTimeText)：\($0.title) - \($0.body)" }.joined(separator: "；")
            return """
            - id=\(goal.id.uuidString) | \(goal.title) | \(L("目的")):\(goal.purpose) | \(L("衡量")):\(goal.metric) | \(L("截止")):\(goal.targetDate.dayKey) | \(L("里程碑")):\(milestones) | \(L("阶段日志")):\(logs)
            """
        }.joined(separator: "\n")

        let planLogs = database.tasks.flatMap { task in
            task.journal.map { "计划《\(task.title)》 \($0.createdAt.dateTimeText)：\($0.title) - \($0.body)" }
        }
        let goalLogs = database.goals.flatMap { goal in
            goal.logs.map { "目标《\(goal.title)》 \($0.createdAt.dateTimeText)：\($0.title) - \($0.body)" }
        }
        let allLogs = (planLogs + goalLogs).suffix(60)
        logsText = allLogs.isEmpty ? L("暂无日志") : allLogs.joined(separator: "\n")

        let samples = ActivityAnalyzer.samples(on: date, from: database.samples)
        let durations = ActivityAnalyzer.durations(from: samples, sampleInterval: database.settings.sampleInterval)
        let timeline = ActivityAnalyzer.timelineBlocks(from: samples, sampleInterval: database.settings.sampleInterval).suffix(30)
        activityText = """
        \(L("记录时长")):\(ActivityAnalyzer.totalMinutes(from: samples, sampleInterval: database.settings.sampleInterval)) \(L("分钟"))
        \(L("应用分布")):\(durations.prefix(12).map { "\($0.appName) \($0.minutes) \(L("分钟"))" }.joined(separator: "、"))
        \(L("窗口轨迹")):
        \(timeline.isEmpty ? L("暂无窗口轨迹") : timeline.map { "- \($0)" }.joined(separator: "\n"))
        """

        let summaries = database.summaries.sorted { $0.generatedAt > $1.generatedAt }.prefix(8)
        summariesText = summaries.isEmpty ? L("暂无总结") : summaries.map {
            "- \($0.dateKey) | \($0.generatedAt.dateTimeText) | \(String($0.body.prefix(260)))"
        }.joined(separator: "\n")

        memoryText = """
        \(L("身份")):\(identityText)
        \(L("摘要")):\(database.coachMemory.summary.isEmpty ? L("暂无长期记忆") : database.coachMemory.summary)
        \(L("关键事实")):\(database.coachMemory.keyFacts.joined(separator: "；"))
        \(L("更新时间")):\(database.coachMemory.updatedAt?.dateTimeText ?? L("无"))
        """

        recentMessagesText = database.currentCoachMessages.suffix(16).map {
            "- \($0.role.title) \($0.createdAt.dateTimeText)：\(String($0.content.prefix(260)))"
        }.joined(separator: "\n")
    }
}

enum PlanningCoachPromptBuilder {
    static func systemPrompt(settings: AppSettings) -> String {
        let skills = StudyAgentPromptBuilder.enabledSkills(settings: settings)
            .map { "- \($0.promptInstruction)" }
            .joined(separator: "\n")

        return """
        You are Trace's Coach, not a simple summary tool. You operate with claw-code-style agent boundaries: conversation messages, tool actions, permission boundaries, file operations, memory updates, and context compaction.
        Language: \(settings.language.promptInstruction)

        核心语义：
        - 计划 = 短期、明确、可执行的战术动作，必须有日期、完成信号或预计时长。
        - 目标 = 长期、笼统、战略性的方向，必须体现目的、衡量方式、阶段日志。
        - 今日页负责展示、完成记录、计划日记和目标阶段日志；新增、调整、删除应通过规划页或你输出的工具动作完成。
        - 身份信息是用户长期背景，例如“大一计算机科学学生”。你必须用它调整建议口吻、难度和优先级，但不能通过工具动作修改身份。

        你可以输出的工具动作：
        - add_plan: title, note, project, start_date(yyyy-MM-dd), target_date(yyyy-MM-dd), estimated_minutes, priority(low/medium/high)
        - update_plan: target_id, title?, note?, project?, start_date?, target_date? 或 date?, estimated_minutes?, priority?
        - delete_plan: target_id
        - complete_plan: target_id, title?, body?
        - add_plan_log: target_id, title?, body
        - add_goal: title, purpose, metric, days
        - update_goal: target_id, title?, purpose?, metric?, days?
        - delete_goal: target_id
        - add_goal_log: target_id, title?, body
        - read_planning_context
        - list_coach_files
        - read_coach_file: file_name
        - write_coach_file: file_name, content

        权限边界：
        - 只能操作用户的计划、目标、日志、总结、活动记录和教练文件区。
        - 删除前必须在 reply 中明确说明删除对象；无法确定 target_id 时不要删除。
        - 不编造活动记录、日志或文件内容；缺证据就说明数据不足。
        - 文件操作只限教练文件区，不要声称访问了系统其它路径。

        已启用总结能力：
        \(skills)

        只返回 JSON 对象，不要把 JSON 包进 Markdown 代码块。Use the selected language for reply, memory_update, key_facts, and daily_summary values. reply 字段可以使用 Markdown 标题、列表和 LaTeX 数学公式。JSON schema:
        {
          "reply": "natural language reply in the selected language",
          "actions": [
            {
              "type": "add_plan|update_plan|delete_plan|complete_plan|add_plan_log|add_goal|update_goal|delete_goal|add_goal_log|read_planning_context|list_coach_files|read_coach_file|write_coach_file",
              "target_id": "optional UUID",
              "title": "optional",
              "note": "optional",
              "project": "optional",
              "date": "yyyy-MM-dd optional, legacy alias for target_date",
              "start_date": "yyyy-MM-dd optional",
              "target_date": "yyyy-MM-dd optional",
              "estimated_minutes": 45,
              "priority": "low|medium|high optional",
              "purpose": "optional",
              "metric": "optional",
              "days": 14,
              "progress": 0.25,
              "body": "log body or completion note",
              "file_name": "optional file name.md",
              "content": "optional file content"
            }
          ],
          "memory_update": "optional long-term memory summary in the selected language",
          "key_facts": ["optional stable facts in the selected language"],
          "daily_summary": {
            "executive_summary": "optional, selected language",
            "highlights": [],
            "obstacles": [],
            "recommendations": [],
            "tomorrow_plan": [],
            "data_warnings": []
          }
        }
        """
    }

    static func userPrompt(input: String, context: PlanningCoachContext) -> String {
        """
        USER_INPUT:
        \(input)

        TODAY:
        \(context.date.dayKey)

        IDENTITY:
        \(context.identityText)

        MEMORY:
        \(context.memoryText)

        PLANS:
        \(context.plansText)

        GOALS:
        \(context.goalsText)

        LOGS:
        \(context.logsText)

        ACTIVITY_RECORDS:
        \(context.activityText)

        SAVED_SUMMARIES:
        \(context.summariesText)

        RECENT_CONVERSATION:
        \(context.recentMessagesText)
        """
    }
}

enum PlanningCoachAgent {
    static func decodeResponse(from content: String, fallbackReply: String) throws -> CoachAgentResponse {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end {
            jsonText = String(trimmed[start...end])
        } else {
            jsonText = trimmed
        }

        guard let data = jsonText.data(using: .utf8) else {
            throw AIClientError.badResponse(L("教练 JSON 编码无效"))
        }

        return try JSONDecoder().decode(CoachAgentResponse.self, from: data)
            .normalized(fallbackReply: fallbackReply)
    }

    static func localFallback(input: String, database: AppDatabase, reason: String) -> CoachAgentResponse {
        TraceLocalization.current = database.settings.language
        let context = PlanningCoachContext(database: database)
        let lower = input.lowercased()
        let actions: [CoachAction] = []

        if lower.contains("总结") || lower.contains("复盘") {
            return CoachAgentResponse(
                reply: """
                \(L("AI 服务暂时不可用，我先用本地数据给出简要复盘")): \(L("今天记录到")) \(ActivityAnalyzer.totalMinutes(from: ActivityAnalyzer.samples(on: Date(), from: database.samples), sampleInterval: database.settings.sampleInterval)) \(L("分钟")); \(L("今日计划")) \(database.tasks.filter { $0.startDate.dayKey <= Date().dayKey && Date().dayKey <= $0.targetDate.dayKey }.count); \(L("长期目标")) \(database.goals.count). \(L("服务原因")): \(reason)
                """,
                actions: actions,
                memoryUpdate: database.coachMemory.summary,
                keyFacts: database.coachMemory.keyFacts
            )
        }

        if input.contains("查看") || input.contains("所有") || input.contains("日志") || input.contains("记录") {
            return CoachAgentResponse(
                reply: """
                \(L("AI 服务暂时不可用，我可以先读取本地上下文")). \(L("计划")): \(database.tasks.count); \(L("目标")): \(database.goals.count); \(L("最近日志")): \(String(context.logsText.prefix(500))). \(L("服务原因")): \(reason)
                """,
                actions: [.init(type: .readPlanningContext)],
                memoryUpdate: database.coachMemory.summary,
                keyFacts: database.coachMemory.keyFacts
            )
        }

        return CoachAgentResponse(
            reply: "\(L("教练暂时无法调用模型")): \(reason). \(L("本地数据仍可查看，计划与目标可以在规划里继续编辑。"))",
            actions: actions,
            memoryUpdate: database.coachMemory.summary,
            keyFacts: database.coachMemory.keyFacts
        )
    }
}
