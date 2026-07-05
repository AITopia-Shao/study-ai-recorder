import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            ZStack {
                AppColors.canvas.ignoresSafeArea()
                detailView
                    .padding(28)
            }
        }
        .preferredColorScheme(state.database.settings.visualTheme.preferredColorScheme)
        .tint(AppColors.accent)
    }

    @ViewBuilder
    private var detailView: some View {
        switch state.selectedSection {
        case .today:
            TodayView()
        case .plan:
            PlanView()
        case .goals:
            GoalsView()
        case .monitor:
            MonitorView()
        case .summary:
            SummaryView()
        case .settings:
            SettingsView()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 34, height: 34)
                        .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Study Trace")
                            .font(.title3.weight(.semibold))
                        Text("AI 学习记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SidebarGroup(title: "工作台") {
                        ForEach([AppSection.today, .plan, .goals, .monitor, .summary]) { section in
                            SidebarButton(section: section)
                        }
                    }

                    SidebarGroup(title: "系统") {
                        SidebarButton(section: .settings)
                    }
                }
                .padding(.horizontal, 14)
            }

            MonitorStatusPill()
                .padding(16)
        }
        .background(AppColors.sidebar)
    }
}

struct SidebarGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            VStack(spacing: 4) {
                content
            }
        }
    }
}

struct SidebarButton: View {
    @EnvironmentObject private var state: AppState
    let section: AppSection

    var isSelected: Bool {
        state.selectedSection == section
    }

    var body: some View {
        Button {
            state.selectedSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? AppColors.accent : .secondary)
                Text(section.title)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(isSelected ? AppColors.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? AppColors.accent.opacity(0.20) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MonitorStatusPill: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state.monitor.isRunning ? AppColors.good : .secondary)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.monitor.isRunning ? "正在记录" : "记录暂停")
                    .font(.callout.weight(.semibold))
                Text(state.monitor.latestSample?.appName ?? "等待采样")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                state.monitor.isRunning ? state.monitor.stop() : state.monitor.start()
            } label: {
                Image(systemName: state.monitor.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.border, lineWidth: 1)
        }
    }
}

struct TodayView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(
                    title: "今日轨迹",
                    subtitle: Date().dayText,
                    actions: {
                        ModePicker()
                        MonitorButton()
                        GenerateSummaryButton()
                    }
                )

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    MetricCard(title: "今日任务", value: "\(state.todaysTasks().count)", icon: "checkmark.circle")
                    MetricCard(title: "已完成", value: "\(state.todaysTasks().filter { $0.status == .done }.count)", icon: "seal")
                    MetricCard(title: "记录时长", value: "\(ActivityAnalyzer.totalMinutes(from: state.todaysSamples(), sampleInterval: state.database.settings.sampleInterval)) 分", icon: "timer")
                    MetricCard(title: "AI 评分", value: state.latestSummary()?.score.description ?? "-", icon: "sparkles")
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 18) {
                        QuickTaskCard(mode: state.selectedMode)
                        TaskListCard(mode: state.selectedMode, title: state.selectedMode == .plan ? "今日计划" : "目标动作")
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 18) {
                        AppUsageCard()
                        TimelineCard()
                    }
                    .frame(width: 360)
                }
            }
            .frame(maxWidth: 1240, alignment: .leading)
        }
    }
}

struct PlanView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(
                    title: "计划",
                    subtitle: "把今天的学习拆成可以完成的动作",
                    actions: {
                        MonitorButton()
                    }
                )

                HStack(alignment: .top, spacing: 18) {
                    QuickTaskCard(mode: .plan)
                        .frame(width: 360)
                    TaskListCard(mode: .plan, title: "计划列表")
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }
}

struct GoalsView: View {
    @EnvironmentObject private var state: AppState
    @State private var title = ""
    @State private var purpose = ""
    @State private var metric = ""
    @State private var days = 14.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(
                    title: "目标",
                    subtitle: "把学习愿望变成有期限、有衡量方式的推进线",
                    actions: {
                        MonitorButton()
                    }
                )

                HStack(alignment: .top, spacing: 18) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("新目标")
                                .font(.headline)
                            TextField("目标名称", text: $title)
                                .textFieldStyle(.roundedBorder)
                            TextField("为什么做", text: $purpose, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                            TextField("衡量方式", text: $metric)
                                .textFieldStyle(.roundedBorder)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("周期 \(Int(days)) 天")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(value: $days, in: 3...90, step: 1)
                            }
                            Button {
                                state.addGoal(title: title, purpose: purpose, metric: metric, days: Int(days))
                                title = ""
                                purpose = ""
                                metric = ""
                                days = 14
                            } label: {
                                Label("添加目标", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .frame(width: 360)

                    VStack(spacing: 14) {
                        ForEach(state.database.goals) { goal in
                            GoalCard(goal: goal)
                        }
                    }
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }
}

struct MonitorView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(
                    title: "监控",
                    subtitle: "进程、窗口与可选屏幕快照",
                    actions: {
                        MonitorButton()
                    }
                )

                HStack(alignment: .top, spacing: 18) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("当前采样")
                                .font(.headline)
                            if let sample = state.monitor.latestSample {
                                InfoRow(label: "应用", value: sample.appName)
                                InfoRow(label: "窗口", value: sample.windowTitle ?? "未获取")
                                InfoRow(label: "时间", value: sample.timestamp.clockText)
                                InfoRow(label: "进程", value: "\(sample.processID)")
                                if let text = sample.screenText, !text.isEmpty {
                                    InfoRow(label: "屏幕", value: text)
                                }
                            } else {
                                Text("暂无采样")
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                state.monitor.collectNow()
                            } label: {
                                Label("立即采样", systemImage: "dot.scope")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(width: 360)

                    VStack(spacing: 18) {
                        AppUsageCard()
                        TimelineCard(limit: 24)
                    }
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }
}

struct SummaryView: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedDate = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(
                    title: "AI 总结",
                    subtitle: "稳定评分、结构化复盘、短建议",
                    actions: {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                        GenerateSummaryButton(date: selectedDate)
                    }
                )

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 18) {
                        if let summary = state.latestSummary(for: selectedDate) {
                            HStack(spacing: 14) {
                                Text("评分：\(summary.score)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(scoreColor(summary.score))
                                Text(summary.model)
                                    .foregroundStyle(.secondary)
                                Text(summary.generatedAt.clockText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Divider()
                            Text(summary.body)
                                .font(.body)
                                .lineSpacing(6)
                                .textSelection(.enabled)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.largeTitle)
                                    .foregroundStyle(AppColors.accent)
                                Text("还没有这一天的总结")
                                    .font(.headline)
                                Text("生成后会保存在本机数据库里。")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 1000, alignment: .leading)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(title: "设置", subtitle: "AI、采样与本地记录", actions: {})

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("外观")
                            .font(.headline)
                        Picker("主题", selection: Binding(
                            get: { state.database.settings.visualTheme },
                            set: { value in state.updateSettings { $0.visualTheme = value } }
                        )) {
                            ForEach(AppVisualTheme.allCases) { theme in
                                Label(theme.title, systemImage: theme.systemImage)
                                    .tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 12) {
                            ForEach([AppVisualTheme.boulevard, .starlight]) { theme in
                                ThemePreview(theme: theme)
                            }
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI 接口")
                            .font(.headline)
                        TextField("API URL", text: Binding(
                            get: { state.database.settings.baseURL },
                            set: { value in state.updateSettings { $0.baseURL = value } }
                        ))
                        .textFieldStyle(.roundedBorder)

                        TextField("模型", text: Binding(
                            get: { state.database.settings.model },
                            set: { value in state.updateSettings { $0.model = value } }
                        ))
                        .textFieldStyle(.roundedBorder)

                        SecureField("API Key", text: $state.apiKeyDraft)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button {
                                state.saveAPIKey()
                            } label: {
                                Label("保存 Key", systemImage: "key")
                            }
                            .buttonStyle(.borderedProminent)

                            if let status = state.statusMessage {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("学习 Agent")
                                    .font(.headline)
                                Text("评分由本地量规锁定，模型只负责证据归纳和建议。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("精简风格", isOn: Binding(
                                get: { state.database.settings.compactSummaryStyle },
                                set: { value in state.updateSettings { $0.compactSummaryStyle = value } }
                            ))
                            .toggleStyle(.switch)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                            ForEach(LearningAgentSkill.allCases) { skill in
                                AgentSkillRow(skill: skill)
                            }
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("采样")
                            .font(.headline)
                        Picker("频率", selection: Binding(
                            get: { state.database.settings.sampleInterval },
                            set: { value in state.updateSettings { $0.sampleInterval = value } }
                        )) {
                            Text("15 秒").tag(15.0)
                            Text("30 秒").tag(30.0)
                            Text("60 秒").tag(60.0)
                            Text("120 秒").tag(120.0)
                        }
                        .pickerStyle(.segmented)

                        Toggle("记录窗口标题", isOn: Binding(
                            get: { state.database.settings.includeWindowTitles },
                            set: { value in state.updateSettings { $0.includeWindowTitles = value } }
                        ))

                        Toggle("保存屏幕快照", isOn: Binding(
                            get: { state.database.settings.captureScreenshots },
                            set: { value in state.updateSettings { $0.captureScreenshots = value } }
                        ))

                        Stepper(
                            "快照间隔 \(state.database.settings.screenshotIntervalMinutes) 分钟",
                            value: Binding(
                                get: { state.database.settings.screenshotIntervalMinutes },
                                set: { value in state.updateSettings { $0.screenshotIntervalMinutes = value } }
                            ),
                            in: 5...120,
                            step: 5
                        )
                    }
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(28)
        }
        .background(AppColors.canvas)
        .preferredColorScheme(state.database.settings.visualTheme.preferredColorScheme)
    }
}

struct ThemePreview: View {
    let theme: AppVisualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(theme.title, systemImage: theme.systemImage)
                    .font(.callout.weight(.semibold))
                Spacer()
                if theme == .boulevard {
                    swatch(AppColors.boulevardLeaf)
                    swatch(AppColors.boulevardSky)
                    swatch(AppColors.boulevardSun)
                } else {
                    swatch(AppColors.starMint)
                    swatch(AppColors.starGold)
                    swatch(AppColors.starViolet)
                }
            }
            Text(theme.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.selection, in: RoundedRectangle(cornerRadius: 8))
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

struct AgentSkillRow: View {
    let skill: LearningAgentSkill

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppColors.good)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.title)
                    .font(.callout.weight(.semibold))
                Text(skill.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppColors.selection, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct QuickTaskCard: View {
    @EnvironmentObject private var state: AppState
    let mode: WorkspaceMode

    @State private var title = ""
    @State private var note = ""
    @State private var project = "学习"
    @State private var minutes = 45.0
    @State private var priority: TaskPriority = .medium

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(mode.title, systemImage: mode.systemImage)
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $priority) {
                        ForEach(TaskPriority.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 88)
                }

                TextField(mode == .plan ? "今天要完成什么" : "朝目标推进什么", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)

                TextField("备注", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("项目", text: $project)
                        .textFieldStyle(.roundedBorder)
                    Stepper("\(Int(minutes)) 分", value: $minutes, in: 5...240, step: 5)
                        .frame(width: 135)
                }

                Button(action: add) {
                    Label("添加", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func add() {
        state.addTask(
            title: title,
            note: note,
            mode: mode,
            project: project,
            estimatedMinutes: Int(minutes),
            priority: priority
        )
        title = ""
        note = ""
    }
}

struct TaskListCard: View {
    @EnvironmentObject private var state: AppState
    let mode: WorkspaceMode
    let title: String

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                let tasks = state.todaysTasks(mode: mode)
                if tasks.isEmpty {
                    Text("暂无任务")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                } else {
                    ForEach(tasks) { task in
                        TaskRow(task: task)
                        if task.id != tasks.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject private var state: AppState
    let task: StudyTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                state.setTaskStatus(task, status: task.status == .done ? .planned : .done)
            } label: {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .done ? AppColors.good : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(task.status == .done)
                if !task.note.isEmpty {
                    Text(task.note)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Tag(text: task.project, color: AppColors.accent)
                    Tag(text: "\(task.estimatedMinutes) 分", color: AppColors.steel)
                    Tag(text: task.priority.title, color: priorityColor)
                    Picker("", selection: Binding(
                        get: { task.status },
                        set: { state.setTaskStatus(task, status: $0) }
                    )) {
                        ForEach(TaskStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 104)
                }
            }
            Spacer()
            Button {
                state.removeTask(task)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return AppColors.steel
        case .medium: return AppColors.accent
        case .high: return AppColors.warning
        }
    }
}

struct GoalCard: View {
    @EnvironmentObject private var state: AppState
    let goal: StudyGoal

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.title)
                            .font(.headline)
                        Text(goal.purpose.isEmpty ? goal.metric : goal.purpose)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        state.removeGoal(goal)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                ProgressView(value: goal.progress)
                    .tint(AppColors.good)
                HStack {
                    Text("进度 \(Int(goal.progress * 100))%")
                    Spacer()
                    Text("截止 \(goal.targetDate.dayText)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { goal.progress },
                    set: { state.updateGoalProgress(goal, progress: $0) }
                ), in: 0...1)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(goal.milestones) { milestone in
                        Button {
                            state.toggleMilestone(milestone, in: goal)
                        } label: {
                            HStack {
                                Image(systemName: milestone.isDone ? "checkmark.square.fill" : "square")
                                Text(milestone.title)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(milestone.isDone ? AppColors.good : .primary)
                    }
                }
            }
        }
    }
}

struct AppUsageCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("应用时间")
                    .font(.headline)
                let durations = state.appDurations()
                if durations.isEmpty {
                    Text("开始监控后显示")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    let maxMinutes = max(durations.first?.minutes ?? 1, 1)
                    ForEach(durations.prefix(8)) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.appName)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.minutes) 分")
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColors.accent.opacity(0.16))
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(AppColors.accent)
                                            .frame(width: proxy.size.width * CGFloat(item.minutes) / CGFloat(maxMinutes))
                                    }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
    }
}

struct TimelineCard: View {
    @EnvironmentObject private var state: AppState
    var limit = 12

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("窗口轨迹")
                    .font(.headline)
                let blocks = ActivityAnalyzer.timelineBlocks(
                    from: state.todaysSamples(),
                    sampleInterval: state.database.settings.sampleInterval
                )
                if blocks.isEmpty {
                    Text("暂无轨迹")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(blocks.suffix(limit).enumerated()), id: \.offset) { _, block in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(AppColors.good)
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)
                            Text(block)
                                .lineLimit(2)
                                .font(.callout)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

struct HeaderBar<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                actions
            }
        }
    }
}

struct ModePicker: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Picker("", selection: $state.selectedMode) {
            ForEach(WorkspaceMode.allCases) { mode in
                Label(mode.shortTitle, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 170)
    }
}

struct MonitorButton: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Button {
            state.monitor.isRunning ? state.monitor.stop() : state.monitor.start()
        } label: {
            Label(state.monitor.isRunning ? "暂停" : "开始", systemImage: state.monitor.isRunning ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.bordered)
    }
}

struct GenerateSummaryButton: View {
    @EnvironmentObject private var state: AppState
    var date = Date()

    var body: some View {
        Button {
            Task {
                await state.generateSummary(for: date)
            }
        } label: {
            Label(state.isGeneratingSummary ? "生成中" : "生成 AI 总结", systemImage: "sparkles")
        }
        .buttonStyle(.borderedProminent)
        .disabled(state.isGeneratingSummary)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        SurfaceCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 34, height: 34)
                    .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.weight(.bold))
                }
                Spacer()
            }
        }
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            }
    }
}

struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

enum AppColors {
    static let canvas = adaptive(light: NSColor(red: 0.98, green: 0.98, blue: 0.95, alpha: 1), dark: NSColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1))
    static let surface = adaptive(light: NSColor(red: 1.00, green: 0.99, blue: 0.96, alpha: 1), dark: NSColor(red: 0.10, green: 0.11, blue: 0.17, alpha: 1))
    static let border = adaptive(light: NSColor(red: 0.79, green: 0.82, blue: 0.74, alpha: 1), dark: NSColor(red: 0.24, green: 0.26, blue: 0.36, alpha: 1)).opacity(0.72)
    static let sidebar = canvas
    static let selection = adaptive(light: NSColor(red: 0.92, green: 0.96, blue: 0.88, alpha: 1), dark: NSColor(red: 0.15, green: 0.18, blue: 0.26, alpha: 1))
    static let accent = adaptive(light: NSColor(red: 0.08, green: 0.43, blue: 0.32, alpha: 1), dark: NSColor(red: 0.46, green: 0.82, blue: 0.70, alpha: 1))
    static let good = adaptive(light: NSColor(red: 0.12, green: 0.55, blue: 0.31, alpha: 1), dark: NSColor(red: 0.48, green: 0.86, blue: 0.55, alpha: 1))
    static let warning = adaptive(light: NSColor(red: 0.76, green: 0.31, blue: 0.19, alpha: 1), dark: NSColor(red: 1.00, green: 0.63, blue: 0.38, alpha: 1))
    static let steel = adaptive(light: NSColor(red: 0.30, green: 0.40, blue: 0.48, alpha: 1), dark: NSColor(red: 0.62, green: 0.70, blue: 0.80, alpha: 1))
    static let boulevardLeaf = Color(red: 0.08, green: 0.43, blue: 0.32)
    static let boulevardSky = Color(red: 0.27, green: 0.55, blue: 0.72)
    static let boulevardSun = Color(red: 0.86, green: 0.64, blue: 0.27)
    static let starMint = Color(red: 0.46, green: 0.82, blue: 0.70)
    static let starGold = Color(red: 0.93, green: 0.74, blue: 0.36)
    static let starViolet = Color(red: 0.55, green: 0.51, blue: 0.86)

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }
}

extension AppVisualTheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .boulevard: return .light
        case .starlight: return .dark
        }
    }
}

private func scoreColor(_ score: Int) -> Color {
    if score >= 8 { return AppColors.good }
    if score >= 5 { return AppColors.boulevardSun }
    return AppColors.warning
}
