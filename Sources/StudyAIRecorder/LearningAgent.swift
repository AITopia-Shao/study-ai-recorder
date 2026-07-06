import Foundation

struct LearningDayContext: Hashable {
    let date: Date
    let tasks: [StudyTask]
    let goals: [StudyGoal]
    let samples: [ActivitySample]
    let appDurations: [AppDuration]
    let timelineBlocks: [String]
    let activeMinutes: Int
    let completedTasks: Int
    let plannedTasks: Int
    let activeAppCount: Int
    let screenTextSnippets: [String]

    init(date: Date, tasks: [StudyTask], goals: [StudyGoal], samples: [ActivitySample], settings: AppSettings) {
        self.date = date
        self.tasks = tasks
        self.goals = goals
        self.samples = samples
        appDurations = ActivityAnalyzer.durations(from: samples, sampleInterval: settings.sampleInterval)
        timelineBlocks = ActivityAnalyzer.timelineBlocks(from: samples, sampleInterval: settings.sampleInterval)
        activeMinutes = ActivityAnalyzer.totalMinutes(from: samples, sampleInterval: settings.sampleInterval)
        completedTasks = tasks.filter { $0.status == .done }.count
        plannedTasks = tasks.count
        activeAppCount = Set(samples.map(\.appName)).count
        screenTextSnippets = samples
            .compactMap { sample -> String? in
                guard let text = sample.screenText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    return nil
                }
                return "\(sample.timestamp.clockText) \(sample.appName)：\(String(text.prefix(180)))"
            }
            .suffix(16)
    }

    var evidenceLevel: EvidenceLevel {
        if activeMinutes >= 120 && timelineBlocks.count >= 6 { return .strong }
        if activeMinutes >= 35 && timelineBlocks.count >= 3 { return .medium }
        if activeMinutes >= 8 || !tasks.isEmpty || !goals.isEmpty { return .thin }
        return .empty
    }

    var topAppsText: String {
        appDurations.prefix(8)
            .map { "\($0.appName) \($0.minutes) 分钟" }
            .joined(separator: "、")
    }

    var tasksText: String {
        if tasks.isEmpty { return "无今日任务" }
        return tasks.map {
            let journal = $0.journal.suffix(3).map { "\($0.createdAt.clockText)：\($0.title) - \($0.body)" }.joined(separator: "；")
            return "- [\($0.status.title)] \($0.title) | 开始：\($0.startDate.dayText) | 完成：\($0.targetDate.dayText) | 项目：\($0.project) | 预计：\($0.estimatedMinutes) 分钟 | 优先级：\($0.priority.title) | 备注：\($0.note) | 完成记录：\($0.completionNote) | 日记：\(journal)"
        }.joined(separator: "\n")
    }

    var goalsText: String {
        if goals.isEmpty { return "无长期目标" }
        return goals.map {
            let logs = $0.logs.suffix(5).map { "\($0.createdAt.dayText)：\($0.title) - \($0.body)" }.joined(separator: "；")
            let milestones = $0.milestones.map { "\($0.isDone ? "已完成" : "未完成")-\($0.title)" }.joined(separator: "；")
            return "- \($0.title) | 进度：\(Int($0.progress * 100))% | 衡量：\($0.metric) | 截止：\($0.targetDate.dayText) | 里程碑：\(milestones) | 阶段日志：\(logs)"
        }.joined(separator: "\n")
    }
}

enum EvidenceLevel: String, Hashable {
    case empty
    case thin
    case medium
    case strong

    var title: String {
        switch self {
        case .empty: return "无有效证据"
        case .thin: return "证据偏少"
        case .medium: return "证据可用"
        case .strong: return "证据充分"
        }
    }
}

struct LearningScore: Hashable {
    let score: Int
    let confidence: String
    let reason: String
    let components: [String]
}

enum LearningScoreRubric {
    static func evaluate(_ context: LearningDayContext) -> LearningScore {
        var score = 2
        var components: [String] = []

        switch context.evidenceLevel {
        case .empty:
            components.append("没有足够轨迹，基础分保守。")
        case .thin:
            score += 1
            components.append("有少量轨迹或任务信息，但不足以判断全天。")
        case .medium:
            score += 2
            components.append("轨迹可覆盖一个以上学习片段。")
        case .strong:
            score += 3
            components.append("轨迹覆盖较长时间，证据质量较好。")
        }

        if context.plannedTasks > 0 {
            let completionRatio = Double(context.completedTasks) / Double(context.plannedTasks)
            if completionRatio >= 0.8 {
                score += 2
                components.append("今日任务完成度较高。")
            } else if completionRatio >= 0.4 {
                score += 1
                components.append("任务有推进，但闭环不足。")
            } else {
                components.append("任务完成度偏低。")
            }
        } else {
            components.append("缺少今日任务，无法判断计划执行。")
        }

        if context.activeMinutes >= 180 {
            score += 2
            components.append("记录到较长学习/工作时段。")
        } else if context.activeMinutes >= 60 {
            score += 1
            components.append("记录到可用学习/工作时段。")
        } else {
            components.append("记录时长偏短。")
        }

        if !context.goals.isEmpty && context.tasks.contains(where: { $0.priority == .high || !$0.journal.isEmpty || !$0.completionNote.isEmpty }) {
            score += 1
            components.append("存在支撑长期目标的高优先级行动或日志。")
        } else if !context.goals.isEmpty {
            components.append("有长期目标，但今日动作关联不强。")
        }

        if context.activeAppCount >= 7 && context.activeMinutes < 120 {
            score -= 1
            components.append("短时段内应用切换偏多。")
        }

        let cappedScore = min(10, max(1, score))
        let confidence: String
        switch context.evidenceLevel {
        case .empty: confidence = "很低"
        case .thin: confidence = "低"
        case .medium: confidence = "中"
        case .strong: confidence = "高"
        }

        return LearningScore(
            score: cappedScore,
            confidence: confidence,
            reason: "\(context.evidenceLevel.title)，记录 \(context.activeMinutes) 分钟，完成 \(context.completedTasks)/\(context.plannedTasks) 个今日任务。",
            components: components
        )
    }
}

struct StudyAgentReport: Codable, Hashable {
    var executiveSummary: String
    var highlights: [String]
    var obstacles: [String]
    var recommendations: [String]
    var tomorrowPlan: [String]
    var dataWarnings: [String]

    enum CodingKeys: String, CodingKey {
        case executiveSummary = "executive_summary"
        case highlights
        case obstacles
        case recommendations
        case tomorrowPlan = "tomorrow_plan"
        case dataWarnings = "data_warnings"
    }

    static func fallback(context: LearningDayContext, score: LearningScore, reason: String? = nil) -> StudyAgentReport {
        var warnings: [String] = []
        if context.evidenceLevel == .empty || context.evidenceLevel == .thin {
            warnings.append("今天轨迹不足，结论只适合作为轻量提醒。")
        }
        if let reason {
            warnings.append("AI 服务未完成：\(reason)")
        }

        let topApps = context.topAppsText.isEmpty ? "暂无应用分布" : context.topAppsText
        let summary = context.activeMinutes > 0
            ? "今天记录到 \(context.activeMinutes) 分钟轨迹，主要集中在 \(topApps)。"
            : "今天缺少连续轨迹，先把任务和目标补齐。"

        return StudyAgentReport(
            executiveSummary: summary,
            highlights: [
                context.completedTasks > 0 ? "完成了 \(context.completedTasks) 个今日任务。" : "已经开始建立记录入口。",
                context.goals.isEmpty ? "可先补一个长期目标。" : "保留了 \(context.goals.count) 个长期目标。"
            ],
            obstacles: [
                context.plannedTasks == 0 ? "今天没有明确任务，评分只能保守。" : "计划闭环仍需加强。",
                context.evidenceLevel == .strong ? "应用切换需要继续观察。" : "轨迹数据偏少，难以判断专注质量。"
            ],
            recommendations: [
                "明早先写 1 个主线任务和完成信号。",
                "每段学习结束后补 1 句产出记录。",
                "复盘时只保留 3 条最关键改进。"
            ],
            tomorrowPlan: [
                "选一个最高优先级任务先做 45 分钟。",
                "完成后记录成果文件、页码或实验结果。",
                "晚上用教练检查计划偏差。"
            ],
            dataWarnings: warnings
        )
    }

    func normalized(context: LearningDayContext, score: LearningScore) -> StudyAgentReport {
        StudyAgentReport(
            executiveSummary: clean(executiveSummary, fallback: StudyAgentReport.fallback(context: context, score: score).executiveSummary, limit: 120),
            highlights: normalizeList(highlights, fallback: StudyAgentReport.fallback(context: context, score: score).highlights, count: 2),
            obstacles: normalizeList(obstacles, fallback: StudyAgentReport.fallback(context: context, score: score).obstacles, count: 2),
            recommendations: normalizeList(recommendations, fallback: StudyAgentReport.fallback(context: context, score: score).recommendations, count: 3),
            tomorrowPlan: normalizeList(tomorrowPlan, fallback: StudyAgentReport.fallback(context: context, score: score).tomorrowPlan, count: 3),
            dataWarnings: normalizeList(dataWarnings, fallback: [], count: min(max(dataWarnings.count, 0), 2))
        )
    }

    private func normalizeList(_ values: [String], fallback: [String], count: Int) -> [String] {
        let cleaned = values.map { clean($0, fallback: "", limit: 70) }.filter { !$0.isEmpty }
        let padded = cleaned + fallback
        return Array(padded.prefix(count))
    }

    private func clean(_ value: String, fallback: String, limit: Int) -> String {
        let stripped = value
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "---", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = stripped.isEmpty ? fallback : stripped
        return String(selected.prefix(limit))
    }
}

enum LearningSummaryRenderer {
    static func render(date: Date, score: LearningScore, report: StudyAgentReport, settings: AppSettings) -> String {
        let compactSpacing = settings.compactSummaryStyle ? "\n" : "\n\n"
        let warnings = report.dataWarnings.isEmpty
            ? ""
            : "\(compactSpacing)数据边界\n\(numbered(report.dataWarnings))"

        return """
        总评
        \(report.executiveSummary)

        评分依据
        - \(score.score)/10；置信度：\(score.confidence)
        - \(score.reason)
        - \(score.components.prefix(3).joined(separator: "；"))

        亮点
        \(numbered(report.highlights))

        阻碍
        \(numbered(report.obstacles))

        改进建议
        \(numbered(report.recommendations))

        明日计划
        \(numbered(report.tomorrowPlan))\(warnings)
        """
    }

    private static func numbered(_ items: [String]) -> String {
        items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
}

enum StudyAgentPromptBuilder {
    static func systemPrompt(settings: AppSettings) -> String {
        let skills = enabledSkills(settings: settings)
            .map { "- \($0.promptInstruction)" }
            .joined(separator: "\n")

        return """
        你是 Trace 教练的总结子代理。你的任务是把学习轨迹、计划日记和目标阶段日志整理成稳定、简洁、可执行的日报 JSON。

        运行规则：
        - 只返回 JSON，不要 Markdown，不要问候语，不要解释 schema。
        - 不输出评分；评分已由本地量规锁定。
        - 不编造未出现的活动、任务、软件或成果。
        - 中文表达要短、稳、具体，每条建议只说一个动作。
        - 避免“没关系、万事开头难、加油”等空泛安慰。

        已启用 skills：
        \(skills)
        """
    }

    static func userPrompt(context: LearningDayContext, score: LearningScore) -> String {
        let timeline = context.timelineBlocks.prefix(80).map { "- \($0)" }.joined(separator: "\n")
        let apps = context.appDurations.prefix(12).map { "- \($0.appName)：\($0.minutes) 分钟" }.joined(separator: "\n")
        let screen = context.screenTextSnippets.map { "- \($0)" }.joined(separator: "\n")

        return """
        SCORING_LOCK:
        score=\(score.score)
        confidence=\(score.confidence)
        reason=\(score.reason)

        DATE:
        \(context.date.dayText)

        TASKS:
        \(context.tasksText)

        GOALS:
        \(context.goalsText)

        APP_DURATIONS:
        \(apps.isEmpty ? "暂无应用时间分布" : apps)

        TIMELINE:
        \(timeline.isEmpty ? "暂无窗口轨迹" : timeline)

        SCREEN_OCR:
        \(screen.isEmpty ? "暂无屏幕文字片段" : screen)

        OUTPUT_JSON_SCHEMA:
        {
          "executive_summary": "一句总评，60字以内",
          "highlights": ["恰好2条，每条35字以内"],
          "obstacles": ["恰好2条，每条35字以内"],
          "recommendations": ["恰好3条，每条35字以内"],
          "tomorrow_plan": ["恰好3条，每条35字以内"],
          "data_warnings": ["0到2条，只有数据不足时填写"]
        }
        """
    }

    static func enabledSkills(settings: AppSettings) -> [LearningAgentSkill] {
        let enabled = Set(settings.enabledAgentSkillIDs)
        let skills = LearningAgentSkill.allCases.filter { enabled.contains($0.rawValue) }
        return skills.isEmpty ? LearningAgentSkill.allCases : skills
    }
}
