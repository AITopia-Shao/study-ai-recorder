import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @State private var isSidebarHidden = false

    var body: some View {
        let _ = AppColors.configure(state.database.settings)
        HStack(spacing: 0) {
            if !isSidebarHidden {
                SidebarView()
                    .frame(width: 260)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            ZStack {
                AppColors.canvas
                    .ignoresSafeArea()
                detailView
                    .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(state.database.settings.visualTheme.preferredColorScheme)
        .tint(AppColors.accent)
        .environment(\.traceTheme, TraceThemePalette(settings: state.database.settings))
        .background(TitlebarSidebarToggle(isSidebarHidden: $isSidebarHidden).frame(width: 0, height: 0))
    }

    @ViewBuilder
    private var detailView: some View {
        switch state.selectedSection {
        case .today:
            TodayView()
        case .planning:
            PlanningView()
        case .monitor:
            MonitorView()
        case .coach:
            CoachView()
        case .settings:
            SettingsView()
        }
    }
}

struct TitlebarSidebarToggle: NSViewRepresentable {
    @Binding var isSidebarHidden: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isSidebarHidden: $isSidebarHidden)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.install(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isSidebarHidden = $isSidebarHidden
        context.coordinator.updateButton()
        DispatchQueue.main.async {
            context.coordinator.install(from: nsView)
        }
    }

    final class Coordinator: NSObject {
        var isSidebarHidden: Binding<Bool>
        private weak var window: NSWindow?
        private var accessory: NSTitlebarAccessoryViewController?
        private var button: NSButton?

        init(isSidebarHidden: Binding<Bool>) {
            self.isSidebarHidden = isSidebarHidden
        }

        deinit {
            removeAccessory()
        }

        func install(from view: NSView) {
            guard let window = view.window else { return }
            if self.window === window, accessory != nil {
                updateButton()
                return
            }

            removeAccessory()

            let container = NSView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
            let button = NSButton(frame: .zero)
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(toggleSidebar)
            button.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 24),
                button.heightAnchor.constraint(equalToConstant: 24)
            ])

            let accessory = NSTitlebarAccessoryViewController()
            accessory.view = container
            accessory.layoutAttribute = .left

            window.addTitlebarAccessoryViewController(accessory)
            self.window = window
            self.accessory = accessory
            self.button = button
            updateButton()
        }

        func updateButton() {
            let symbolName = isSidebarHidden.wrappedValue ? "sidebar.leading" : "sidebar.left"
            button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            button?.contentTintColor = .secondaryLabelColor
            button?.toolTip = isSidebarHidden.wrappedValue ? "展开侧边栏" : "折叠侧边栏"
        }

        @objc private func toggleSidebar() {
            withAnimation(.snappy(duration: 0.18)) {
                isSidebarHidden.wrappedValue.toggle()
            }
            updateButton()
        }

        private func removeAccessory() {
            guard let window, let accessory else { return }
            for (index, controller) in window.titlebarAccessoryViewControllers.enumerated().reversed() where controller === accessory {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            self.accessory = nil
            self.button = nil
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @State private var isCoachExpanded = true

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Button {
                    state.selectedSection = .settings
                } label: {
                    Image(systemName: "brain.head.profile")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 34, height: 34)
                        .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("设置")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trace")
                        .font(.title3.weight(.semibold))
                    Text("记录与教练")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SidebarGroup(title: "工作台") {
                        ForEach([AppSection.today, .planning, .monitor]) { section in
                            SidebarButton(section: section)
                        }
                        CoachSidebarSection(isExpanded: $isCoachExpanded)
                    }
                }
                .padding(.horizontal, 14)
            }

            VStack(spacing: 10) {
                MonitorStatusPill()
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GlassSidebarBackground(tint: sidebarTint)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppColors.border.opacity(0.72))
                .frame(width: 1)
        }
    }

    private var sidebarTint: Color {
        switch state.database.settings.visualTheme {
        case .day:
            return Color.white.opacity(0.38)
        case .night:
            return Color(red: 0.06, green: 0.07, blue: 0.12).opacity(0.52)
        case .custom:
            return state.database.settings.customSidebarColor.color.opacity(0.48)
        }
    }
}

struct GlassSidebarBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            MacSidebarVisualEffect()
            Rectangle()
                .fill(tint)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .ignoresSafeArea()
    }
}

struct MacSidebarVisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
        nsView.blendingMode = .behindWindow
        nsView.state = .active
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
        .help(section.title)
    }
}

struct CoachSidebarSection: View {
    @EnvironmentObject private var state: AppState
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    state.selectedSection = .coach
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: AppSection.coach.systemImage)
                            .frame(width: 20)
                            .foregroundStyle(isSelected ? AppColors.accent : .secondary)
                        Text(AppSection.coach.title)
                            .font(.callout.weight(isSelected ? .semibold : .medium))
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
                .help("教练")

                Button {
                    state.startNewCoachConversation()
                    state.selectedSection = .coach
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 28)
                }
                .buttonStyle(.borderless)
                .help("新对话")

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 20, height: 28)
                }
                .buttonStyle(.borderless)
                .help(isExpanded ? "收起对话" : "展开对话")
            }

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(sortedConversations) { conversation in
                        SidebarConversationRow(conversation: conversation)
                    }
                }
                .padding(.leading, 28)
            }
        }
    }

    private var isSelected: Bool {
        state.selectedSection == .coach
    }

    private var sortedConversations: [CoachConversation] {
        state.database.coachConversations.sorted { $0.updatedAt > $1.updatedAt }
    }
}

struct SidebarConversationRow: View {
    @EnvironmentObject private var state: AppState
    let conversation: CoachConversation
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var titleFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "bubble.left.fill" : "bubble.left")
                .font(.caption)
                .foregroundStyle(isActive ? AppColors.accent : .secondary)
            if isEditing {
                TextField("对话标题", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .focused($titleFieldFocused)
                    .onSubmit(commitRename)
            } else {
                Text(conversation.title)
                    .font(.caption.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if isEditing {
                Button {
                    commitRename()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .help("确认")

                Button {
                    cancelRename()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .help("取消")
            } else {
                Button {
                    beginRename()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .help("重命名")

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("删除对话")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(isActive ? AppColors.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                state.selectCoachConversation(conversation)
                state.selectedSection = .coach
            }
        }
        .confirmationDialog("删除对话？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                state.deleteCoachConversation(conversation)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不会影响教练记忆和身份信息。")
        }
    }

    private var isActive: Bool {
        state.database.activeCoachConversationId == conversation.id
    }

    private func beginRename() {
        draftTitle = conversation.title
        isEditing = true
        DispatchQueue.main.async {
            titleFieldFocused = true
        }
    }

    private func commitRename() {
        state.renameCoachConversation(conversation, title: draftTitle)
        isEditing = false
        titleFieldFocused = false
    }

    private func cancelRename() {
        draftTitle = conversation.title
        isEditing = false
        titleFieldFocused = false
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
            Toggle("", isOn: Binding(
                get: { state.monitor.isRunning },
                set: { value in
                    value ? state.monitor.start() : state.monitor.stop()
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .background(AppColors.surface.opacity(0.66), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.border, lineWidth: 1)
        }
    }
}

struct TodayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(title: "今日", subtitle: Date().dayText, actions: {})

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        TodayPlansCard()
                            .frame(maxWidth: .infinity)
                        TodayGoalsCard()
                            .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 18) {
                        TodayPlansCard()
                        TodayGoalsCard()
                    }
                }
            }
            .frame(maxWidth: 1240, alignment: .leading)
        }
    }
}

struct TodayPlansCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("今日计划")
                    .font(.headline)
                let tasks = state.todaysTasks()
                if tasks.isEmpty {
                    EmptyStateText("暂无今日计划")
                } else {
                    ForEach(tasks) { task in
                        TodayPlanRow(task: task)
                        if task.id != tasks.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct TodayPlanRow: View {
    @EnvironmentObject private var state: AppState
    let task: StudyTask
    @State private var diaryTitle = ""
    @State private var diaryBody = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    if task.status == .done {
                        state.setTaskStatus(task, status: .planned)
                    } else {
                        state.completeTask(task, title: diaryTitle, body: diaryBody)
                        clearDraft()
                    }
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
                    }
                    HStack(spacing: 8) {
                        Tag(text: task.project, color: AppColors.accent)
                        Tag(text: "\(task.startDate.monthDayText)-\(task.targetDate.monthDayText)", color: AppColors.accent)
                        Tag(text: "\(task.estimatedMinutes) 分", color: AppColors.steel)
                        Tag(text: task.priority.title, color: priorityColor)
                        if let completedAt = task.completedAt {
                            Tag(text: completedAt.clockText, color: AppColors.good)
                        }
                    }
                }
                Spacer()
            }

            MemoEditor(title: $diaryTitle, text: $diaryBody, titlePlaceholder: "日记标题", bodyPlaceholder: "完成细节与感想")

            HStack(spacing: 10) {
                Button {
                    state.appendTaskJournal(task, title: diaryTitle, body: diaryBody)
                    clearDraft()
                } label: {
                    Label("记录日记", systemImage: "square.and.pencil")
                }
                .disabled(isDiaryDraftEmpty)

                Button {
                    state.completeTask(task, title: diaryTitle, body: diaryBody)
                    clearDraft()
                } label: {
                    Label("记录并完成", systemImage: "checkmark.circle")
                }
                .disabled(task.status == .done || isDiaryDraftEmpty)

                Spacer()
                if !task.completionNote.isEmpty {
                    Text(task.completionNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if !task.journal.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(task.journal.prefix(3)) { entry in
                        Text("\(entry.createdAt.clockText) \(entry.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(entry.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
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

    private func clearDraft() {
        diaryTitle = ""
        diaryBody = ""
    }

    private var isDiaryDraftEmpty: Bool {
        diaryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && diaryBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TodayGoalsCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("目标推进")
                    .font(.headline)
                let goals = state.activeGoals()
                if goals.isEmpty {
                    EmptyStateText("暂无长期目标")
                } else {
                    ForEach(goals) { goal in
                        TodayGoalRow(goal: goal)
                        if goal.id != goals.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct TodayGoalRow: View {
    @EnvironmentObject private var state: AppState
    let goal: StudyGoal
    @State private var logTitle = ""
    @State private var logBody = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(goal.title)
                        .font(.body.weight(.semibold))
                    Text(goal.metric)
                        .font(.callout)
                        .foregroundStyle(AppColors.accent)
                    if !goal.purpose.isEmpty {
                        Text(goal.purpose)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
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

            MemoEditor(title: $logTitle, text: $logBody, titlePlaceholder: "阶段日志标题", bodyPlaceholder: "阶段完成情况与感想")
            Button {
                state.appendGoalLog(goal, title: logTitle, body: logBody)
                logTitle = ""
                logBody = ""
            } label: {
                Label("记录阶段日志", systemImage: "text.badge.plus")
            }
            .disabled(isLogDraftEmpty)

            ForEach(goal.logs.sorted { $0.createdAt > $1.createdAt }.prefix(3)) { entry in
                Text("\(entry.createdAt.monthDayText) \(entry.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var isLogDraftEmpty: Bool {
        logTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && logBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct MemoEditor: View {
    @Binding var title: String
    @Binding var text: String
    let titlePlaceholder: String
    let bodyPlaceholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(titlePlaceholder, text: $title)
                .textFieldStyle(.roundedBorder)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                if text.isEmpty {
                    Text(bodyPlaceholder)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            }
        }
    }
}

struct PlanningView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(title: "规划", subtitle: "长期目标与短期计划", actions: {})

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        PlanFormCard()
                            .frame(maxWidth: .infinity)
                        GoalFormCard()
                            .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 18) {
                        PlanFormCard()
                        GoalFormCard()
                    }
                }

                PlanCalendarCard()
                GoalBoard()
            }
            .frame(maxWidth: 1240, alignment: .leading)
        }
    }
}

struct PlanFormCard: View {
    @EnvironmentObject private var state: AppState
    @State private var title = ""
    @State private var note = ""
    @State private var project = "学习"
    @State private var startDate = Date()
    @State private var targetDate = Date()
    @State private var minutes = 45.0
    @State private var priority: TaskPriority = .medium

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("新计划")
                    .font(.headline)
                TextField("计划名称", text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField("完成信号或备注", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                TextField("项目", text: $project)
                    .textFieldStyle(.roundedBorder)
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("完成日期", selection: $targetDate, displayedComponents: .date)
                    .onChange(of: startDate) { _, value in
                        if targetDate < value {
                            targetDate = value
                        }
                    }
                if targetDate < startDate {
                    Text("完成日期不能早于开始日期")
                        .font(.caption)
                        .foregroundStyle(AppColors.warning)
                }
                HStack {
                    Picker("优先级", selection: $priority) {
                        ForEach(TaskPriority.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    Stepper("\(Int(minutes)) 分", value: $minutes, in: 5...240, step: 5)
                }
                Button {
                    state.addTask(
                        title: title,
                        note: note,
                        project: project,
                        startDate: startDate,
                        targetDate: targetDate,
                        estimatedMinutes: Int(minutes),
                        priority: priority
                    )
                    title = ""
                    note = ""
                    project = "学习"
                    startDate = Date()
                    targetDate = Date()
                    minutes = 45
                } label: {
                    Label("添加计划", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetDate < startDate)
            }
            .frame(minHeight: 320, alignment: .top)
        }
    }
}

struct GoalFormCard: View {
    @EnvironmentObject private var state: AppState
    @State private var title = ""
    @State private var purpose = ""
    @State private var metric = ""
    @State private var days = 30.0

    var body: some View {
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
                    Slider(value: $days, in: 7...180, step: 1)
                }
                Button {
                    state.addGoal(title: title, purpose: purpose, metric: metric, days: Int(days))
                    title = ""
                    purpose = ""
                    metric = ""
                    days = 30
                } label: {
                    Label("添加目标", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(minHeight: 320, alignment: .top)
        }
    }
}

struct PlanningPulseCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("规划概览")
                    .font(.headline)
                InfoRow(label: "计划", value: "\(state.database.tasks.count)")
                InfoRow(label: "今日", value: "\(state.todaysTasks().count)")
                InfoRow(label: "目标", value: "\(state.database.goals.count)")
                InfoRow(label: "日志", value: "\(state.database.tasks.reduce(0) { $0 + $1.journal.count } + state.database.goals.reduce(0) { $0 + $1.logs.count })")
            }
        }
    }
}

struct PlanCalendarCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("计划日历")
                .font(.headline)
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    if groupedTasks.isEmpty {
                        EmptyStateText("暂无计划")
                    } else {
                        ForEach(sortedKeys, id: \.self) { key in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(key)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(AppColors.accent)
                                ForEach((groupedTasks[key] ?? []).sorted { left, right in
                                    if left.targetDate == right.targetDate {
                                        return left.startDate < right.startDate
                                    }
                                    return left.targetDate < right.targetDate
                                }) { task in
                                    PlanCalendarRow(task: task)
                                }
                            }
                            if key != sortedKeys.last {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedTasks: [String: [StudyTask]] {
        Dictionary(grouping: state.database.tasks) { $0.targetDate.dayKey }
    }

    private var sortedKeys: [String] {
        groupedTasks.keys.sorted()
    }
}

struct PlanCalendarRow: View {
    @EnvironmentObject private var state: AppState
    let task: StudyTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: task.status == .done ? "checkmark.seal.fill" : "circle.dotted")
                .foregroundStyle(task.status == .done ? AppColors.good : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                if !task.note.isEmpty {
                    Text(task.note)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Tag(text: task.project, color: AppColors.accent)
                    Tag(text: "开始 \(task.startDate.monthDayText)", color: AppColors.accent)
                    Tag(text: "完成 \(task.targetDate.monthDayText)", color: AppColors.accent)
                    Tag(text: "\(task.estimatedMinutes) 分", color: AppColors.steel)
                    Tag(text: task.status.title, color: task.status == .done ? AppColors.good : AppColors.steel)
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
    }
}

struct GoalBoard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let items = goalLogItems
        VStack(alignment: .leading, spacing: 14) {
            Text("目标日志")
                .font(.headline)
            if state.database.goals.isEmpty {
                SurfaceCard {
                    EmptyStateText("暂无目标")
                }
            } else {
                SurfaceCard {
                    NavigationStack {
                        if items.isEmpty {
                            EmptyStateText("暂无阶段日志")
                        } else if spansMultipleMonths(items) {
                            GoalLogMonthList(groups: monthGroups(from: items))
                        } else {
                            GoalLogTitleList(title: "阶段日志", items: items)
                        }
                    }
                    .frame(minHeight: 280)
                }
            }
        }
    }

    private var goalLogItems: [GoalLogItem] {
        state.database.goals.flatMap { goal in
            goal.logs.map { entry in
                GoalLogItem(
                    id: entry.id,
                    goalTitle: goal.title,
                    purpose: goal.purpose,
                    metric: goal.metric,
                    title: entry.title,
                    body: entry.body,
                    createdAt: entry.createdAt
                )
            }
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private func spansMultipleMonths(_ items: [GoalLogItem]) -> Bool {
        Set(items.map(\.monthKey)).count > 1
    }

    private func monthGroups(from items: [GoalLogItem]) -> [GoalLogMonthGroup] {
        Dictionary(grouping: items, by: \.monthKey)
            .map { key, grouped in
                GoalLogMonthGroup(
                    id: key,
                    title: grouped.first?.monthText ?? key,
                    items: grouped.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.id > $1.id }
    }
}

struct GoalLogItem: Identifiable, Hashable {
    let id: UUID
    let goalTitle: String
    let purpose: String
    let metric: String
    let title: String
    let body: String
    let createdAt: Date

    var monthKey: String { createdAt.monthKey }
    var monthText: String { createdAt.monthText }
}

struct GoalLogMonthGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let items: [GoalLogItem]
}

struct GoalLogMonthList: View {
    let groups: [GoalLogMonthGroup]

    var body: some View {
        List(groups) { group in
            NavigationLink {
                GoalLogTitleList(title: group.title, items: group.items)
            } label: {
                Text(group.title)
                    .font(.body.weight(.semibold))
            }
        }
        .listStyle(.plain)
        .navigationTitle("目标日志")
    }
}

struct GoalLogTitleList: View {
    let title: String
    let items: [GoalLogItem]

    var body: some View {
        List(items) { item in
            NavigationLink {
                GoalLogArticle(item: item)
            } label: {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
    }
}

struct GoalLogArticle: View {
    let item: GoalLogItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.title)
                    .font(.title2.weight(.semibold))
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.goalTitle)
                        .font(.headline)
                    Text(item.createdAt.dateTimeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !item.purpose.isEmpty {
                        Text(item.purpose)
                            .foregroundStyle(.secondary)
                    }
                    Label(item.metric, systemImage: "ruler")
                        .foregroundStyle(AppColors.accent)
                }
                Divider()
                MarkdownMessageView(text: item.body, compact: false)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("全文")
    }
}

struct GoalPlanningCard: View {
    @EnvironmentObject private var state: AppState
    let goal: StudyGoal

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(goal.title)
                            .font(.title3.weight(.semibold))
                        if !goal.purpose.isEmpty {
                            Text(goal.purpose)
                                .foregroundStyle(.secondary)
                        }
                        Label(goal.metric, systemImage: "ruler")
                            .foregroundStyle(AppColors.accent)
                    }
                    Spacer()
                    Button {
                        state.removeGoal(goal)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                HStack {
                    Text("截止 \(goal.targetDate.dayText)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !goal.logs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(goal.logs.sorted { $0.createdAt > $1.createdAt }.prefix(6)) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                Text(entry.createdAt.monthDayText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.accent)
                                    .frame(width: 48, alignment: .leading)
                                Text(entry.title)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MonitorView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(title: "监控", subtitle: "记录时长、应用分布与窗口轨迹", actions: {})

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 18) {
                        MonitorOverviewCard()
                        CurrentSampleCard()
                    }
                    .frame(width: 360)

                    VStack(spacing: 18) {
                        AppUsageCard()
                        TimelineCard(limit: 28)
                    }
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }
}

struct MonitorOverviewCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("今日记录")
                    .font(.headline)
                InfoRow(label: "时长", value: "\(ActivityAnalyzer.totalMinutes(from: state.todaysSamples(), sampleInterval: state.database.settings.sampleInterval)) 分钟")
                InfoRow(label: "样本", value: "\(state.todaysSamples().count)")
                InfoRow(label: "状态", value: state.monitor.isRunning ? "正在记录" : "暂停")
            }
        }
    }
}

struct CurrentSampleCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
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
                    EmptyStateText("暂无采样")
                }
                Button {
                    state.monitor.collectNow()
                } label: {
                    Label("立即采样", systemImage: "dot.scope")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct CoachView: View {
    @EnvironmentObject private var state: AppState
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderBar(title: "教练", subtitle: "对话、记忆与规划动作", actions: {})

            HStack(alignment: .top, spacing: 18) {
                CoachChatCard(input: $input)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 18) {
                    LatestSummaryCard()
                    CoachMemoryCard()
                }
                .frame(width: 340)
            }
        }
        .frame(maxWidth: 1240, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CoachChatCard: View {
    @EnvironmentObject private var state: AppState
    @Binding var input: String

    var body: some View {
        SurfaceCard {
            VStack(spacing: 14) {
                HStack {
                    Text(state.activeCoachConversation?.title ?? "当前对话")
                        .font(.headline)
                    Spacer()
                    Text(state.coachIdentityTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if state.activeCoachMessages.isEmpty {
                                EmptyStateText("暂无对话")
                            } else {
                                ForEach(state.activeCoachMessages) { message in
                                    CoachMessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            if state.isCoachThinking {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("教练正在思考")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: state.activeCoachMessages.count) { _, _ in
                        if let last = state.activeCoachMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                HStack(alignment: .bottom, spacing: 10) {
                    TextEditor(text: $input)
                        .font(.body)
                        .frame(minHeight: 72, maxHeight: 110)
                        .scrollContentBackground(.hidden)
                        .background(AppColors.selection, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.border, lineWidth: 1)
                        }
                    Button {
                        send()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .frame(width: 34, height: 34)
                    }
                    .help("发送")
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isCoachThinking)
                }
            }
        }
    }

    private func send() {
        let message = input
        input = ""
        Task {
            await state.sendCoachMessage(message)
        }
    }
}

struct CoachMessageBubble: View {
    let message: CoachMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 80)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(message.role.title)
                        .font(.caption.weight(.semibold))
                    if let toolName = message.toolName {
                        Text(toolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(message.createdAt.clockText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if message.isError {
                    Text(message.content)
                        .font(message.role == .tool ? .caption : .body)
                        .foregroundStyle(AppColors.warning)
                        .textSelection(.enabled)
                } else {
                    MarkdownMessageView(text: message.content, compact: message.role == .tool)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border.opacity(message.role == .tool ? 0.65 : 1), lineWidth: 1)
            }
            if message.role != .user {
                Spacer(minLength: 80)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return AppColors.accent.opacity(0.12)
        case .assistant: return AppColors.surface
        case .tool: return AppColors.selection
        case .system: return AppColors.steel.opacity(0.12)
        }
    }
}

struct MarkdownMessageView: View {
    let text: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 9) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(text)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let value):
            Text(value)
                .font(headingFont(level))
                .padding(.top, level == 1 ? 4 : 2)
        case .paragraph(let value):
            MarkdownInlineText(value)
                .font(compact ? .caption : .body)
        case .bullet(let value):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(compact ? .caption : .body)
                MarkdownInlineText(value)
                    .font(compact ? .caption : .body)
            }
        case .code(let value):
            Text(value)
                .font(.system(compact ? .caption : .callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.selection, in: RoundedRectangle(cornerRadius: 8))
        case .formula(let value):
            Text(LaTeXFormatter.render(value))
                .font(.system(size: compact ? 13 : 16, weight: .medium, design: .serif))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(AppColors.selection, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return compact ? .headline : .title3.weight(.semibold)
        case 2: return .headline
        default: return .subheadline.weight(.semibold)
        }
    }
}

struct MarkdownInlineText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: InlineMarkdownFormatter.render(text),
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(InlineMarkdownFormatter.render(text))
        }
    }
}

enum MarkdownBlock: Hashable {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case code(String)
    case formula(String)

    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var formula: [String] = []
        var inCode = false
        var inFormula = false

        func flushParagraph() {
            let joined = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(.paragraph(joined))
            }
            paragraph.removeAll()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(code.joined(separator: "\n")))
                    code.removeAll()
                    inCode = false
                } else {
                    flushParagraph()
                    inCode = true
                }
                continue
            }

            if inCode {
                code.append(rawLine)
                continue
            }

            if line.hasPrefix("$$") {
                if inFormula {
                    blocks.append(.formula(formula.joined(separator: "\n")))
                    formula.removeAll()
                    inFormula = false
                } else if line.hasSuffix("$$"), line.count > 4 {
                    flushParagraph()
                    let value = String(line.dropFirst(2).dropLast(2))
                    blocks.append(.formula(value))
                } else {
                    flushParagraph()
                    inFormula = true
                    let remainder = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !remainder.isEmpty {
                        formula.append(remainder)
                    }
                }
                continue
            }

            if inFormula {
                formula.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
            } else if let heading = parseHeading(line) {
                flushParagraph()
                blocks.append(.heading(heading.level, heading.text))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else {
                paragraph.append(rawLine)
            }
        }

        flushParagraph()
        if !code.isEmpty { blocks.append(.code(code.joined(separator: "\n"))) }
        if !formula.isEmpty { blocks.append(.formula(formula.joined(separator: "\n"))) }
        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let index = line.index(line.startIndex, offsetBy: hashes)
        guard index < line.endIndex, line[index] == " " else { return nil }
        return (hashes, String(line[line.index(after: index)...]))
    }
}

enum InlineMarkdownFormatter {
    static func render(_ text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "$" {
                let next = text.index(after: index)
                if next < text.endIndex,
                   let close = text[next...].firstIndex(of: "$") {
                    let formula = String(text[next..<close])
                    result += LaTeXFormatter.render(formula)
                    index = text.index(after: close)
                    continue
                }
            }
            result.append(text[index])
            index = text.index(after: index)
        }
        return result
    }
}

enum LaTeXFormatter {
    static func render(_ input: String) -> String {
        var output = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$$", with: "")
            .replacingOccurrences(of: "$", with: "")

        output = replaceCommandWithTwoArguments("\\frac", in: output) { numerator, denominator in
            "\(render(numerator))⁄\(render(denominator))"
        }
        output = replaceCommandWithOneArgument("\\sqrt", in: output) { value in
            "√(\(render(value)))"
        }

        for (source, target) in replacements {
            output = output.replacingOccurrences(of: source, with: target)
        }

        output = replaceScripts(in: output)
        output = output
            .replacingOccurrences(of: "\\left", with: "")
            .replacingOccurrences(of: "\\right", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
        return output
    }

    private static let replacements: [String: String] = [
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ",
        "\\epsilon": "ε", "\\theta": "θ", "\\lambda": "λ", "\\mu": "μ",
        "\\pi": "π", "\\rho": "ρ", "\\sigma": "σ", "\\phi": "φ",
        "\\omega": "ω", "\\Delta": "Δ", "\\Sigma": "Σ", "\\Omega": "Ω",
        "\\times": "×", "\\cdot": "·", "\\leq": "≤", "\\geq": "≥",
        "\\neq": "≠", "\\approx": "≈", "\\infty": "∞", "\\sum": "∑",
        "\\int": "∫", "\\rightarrow": "→", "\\leftarrow": "←", "\\to": "→",
        "\\in": "∈", "\\notin": "∉", "\\forall": "∀", "\\exists": "∃",
        "\\pm": "±"
    ]

    private static func replaceCommandWithOneArgument(
        _ command: String,
        in text: String,
        transform: (String) -> String
    ) -> String {
        var text = text
        while let commandRange = text.range(of: "\(command){") {
            let openBrace = text.index(before: commandRange.upperBound)
            guard let argument = readBraced(in: text, openBrace: openBrace) else { break }
            text.replaceSubrange(commandRange.lowerBound..<argument.endIndex, with: transform(argument.value))
        }
        return text
    }

    private static func replaceCommandWithTwoArguments(
        _ command: String,
        in text: String,
        transform: (String, String) -> String
    ) -> String {
        var text = text
        while let commandRange = text.range(of: "\(command){") {
            let firstOpen = text.index(before: commandRange.upperBound)
            guard let first = readBraced(in: text, openBrace: firstOpen),
                  first.endIndex < text.endIndex,
                  text[first.endIndex] == "{",
                  let second = readBraced(in: text, openBrace: first.endIndex) else { break }
            text.replaceSubrange(commandRange.lowerBound..<second.endIndex, with: transform(first.value, second.value))
        }
        return text
    }

    private static func readBraced(in text: String, openBrace: String.Index) -> (value: String, endIndex: String.Index)? {
        guard openBrace < text.endIndex, text[openBrace] == "{" else { return nil }
        var depth = 0
        var index = openBrace
        var valueStart = text.index(after: openBrace)
        while index < text.endIndex {
            if text[index] == "{" {
                if depth == 0 {
                    valueStart = text.index(after: index)
                }
                depth += 1
            } else if text[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return (String(text[valueStart..<index]), text.index(after: index))
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func replaceScripts(in text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "^" || character == "_" {
                let isSuperscript = character == "^"
                let next = text.index(after: index)
                guard next < text.endIndex else {
                    result.append(character)
                    break
                }
                if text[next] == "{", let argument = readBraced(in: text, openBrace: next) {
                    result += mapScript(argument.value, superscript: isSuperscript)
                    index = argument.endIndex
                } else {
                    result += mapScript(String(text[next]), superscript: isSuperscript)
                    index = text.index(after: next)
                }
            } else {
                result.append(character)
                index = text.index(after: index)
            }
        }
        return result
    }

    private static func mapScript(_ value: String, superscript: Bool) -> String {
        let table = superscript ? superscripts : subscripts
        return String(value.map { table[$0] ?? $0 })
    }

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵",
        "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "+": "⁺", "-": "⁻",
        "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "i": "ⁱ"
    ]

    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅",
        "6": "₆", "7": "₇", "8": "₈", "9": "₉", "+": "₊", "-": "₋",
        "=": "₌", "(": "₍", ")": "₎", "a": "ₐ", "e": "ₑ", "h": "ₕ",
        "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ",
        "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
        "v": "ᵥ", "x": "ₓ"
    ]
}

struct LatestSummaryCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("今日复盘")
                    .font(.headline)
                if let summary = state.latestSummary() {
                    HStack {
                        Text("\(summary.score)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(scoreColor(summary.score))
                        Text(summary.model)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text(summary.body)
                        .font(.caption)
                        .lineLimit(8)
                        .foregroundStyle(.secondary)
                } else {
                    EmptyStateText("暂无复盘")
                }
            }
        }
    }
}

struct CoachMemoryCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("记忆")
                    .font(.headline)
                Text(state.database.coachMemory.summary.isEmpty ? "暂无长期记忆" : state.database.coachMemory.summary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !state.database.coachMemory.keyFacts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.database.coachMemory.keyFacts.prefix(6), id: \.self) { fact in
                            Label(fact, systemImage: "pin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var identityDraft = ""
    @State private var showIdentityChangeAlert = false

    var body: some View {
        let _ = AppColors.configure(state.database.settings)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBar(title: "设置", subtitle: "身份、接口、外观与采样", actions: {})

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("身份信息")
                            .font(.headline)
                        TextField("例如：大一计算机科学学生、高中数学偏科生", text: $identityDraft)
                            .textFieldStyle(.roundedBorder)

                        Text("教练会把身份信息作为长期背景。修改已有身份会先归档当前身份下的记忆和全部对话，再开启新的身份记忆。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                saveIdentityTapped()
                            } label: {
                                Label(currentIdentityText.isEmpty ? "保存身份" : "修改身份", systemImage: "person.text.rectangle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(identityDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || identityDraft.trimmingCharacters(in: .whitespacesAndNewlines) == currentIdentityText)

                            Text("当前：\(state.coachIdentityTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ArchivedConversationsCard()

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

                        if state.database.settings.visualTheme == .custom {
                            CustomColorPalette()
                        }

                        HStack(spacing: 12) {
                            ForEach(AppVisualTheme.allCases) { theme in
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
        }
        .environment(\.traceTheme, TraceThemePalette(settings: state.database.settings))
        .onAppear {
            identityDraft = state.database.coachIdentity.title
        }
        .alert("修改身份信息？", isPresented: $showIdentityChangeAlert) {
            Button("取消", role: .cancel) {}
            Button("确认归档并修改", role: .destructive) {
                state.updateCoachIdentity(identityDraft)
            }
        } message: {
            Text("这会归档当前身份下的教练记忆和所有对话，然后为新身份开启新的记忆与对话。")
        }
    }

    private var currentIdentityText: String {
        state.database.coachIdentity.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveIdentityTapped() {
        let clean = identityDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if currentIdentityText.isEmpty {
            state.updateCoachIdentity(clean)
        } else if clean != currentIdentityText {
            showIdentityChangeAlert = true
        }
    }
}

struct ArchivedConversationsCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("已归档对话")
                    .font(.headline)
                if state.database.archivedCoachConversations.isEmpty {
                    EmptyStateText("暂无归档")
                } else {
                    ForEach(groupedArchives, id: \.identity) { group in
                        DisclosureGroup(group.identity) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(group.archives) { archive in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(archive.title)
                                            .font(.callout.weight(.semibold))
                                        Text("\(archive.archivedAt.dateTimeText) · \(archive.messages.count) 条消息")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let filePath = archive.filePath {
                                            Text(filePath)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .textSelection(.enabled)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
        }
    }

    private var groupedArchives: [(identity: String, archives: [CoachConversationArchive])] {
        Dictionary(grouping: state.database.archivedCoachConversations, by: \.identityTitle)
            .map { identity, archives in
                (identity, archives.sorted { $0.archivedAt > $1.archivedAt })
            }
            .sorted { $0.identity < $1.identity }
    }
}

struct CustomColorPalette: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("自定义全局主题色")
                    .font(.callout.weight(.semibold))
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .fill(state.database.settings.customSidebarColor.color)
                    .frame(width: 44, height: 26)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                    }
            }
            Color18Channel(label: "R", value: state.database.settings.customSidebarColor.red) { value in
                update(red: value)
            }
            Color18Channel(label: "G", value: state.database.settings.customSidebarColor.green) { value in
                update(green: value)
            }
            Color18Channel(label: "B", value: state.database.settings.customSidebarColor.blue) { value in
                update(blue: value)
            }
        }
        .padding(12)
        .background(AppColors.selection, in: RoundedRectangle(cornerRadius: 8))
    }

    private func update(red: Int? = nil, green: Int? = nil, blue: Int? = nil) {
        state.updateSettings { settings in
            let current = settings.customSidebarColor
            settings.customSidebarColor = Color18(
                red: red ?? current.red,
                green: green ?? current.green,
                blue: blue ?? current.blue
            )
        }
    }
}

struct Color18Channel: View {
    let label: String
    let value: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(width: 18, alignment: .leading)
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(Int($0.rounded())) }
                ),
                in: 0...63,
                step: 1
            )
            Text("\(value)")
                .font(.caption.monospacedDigit())
                .frame(width: 24, alignment: .trailing)
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
                    EmptyStateText("开始记录后显示")
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
                    EmptyStateText("暂无轨迹")
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

struct ThemePreview: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.traceTheme) private var themePalette
    let theme: AppVisualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(theme.title, systemImage: theme.systemImage)
                    .font(.callout.weight(.semibold))
                Spacer()
                if theme == .day {
                    swatch(AppColors.boulevardLeaf)
                    swatch(AppColors.boulevardSky)
                    swatch(AppColors.boulevardSun)
                } else if theme == .night {
                    swatch(AppColors.starMint)
                    swatch(AppColors.starGold)
                    swatch(AppColors.starViolet)
                } else {
                    swatch(state.database.settings.customSidebarColor.color)
                }
            }
            Text(theme.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themePalette.selection, in: RoundedRectangle(cornerRadius: 8))
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

struct SurfaceCard<Content: View>: View {
    @Environment(\.traceTheme) private var theme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border, lineWidth: 1)
            }
    }
}

struct TraceThemePalette {
    let visualTheme: AppVisualTheme
    let customColor: Color18

    init(settings: AppSettings) {
        visualTheme = settings.visualTheme
        customColor = settings.customSidebarColor
    }

    var surface: Color {
        if visualTheme == .custom {
            return customAdaptive(lightOpacity: 0.13, darkOpacity: 0.30)
        }
        return adaptive(light: NSColor(red: 1.00, green: 0.99, blue: 0.96, alpha: 1), dark: NSColor(red: 0.10, green: 0.11, blue: 0.17, alpha: 1))
    }

    var border: Color {
        if visualTheme == .custom {
            return customColor.color.opacity(0.34)
        }
        return adaptive(light: NSColor(red: 0.79, green: 0.82, blue: 0.74, alpha: 1), dark: NSColor(red: 0.24, green: 0.26, blue: 0.36, alpha: 1)).opacity(0.72)
    }

    var selection: Color {
        if visualTheme == .custom {
            return customColor.color.opacity(0.18)
        }
        return adaptive(light: NSColor(red: 0.92, green: 0.96, blue: 0.88, alpha: 1), dark: NSColor(red: 0.15, green: 0.18, blue: 0.26, alpha: 1))
    }

    private func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }

    private func customAdaptive(lightOpacity: Double, darkOpacity: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            let alpha = match == .darkAqua ? darkOpacity : lightOpacity
            let color = NSColor(
                red: customColor.redUnit,
                green: customColor.greenUnit,
                blue: customColor.blueUnit,
                alpha: alpha
            )
            if match == .darkAqua {
                return NSColor(red: 0.05, green: 0.055, blue: 0.065, alpha: 1).blended(withFraction: alpha, of: color) ?? color
            }
            return NSColor.white.blended(withFraction: alpha, of: color) ?? color
        })
    }
}

private struct TraceThemePaletteKey: EnvironmentKey {
    static let defaultValue = TraceThemePalette(settings: AppSettings())
}

extension EnvironmentValues {
    var traceTheme: TraceThemePalette {
        get { self[TraceThemePaletteKey.self] }
        set { self[TraceThemePaletteKey.self] = newValue }
    }
}

struct EmptyStateText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
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
    private static var settings = AppSettings()

    static func configure(_ settings: AppSettings) {
        self.settings = settings
    }

    static var canvas: Color {
        if settings.visualTheme == .custom {
            return customAdaptive(lightOpacity: 0.06, darkOpacity: 0.22)
        }
        return adaptive(light: NSColor(red: 0.98, green: 0.98, blue: 0.95, alpha: 1), dark: NSColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1))
    }

    static var surface: Color {
        if settings.visualTheme == .custom {
            return customAdaptive(lightOpacity: 0.13, darkOpacity: 0.30)
        }
        return adaptive(light: NSColor(red: 1.00, green: 0.99, blue: 0.96, alpha: 1), dark: NSColor(red: 0.10, green: 0.11, blue: 0.17, alpha: 1))
    }

    static var border: Color {
        if settings.visualTheme == .custom {
            return settings.customSidebarColor.color.opacity(0.34)
        }
        return adaptive(light: NSColor(red: 0.79, green: 0.82, blue: 0.74, alpha: 1), dark: NSColor(red: 0.24, green: 0.26, blue: 0.36, alpha: 1)).opacity(0.72)
    }

    static var sidebar: Color { canvas }

    static var selection: Color {
        if settings.visualTheme == .custom {
            return settings.customSidebarColor.color.opacity(0.18)
        }
        return adaptive(light: NSColor(red: 0.92, green: 0.96, blue: 0.88, alpha: 1), dark: NSColor(red: 0.15, green: 0.18, blue: 0.26, alpha: 1))
    }

    static var accent: Color {
        if settings.visualTheme == .custom {
            return settings.customSidebarColor.color
        }
        return adaptive(light: NSColor(red: 0.08, green: 0.43, blue: 0.32, alpha: 1), dark: NSColor(red: 0.46, green: 0.82, blue: 0.70, alpha: 1))
    }

    static var good: Color {
        adaptive(light: NSColor(red: 0.12, green: 0.55, blue: 0.31, alpha: 1), dark: NSColor(red: 0.48, green: 0.86, blue: 0.55, alpha: 1))
    }

    static var warning: Color {
        adaptive(light: NSColor(red: 0.76, green: 0.31, blue: 0.19, alpha: 1), dark: NSColor(red: 1.00, green: 0.63, blue: 0.38, alpha: 1))
    }

    static var steel: Color {
        if settings.visualTheme == .custom {
            return settings.customSidebarColor.color.opacity(0.78)
        }
        return adaptive(light: NSColor(red: 0.30, green: 0.40, blue: 0.48, alpha: 1), dark: NSColor(red: 0.62, green: 0.70, blue: 0.80, alpha: 1))
    }

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

    private static func customAdaptive(lightOpacity: Double, darkOpacity: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            let alpha = match == .darkAqua ? darkOpacity : lightOpacity
            let color = NSColor(
                red: settings.customSidebarColor.redUnit,
                green: settings.customSidebarColor.greenUnit,
                blue: settings.customSidebarColor.blueUnit,
                alpha: alpha
            )
            if match == .darkAqua {
                return NSColor(red: 0.05, green: 0.055, blue: 0.065, alpha: 1).blended(withFraction: alpha, of: color) ?? color
            }
            return NSColor.white.blended(withFraction: alpha, of: color) ?? color
        })
    }
}

extension Color18 {
    var color: Color {
        Color(red: redUnit, green: greenUnit, blue: blueUnit)
    }
}

extension AppVisualTheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .day: return .light
        case .night: return .dark
        case .custom: return nil
        }
    }
}

private func scoreColor(_ score: Int) -> Color {
    if score >= 8 { return AppColors.good }
    if score >= 5 { return AppColors.boulevardSun }
    return AppColors.warning
}
