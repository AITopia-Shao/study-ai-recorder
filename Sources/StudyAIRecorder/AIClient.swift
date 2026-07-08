import Foundation

struct AIClient {
    let settings: AppSettings
    let apiKey: String

    func generateSummary(date: Date, tasks: [StudyTask], goals: [StudyGoal], samples: [ActivitySample]) async throws -> DailySummary {
        TraceLocalization.current = settings.language
        let context = LearningDayContext(date: date, tasks: tasks, goals: goals, samples: samples, settings: settings)
        let score = LearningScoreRubric.evaluate(context)

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingAPIKey
        }

        let messages = [
            ChatMessage(role: "system", content: StudyAgentPromptBuilder.systemPrompt(settings: settings)),
            ChatMessage(role: "user", content: StudyAgentPromptBuilder.userPrompt(context: context, score: score))
        ]

        let content = try await sendChat(messages: messages, temperature: 0.1)

        let report = try Self.decodeReport(from: content)
            .normalized(context: context, score: score)
        let body = LearningSummaryRenderer.render(date: date, score: score, report: report, settings: settings)

        return DailySummary(
            dateKey: date.dayKey,
            generatedAt: Date(),
            score: score.score,
            body: body,
            model: settings.model
        )
    }

    static func localSummary(date: Date, tasks: [StudyTask], goals: [StudyGoal], samples: [ActivitySample], settings: AppSettings = AppSettings(), reason: String) -> DailySummary {
        TraceLocalization.current = settings.language
        let context = LearningDayContext(date: date, tasks: tasks, goals: goals, samples: samples, settings: settings)
        let score = LearningScoreRubric.evaluate(context)
        let report = StudyAgentReport.fallback(context: context, score: score, reason: reason)
        let body = LearningSummaryRenderer.render(date: date, score: score, report: report, settings: settings)

        return DailySummary(
            dateKey: date.dayKey,
            generatedAt: Date(),
            score: score.score,
            body: body,
            model: L("本地启发式")
        )
    }

    func runPlanningCoach(input: String, database: AppDatabase) async throws -> CoachAgentResponse {
        TraceLocalization.current = settings.language
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingAPIKey
        }

        let context = PlanningCoachContext(database: database)
        let messages = [
            ChatMessage(role: "system", content: PlanningCoachPromptBuilder.systemPrompt(settings: settings)),
            ChatMessage(role: "user", content: PlanningCoachPromptBuilder.userPrompt(input: input, context: context))
        ]

        let content = try await sendChat(messages: messages, temperature: 0.2)
        return try PlanningCoachAgent.decodeResponse(
            from: content,
            fallbackReply: L("我读完了当前规划上下文，但模型回复没有给出可展示内容。")
        )
    }

    private func sendChat(messages: [ChatMessage], temperature: Double) async throws -> String {
        let endpoint = try chatCompletionsURL(baseURL: settings.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: settings.model,
                messages: messages,
                temperature: temperature
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? L("空响应")
            throw AIClientError.badResponse(body)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let content, !content.isEmpty else {
            throw AIClientError.badResponse(L("AI 没有返回可读内容。"))
        }
        return content
    }

    private func chatCompletionsURL(baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/chat/completions") else {
            throw AIClientError.invalidBaseURL
        }
        return url
    }

    private static func decodeReport(from content: String) throws -> StudyAgentReport {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end {
            jsonText = String(trimmed[start...end])
        } else {
            jsonText = trimmed
        }

        guard let data = jsonText.data(using: .utf8) else {
            throw AIClientError.badResponse(L("AI JSON 编码无效"))
        }
        return try JSONDecoder().decode(StudyAgentReport.self, from: data)
    }
}

enum AIClientError: LocalizedError {
    case missingAPIKey
    case invalidBaseURL
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return L("还没有保存 API Key")
        case .invalidBaseURL:
            return L("API URL 无效")
        case .badResponse(let body):
            return "\(L("AI 服务返回异常")): \(body)"
        }
    }
}

struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}
