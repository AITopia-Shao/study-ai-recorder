let db;
let timer;
let coachThinking = false;
let coachExpanded = true;
let renamingConversationId = "";
let renameDraft = "";
const goalMonthSelection = new Map();

const byId = (id) => document.getElementById(id);
const nowISO = () => new Date().toISOString();
const uuid = () => crypto.randomUUID();

const LANGUAGES = [
  ["en", "English"],
  ["zh-Hans", "简体中文"],
  ["zh-Hant", "繁體中文"],
  ["ja", "日本語"],
  ["ko", "한국어"],
  ["fr", "Français"],
  ["es", "Español"]
];

const I18N = {
  en: {
    "记录与教练": "Records & Coach",
    "主导航": "Main Navigation",
    "工作台": "Workspace",
    "今日": "Today",
    "规划": "Planning",
    "监控": "Monitor",
    "教练": "Coach",
    "设置": "Settings",
    "新对话": "New Chat",
    "收起对话": "Collapse Chats",
    "展开对话": "Expand Chats",
    "记录暂停": "Recording Paused",
    "正在记录": "Recording",
    "等待采样": "Waiting for Sample",
    "今日计划": "Today Plans",
    "暂无今日计划": "No plans for today",
    "目标推进": "Goal Progress",
    "暂无长期目标": "No long-term goals",
    "长期目标与短期计划": "Long-term goals and short-term plans",
    "新计划": "New Plan",
    "计划名称": "Plan Name",
    "完成信号或备注": "Completion signal or note",
    "项目": "Project",
    "开始日期": "Start Date",
    "完成日期": "Completion Date",
    "完成记录": "Completion Note",
    "预计分钟": "Estimated Minutes",
    "优先级": "Priority",
    "低": "Low",
    "中": "Medium",
    "高": "High",
    "添加计划": "Add Plan",
    "新目标": "New Goal",
    "目标名称": "Goal Name",
    "为什么做": "Why It Matters",
    "衡量方式": "Measure",
    "周期天数": "Duration in Days",
    "添加目标": "Add Goal",
    "计划日历": "Plan Calendar",
    "暂无计划": "No plans",
    "目标日志": "Goal Logs",
    "暂无目标": "No goals",
    "暂无阶段日志": "No stage logs",
    "记录时长、应用分布与窗口轨迹": "Recording time, app usage, and window timeline",
    "立即采样": "Sample Now",
    "今日记录": "Today Record",
    "当前采样": "Current Sample",
    "暂无采样": "No samples",
    "应用时间": "App Time",
    "窗口轨迹": "Window Timeline",
    "暂无轨迹": "No timeline",
    "对话、记忆与规划动作": "Chat, memory, and planning actions",
    "和教练对话": "Chat with Coach",
    "发送": "Send",
    "今日复盘": "Today Review",
    "暂无复盘": "No review yet",
    "记忆": "Memory",
    "暂无长期记忆": "No long-term memory",
    "身份、接口、外观与采样": "Identity, API, appearance, and sampling",
    "身份信息": "Identity",
    "例如：大一计算机科学学生、高中数学偏科生": "For example: first-year computer science student, high-school student weak in math",
    "教练会把身份信息作为长期背景。修改已有身份会归档当前身份下的记忆与全部对话，再开启新的身份记忆。": "The coach uses identity as long-term context. Changing an existing identity archives memory and all chats under the current identity, then starts a new identity memory.",
    "保存身份": "Save Identity",
    "当前：": "Current: ",
    "未设置身份": "No Identity Set",
    "已归档对话": "Archived Chats",
    "暂无归档": "No archives",
    "外观": "Appearance",
    "日间": "Day",
    "暗夜": "Night",
    "自定义": "Custom",
    "语言": "Language",
    "AI 接口": "AI API",
    "模型": "Model",
    "使用 Electron safeStorage 加密保存": "Encrypted with Electron safeStorage",
    "保存接口设置": "Save API Settings",
    "采样": "Sampling",
    "采样间隔": "Sample Interval",
    "秒": "sec",
    "记录窗口标题": "Record window titles",
    "保存屏幕快照并尝试本地 OCR": "Save screenshots and try local OCR",
    "快照间隔（分钟）": "Screenshot interval (minutes)",
    "日记标题": "Diary Title",
    "完成细节与感想": "Completion details and reflections",
    "保存日记": "Save Diary",
    "完成并保存": "Complete and Save",
    "撤销完成": "Undo Completion",
    "阶段日志标题": "Stage Log Title",
    "阶段完成情况、细节与感想": "Stage progress, details, and reflections",
    "保存阶段日志": "Save Stage Log",
    "开始": "Start",
    "开始记录后显示": "Shown after recording starts",
    "完成": "Due",
    "删除": "Delete",
    "时长": "Duration",
    "样本": "Samples",
    "状态": "Status",
    "暂停": "Paused",
    "条消息": "messages",
    "对话": "Conversation",
    "默认对话": "Default Chat",
    "新身份对话": "New Identity Chat"
    ,"学习": "Study",
    "今日对话": "Today Chat",
    "分": "min",
    "分钟": "min",
    "计划": "Plan",
    "目标": "Goal",
    "待开始": "Planned",
    "进行中": "In Progress",
    "已完成": "Done",
    "逾期": "Overdue",
    "截止": "Due",
    "衡量": "Measure",
    "未填写": "Not filled",
    "未命名": "Untitled",
    "未命名记录": "Untitled Note",
    "暂无正文": "No body",
    "对话标题": "Chat Title",
    "确认": "Confirm",
    "取消": "Cancel",
    "重命名": "Rename",
    "我": "Me",
    "工具": "Tool",
    "系统": "System",
    "归档对话": "Archived Chat",
    "完成可验证产出": "Complete a verifiable output",
    "明确下一步动作": "Clarify the next action",
    "完成一次阶段复盘": "Complete one stage review",
    "产出可展示成果": "Produce a demonstrable result",
    "删除后不会影响教练记忆和身份信息。确定删除这个对话？": "Deleting this chat will not delete coach memory or identity information. Delete this chat?",
    "每日自动归档": "Daily auto archive",
    "完成日期不能早于开始日期。": "Completion date cannot be earlier than start date.",
    "修改身份信息会归档当前身份下的教练记忆和全部对话，并开启新的身份记忆。是否继续？": "Changing identity will archive coach memory and all chats under the current identity, then start a new identity memory. Continue?",
    "身份信息从": "Identity changed from",
    "修改为": "to",
    "已切换到身份": "Switched to identity",
    "我会基于这个身份重新建立对话记忆。": "I will rebuild chat memory around this identity.",
    "我会记住你的计划、目标、日志和活动记录，并在你需要时帮你调整规划。": "I will remember your plans, goals, logs, and activity records, and help you adjust planning when needed.",
    "设置已保存": "Settings saved",
    "我已读取当前规划上下文。": "I have read the current planning context.",
    "新增计划失败：缺少标题。": "Failed to add plan: missing title.",
    "更新计划失败：未找到目标计划。": "Failed to update plan: target plan not found.",
    "删除计划失败：未找到目标计划。": "Failed to delete plan: target plan not found.",
    "完成计划失败：未找到目标计划。": "Failed to complete plan: target plan not found.",
    "添加计划日记失败。": "Failed to add plan diary.",
    "新增目标失败：缺少标题。": "Failed to add goal: missing title.",
    "更新目标失败：未找到目标。": "Failed to update goal: target goal not found.",
    "删除目标失败：未找到目标。": "Failed to delete goal: target goal not found.",
    "添加目标日志失败。": "Failed to add goal log.",
    "已新增计划": "Added plan",
    "已更新计划": "Updated plan",
    "已删除计划": "Deleted plan",
    "已标记完成": "Marked complete",
    "已添加计划日记": "Added plan diary",
    "已新增目标": "Added goal",
    "已更新目标": "Updated goal",
    "已删除目标": "Deleted goal",
    "已添加目标日志": "Added goal log",
    "已读取上下文": "Read context",
    "教练文件": "Coach files",
    "教练文件区暂无文件。": "Coach files area is empty.",
    "读取文件失败": "Failed to read file",
    "已读取": "Read",
    "已写入教练文件": "Wrote coach file",
    "写入文件失败": "Failed to write file",
    "今天已有可复盘的规划记录。": "Today has planning records ready for review.",
    "总评": "Overview",
    "评分依据": "Score Basis",
    "今日任务完成": "Today's tasks completed",
    "记录时长约": "Recorded about",
    "亮点": "Highlights",
    "阻碍": "Obstacles",
    "改进建议": "Recommendations",
    "明日计划": "Tomorrow Plan",
    "数据边界": "Data Boundaries"
  },
  "zh-Hans": {},
  "zh-Hant": { "记录与教练": "記錄與教練", "规划": "規劃", "监控": "監控", "教练": "教練", "设置": "設定", "计划": "計劃", "目标": "目標", "语言": "語言" },
  ja: { "今日": "今日", "规划": "プラン", "监控": "モニター", "教练": "コーチ", "设置": "設定", "语言": "言語" },
  ko: { "今日": "오늘", "规划": "플래닝", "监控": "모니터", "教练": "코치", "设置": "설정", "语言": "언어" },
  fr: { "今日": "Aujourd'hui", "规划": "Planification", "监控": "Suivi", "教练": "Coach", "设置": "Réglages", "语言": "Langue" },
  es: { "今日": "Hoy", "规划": "Planificación", "监控": "Monitor", "教练": "Coach", "设置": "Ajustes", "语言": "Idioma" }
};

function currentLanguage() {
  return db?.settings?.language || "en";
}

function t(key) {
  const language = currentLanguage();
  if (language === "zh-Hans") return key;
  return I18N[language]?.[key] || I18N.en[key] || key;
}

function normalizeLanguage(value) {
  return LANGUAGES.some(([code]) => code === value) ? value : "en";
}

document.addEventListener("DOMContentLoaded", load);

async function load() {
  db = normalizeDatabase(await window.studyAI.loadDatabase());
  await archiveStaleCoachConversationIfNeeded();
  setDefaultFormDates();
  bindEvents();
  render();
}

function bindEvents() {
  document.querySelectorAll("[data-view]").forEach((button) => {
    button.addEventListener("click", () => selectView(button.dataset.view));
  });
  byId("openSettings").addEventListener("click", () => selectView("settings"));
  byId("newConversation").addEventListener("click", async () => {
    startNewConversation();
    await save();
    selectView("coach");
  });
  byId("toggleCoachList").addEventListener("click", () => {
    coachExpanded = !coachExpanded;
    renderSidebar();
  });

  byId("addTask").addEventListener("click", addTaskFromForm);
  byId("addGoal").addEventListener("click", addGoalFromForm);
  byId("sampleNow").addEventListener("click", sampleNow);
  byId("toggleRecord").addEventListener("change", (event) => setRecording(event.target.checked));
  byId("sendCoach").addEventListener("click", sendCoachMessage);
  byId("coachInput").addEventListener("keydown", (event) => {
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter") sendCoachMessage();
  });

  byId("saveIdentity").addEventListener("click", saveIdentity);
  byId("saveSettings").addEventListener("click", saveSettings);
  byId("languageSelect").addEventListener("change", async (event) => {
    db.settings.language = normalizeLanguage(event.target.value);
    document.documentElement.lang = db.settings.language;
    render();
    await save({ rerender: false });
  });
  byId("closeLogModal").addEventListener("click", closeLogModal);
  byId("logModal").addEventListener("click", (event) => {
    if (event.target.id === "logModal") closeLogModal();
  });

  document.querySelectorAll(".theme-tab").forEach((button) => {
    button.addEventListener("click", async () => {
      db.settings.visualTheme = button.dataset.theme;
      applyTheme();
      renderSettings();
      await save({ rerender: false });
    });
  });

  [
    ["colorRed", "red"],
    ["colorGreen", "green"],
    ["colorBlue", "blue"]
  ].forEach(([id, key]) => {
    byId(id).addEventListener("input", async (event) => {
      db.settings.visualTheme = "custom";
      db.settings.customSidebarColor[key] = Number(event.target.value);
      applyTheme();
      renderSettings();
      await save({ rerender: false });
    });
  });

  ["sampleInterval", "includeWindowTitles", "captureScreenshots", "screenshotInterval"].forEach((id) => {
    byId(id).addEventListener("change", async () => {
      db.settings.sampleInterval = Number(byId("sampleInterval").value || 30);
      db.settings.includeWindowTitles = byId("includeWindowTitles").checked;
      db.settings.captureScreenshots = byId("captureScreenshots").checked;
      db.settings.screenshotIntervalMinutes = Number(byId("screenshotInterval").value || 15);
      await save();
    });
  });
}

function normalizeDatabase(value) {
  const next = value || {};
  next.tasks = (next.tasks || []).map(normalizeTask);
  next.goals = (next.goals || []).map(normalizeGoal);
  next.samples ||= [];
  next.summaries ||= [];
  next.coachMessages ||= [];
  next.coachMemory = {
    summary: next.coachMemory?.summary || "",
    keyFacts: Array.isArray(next.coachMemory?.keyFacts) ? next.coachMemory.keyFacts : [],
    updatedAt: next.coachMemory?.updatedAt || ""
  };
  next.coachIdentity = normalizeIdentity(next.coachIdentity);
  next.coachConversations = (next.coachConversations || []).map((conversation) => normalizeConversation(conversation, next.coachIdentity.id));
  next.archivedCoachConversations = (next.archivedCoachConversations || []).map(normalizeArchive);
  next.settings = normalizeSettings(next.settings || {});

  if (!next.coachConversations.length) {
    const messages = next.coachMessages.length ? next.coachMessages.map(normalizeMessage) : [assistantGreeting()];
    next.coachConversations = [normalizeConversation({
      id: uuid(),
      identityId: next.coachIdentity.id,
      title: messages.length ? t("默认对话") : t("新对话"),
      createdAt: messages[0]?.createdAt || nowISO(),
      updatedAt: messages.at(-1)?.createdAt || nowISO(),
      messages
    }, next.coachIdentity.id)];
  }
  if (!next.activeCoachConversationId || !next.coachConversations.some((item) => item.id === next.activeCoachConversationId)) {
    next.activeCoachConversationId = next.coachConversations[0]?.id || "";
  }
  syncLegacyMessages(next);
  return next;
}

function normalizeSettings(settings) {
  let visualTheme = settings.visualTheme || "day";
  if (visualTheme === "boulevard" || visualTheme === "system") visualTheme = "day";
  if (visualTheme === "starlight") visualTheme = "night";
  const color = settings.customSidebarColor || {};
  return {
    baseURL: settings.baseURL || "https://api.openai.com/v1",
    model: settings.model || "gpt-4o-mini",
    language: normalizeLanguage(settings.language),
    visualTheme,
    sampleInterval: Number(settings.sampleInterval || 30),
    includeWindowTitles: settings.includeWindowTitles !== false,
    captureScreenshots: Boolean(settings.captureScreenshots),
    screenshotIntervalMinutes: Number(settings.screenshotIntervalMinutes || 15),
    maxSamplesPerDay: Number(settings.maxSamplesPerDay || 2400),
    enabledAgentSkillIDs: settings.enabledAgentSkillIDs || [],
    deterministicScoring: settings.deterministicScoring !== false,
    compactSummaryStyle: settings.compactSummaryStyle !== false,
    customSidebarColor: {
      red: clamp18(color.red ?? 8),
      green: clamp18(color.green ?? 27),
      blue: clamp18(color.blue ?? 20)
    }
  };
}

function normalizeIdentity(identity = {}) {
  const now = nowISO();
  return {
    id: identity.id || uuid(),
    title: identity.title || "",
    createdAt: identity.createdAt || now,
    updatedAt: identity.updatedAt || identity.createdAt || now
  };
}

function normalizeConversation(conversation = {}, identityId) {
  const messages = (conversation.messages || []).map(normalizeMessage);
  const createdAt = conversation.createdAt || messages[0]?.createdAt || nowISO();
  return {
    id: conversation.id || uuid(),
    identityId: conversation.identityId || identityId,
    title: cleanTitle(conversation.title || (messages.length ? t("对话") : t("新对话"))),
    createdAt,
    updatedAt: conversation.updatedAt || messages.at(-1)?.createdAt || createdAt,
    messages
  };
}

function normalizeArchive(archive = {}) {
  return {
    id: archive.id || uuid(),
    identityId: archive.identityId || "",
    identityTitle: archive.identityTitle || t("未设置身份"),
    title: archive.title || t("归档对话"),
    createdAt: archive.createdAt || nowISO(),
    archivedAt: archive.archivedAt || nowISO(),
    messages: (archive.messages || []).map(normalizeMessage),
    memorySummary: archive.memorySummary || "",
    keyFacts: Array.isArray(archive.keyFacts) ? archive.keyFacts : [],
    filePath: archive.filePath || ""
  };
}

function normalizeTask(task = {}) {
  const targetDate = task.targetDate || task.date || nowISO();
  const createdAt = task.createdAt || targetDate;
  return {
    id: task.id || uuid(),
    title: task.title || "",
    note: task.note || "",
    mode: "plan",
    project: task.project || t("学习"),
    startDate: task.startDate || createdAt || targetDate,
    targetDate,
    estimatedMinutes: Math.max(5, Number(task.estimatedMinutes || 45)),
    status: task.status || "planned",
    priority: task.priority || "medium",
    createdAt,
    completedAt: task.completedAt || null,
    completionNote: task.completionNote || "",
    journal: (task.journal || []).map(normalizeLogEntry)
  };
}

function normalizeGoal(goal = {}) {
  const createdAt = goal.createdAt || nowISO();
  const milestones = (goal.milestones || []).length ? goal.milestones : [
    { id: uuid(), title: t("明确下一步动作"), isDone: false },
    { id: uuid(), title: t("完成一次阶段复盘"), isDone: false },
    { id: uuid(), title: t("产出可展示成果"), isDone: false }
  ];
  return {
    id: goal.id || uuid(),
    title: goal.title || "",
    purpose: goal.purpose || "",
    metric: goal.metric || t("完成可验证产出"),
    targetDate: goal.targetDate || addDaysISO(30),
    progress: Number(goal.progress || 0),
    milestones: milestones.map((item) => ({ id: item.id || uuid(), title: item.title || "里程碑", isDone: Boolean(item.isDone) })),
    createdAt,
    logs: (goal.logs || []).map(normalizeLogEntry)
  };
}

function normalizeLogEntry(entry = {}) {
  const body = entry.body || entry.content || "";
  return {
    id: entry.id || uuid(),
    title: cleanTitle(entry.title || defaultLogTitle(body)),
    createdAt: entry.createdAt || nowISO(),
    body
  };
}

function normalizeMessage(message = {}) {
  return {
    id: message.id || uuid(),
    role: message.role || "assistant",
    content: message.content || "",
    createdAt: message.createdAt || nowISO(),
    toolName: message.toolName || "",
    isError: Boolean(message.isError)
  };
}

function assistantGreeting() {
  return normalizeMessage({
    role: "assistant",
    content: t("我会记住你的计划、目标、日志和活动记录，并在你需要时帮你调整规划。"),
    createdAt: nowISO()
  });
}

async function save(options = {}) {
  const { rerender = true } = options;
  syncLegacyMessages(db);
  db = normalizeDatabase(await window.studyAI.saveDatabase(db));
  if (rerender) render();
}

function syncLegacyMessages(target = db) {
  const conversation = activeConversation(target);
  target.coachMessages = conversation?.messages || [];
}

function activeConversation(target = db) {
  return (target.coachConversations || []).find((item) => item.id === target.activeCoachConversationId) || (target.coachConversations || [])[0];
}

function activeMessages() {
  return activeConversation()?.messages || [];
}

function appendCoachMessage(message) {
  const conversation = activeConversation();
  if (!conversation) return;
  conversation.messages.push(normalizeMessage(message));
  conversation.updatedAt = nowISO();
  syncLegacyMessages();
}

function startNewConversation(title = `${t("对话")} ${dateTimeText(new Date())}`) {
  const conversation = normalizeConversation({
    id: uuid(),
    identityId: db.coachIdentity.id,
    title,
    messages: []
  }, db.coachIdentity.id);
  db.coachConversations.unshift(conversation);
  db.activeCoachConversationId = conversation.id;
  syncLegacyMessages();
}

function conversationDisplayTitle(conversation) {
  const title = String(conversation?.title || "").trim();
  if (title === "新对话" || title === "New Chat") return t("新对话");
  if (title === "默认对话" || title === "Default Chat") return t("默认对话");
  if (title === "旧对话" || title === "Old Chat") return t("旧对话");
  if (title === "新身份对话" || title === "New Identity Chat") return t("新身份对话");
  if (title.startsWith("对话 ")) return `${t("对话")} ${title.slice(3)}`;
  if (title.startsWith("今日对话 ")) return `${t("今日对话")} ${title.slice(5)}`;
  return title || t("新对话");
}

async function deleteConversation(id) {
  const conversation = db.coachConversations.find((item) => item.id === id);
  if (!conversation) return;
  if (!confirm(t("删除后不会影响教练记忆和身份信息。确定删除这个对话？"))) return;
  const wasActive = db.activeCoachConversationId === id;
  db.coachConversations = db.coachConversations.filter((item) => item.id !== id);
  if (!db.coachConversations.length) startNewConversation(t("新对话"));
  if (wasActive) db.activeCoachConversationId = db.coachConversations[0]?.id || "";
  await save();
}

async function renameConversation(id, title) {
  const conversation = db.coachConversations.find((item) => item.id === id);
  const clean = cleanTitle(title);
  if (!conversation || !clean) return;
  conversation.title = clean;
  conversation.updatedAt = nowISO();
  renamingConversationId = "";
  renameDraft = "";
  await save();
}

async function archiveStaleCoachConversationIfNeeded() {
  const conversation = activeConversation();
  if (!conversation || !conversation.messages.length) return;
  if (dayKey(conversation.updatedAt) >= todayKey()) return;
  await archiveConversation(conversation, t("每日自动归档"));
  db.coachConversations = db.coachConversations.filter((item) => item.id !== conversation.id);
  startNewConversation();
  await save({ rerender: false });
}

async function archiveAllConversations(reason) {
  for (const conversation of [...db.coachConversations]) {
    if (conversation.messages.length) await archiveConversation(conversation, reason);
  }
}

async function archiveConversation(conversation, reason) {
  if (db.archivedCoachConversations.some((item) => item.id === conversation.id)) return;
  const archive = normalizeArchive({
    id: conversation.id,
    identityId: db.coachIdentity.id,
    identityTitle: db.coachIdentity.title || t("未设置身份"),
    title: conversation.title,
    createdAt: conversation.createdAt,
    archivedAt: nowISO(),
    messages: conversation.messages,
    memorySummary: db.coachMemory.summary || "",
    keyFacts: db.coachMemory.keyFacts || []
  });
  if (window.studyAI.writeCoachArchive) {
    const output = await window.studyAI.writeCoachArchive(archive, reason);
    if (output?.ok) archive.filePath = output.path;
  }
  db.archivedCoachConversations.unshift(archive);
}

function render() {
  applyTheme();
  applyLanguage();
  byId("todayDate").textContent = dateText(new Date());
  renderSidebar();
  renderTodayPlans();
  renderTodayGoals();
  renderPlanCalendar();
  renderGoalBoard();
  renderMonitor();
  renderCoach();
  renderSettings();

  const latest = db.samples.at(-1);
  byId("latestApp").textContent = latest?.appName || t("等待采样");
  byId("latestSample").textContent = latest ? JSON.stringify(latest, null, 2) : t("暂无采样");
}

function applyLanguage() {
  document.documentElement.lang = currentLanguage();
  const setText = (selector, key) => {
    const node = document.querySelector(selector);
    if (node) node.textContent = t(key);
  };
  const setPlaceholder = (selector, key) => {
    const node = document.querySelector(selector);
    if (node) node.placeholder = t(key);
  };
  const setTitle = (selector, key) => {
    const node = document.querySelector(selector);
    if (node) node.title = t(key);
  };

  setText(".brand-copy small", "记录与教练");
  setTitle("#openSettings", "设置");
  setText(".nav-label", "工作台");
  setText('[data-view="today"]', "今日");
  setText('[data-view="planning"]', "规划");
  setText('[data-view="monitor"]', "监控");
  setText(".coach-main", "教练");
  setTitle("#newConversation", "新对话");
  setTitle("#toggleCoachList", coachExpanded ? "收起对话" : "展开对话");
  setText("#recordState", timer ? "正在记录" : "记录暂停");

  setText("#today h1", "今日");
  setText("#today article:nth-of-type(1) h2", "今日计划");
  setText("#today article:nth-of-type(2) h2", "目标推进");
  setText("#planning h1", "规划");
  setText("#planning header p", "长期目标与短期计划");
  setText("#planning .form-card:nth-of-type(1) h2", "新计划");
  setText("#planning .form-card:nth-of-type(2) h2", "新目标");
  setText("#monitor h1", "监控");
  setText("#monitor header p", "记录时长、应用分布与窗口轨迹");
  setText("#sampleNow", "立即采样");
  setText("#coach h1", "教练");
  setText("#settings h1", "设置");
  setText("#settings header p", "身份、接口、外观与采样");

  setPlaceholder("#taskTitle", "计划名称");
  setPlaceholder("#taskNote", "完成信号或备注");
  setPlaceholder("#taskProject", "项目");
  setPlaceholder("#goalTitle", "目标名称");
  setPlaceholder("#goalPurpose", "为什么做");
  setPlaceholder("#goalMetric", "衡量方式");
  setPlaceholder("#coachInput", "和教练对话");
  setPlaceholder("#identityTitle", "例如：大一计算机科学学生、高中数学偏科生");
  setPlaceholder("#apiKey", "使用 Electron safeStorage 加密保存");

  document.querySelectorAll("[data-i18n]").forEach((node) => {
    node.textContent = t(node.dataset.i18n);
  });
}

function renderSidebar() {
  document.querySelectorAll(".nav").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === currentView());
  });
  byId("toggleCoachList").textContent = coachExpanded ? "⌄" : "›";
  const container = byId("conversationList");
  container.innerHTML = "";
  if (!coachExpanded) return;

  for (const conversation of [...db.coachConversations].sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)))) {
    const row = document.createElement("div");
    row.className = `conversation-row ${conversation.id === db.activeCoachConversationId ? "active" : ""}`;
    if (conversation.id === renamingConversationId) {
      row.innerHTML = `
        <div class="conversation-edit">
          <input value="${escapeAttribute(renameDraft)}" aria-label="${t("对话标题")}" />
          <button class="commit" title="${t("确认")}">✓</button>
          <button class="cancel" title="${t("取消")}">×</button>
        </div>
      `;
      const input = row.querySelector("input");
      input.addEventListener("input", (event) => { renameDraft = event.target.value; });
      input.addEventListener("keydown", async (event) => {
        if (event.key === "Enter") await renameConversation(conversation.id, renameDraft);
        if (event.key === "Escape") {
          renamingConversationId = "";
          renameDraft = "";
          renderSidebar();
        }
      });
      row.querySelector(".commit").addEventListener("click", () => renameConversation(conversation.id, renameDraft));
      row.querySelector(".cancel").addEventListener("click", () => {
        renamingConversationId = "";
        renameDraft = "";
        renderSidebar();
      });
      requestAnimationFrame(() => input.focus());
    } else {
      row.innerHTML = `
        <button class="conversation-title">${escapeHTML(conversationDisplayTitle(conversation))}</button>
        <button class="icon-btn rename" title="${t("重命名")}">✎</button>
        <button class="icon-btn delete" title="${t("删除")}">⌫</button>
      `;
      row.querySelector(".conversation-title").addEventListener("click", async () => {
        db.activeCoachConversationId = conversation.id;
        syncLegacyMessages();
        await save();
        selectView("coach");
      });
      row.querySelector(".rename").addEventListener("click", () => {
        renamingConversationId = conversation.id;
        renameDraft = conversation.title;
        renderSidebar();
      });
      row.querySelector(".delete").addEventListener("click", () => deleteConversation(conversation.id));
    }
    container.appendChild(row);
  }
}

function renderTodayPlans() {
  const container = byId("todayPlans");
  container.innerHTML = "";
  const tasks = tasksForToday();
  if (!tasks.length) {
    container.innerHTML = `<p>${t("暂无今日计划")}</p>`;
    return;
  }
  for (const task of tasks) {
    const node = document.createElement("div");
    node.className = "item";
    const status = taskStatusLabel(task);
    node.innerHTML = `
      <div class="item-title">
        <strong class="${task.status === "done" ? "today-done" : ""}">${escapeHTML(task.title)}</strong>
        <span class="tag">${status}</span>
      </div>
      <div class="tags">
        <span class="tag">${escapeHTML(task.project || t("学习"))}</span>
        <span class="tag">${dayKey(task.startDate)} → ${dayKey(task.targetDate)}</span>
        <span class="tag">${task.estimatedMinutes || 45} ${t("分")}</span>
        <span class="tag">${priorityText(task.priority)}</span>
      </div>
      ${task.note ? `<p>${escapeHTML(task.note)}</p>` : ""}
      ${task.completionNote ? `<small>${t("完成记录")}: ${escapeHTML(task.completionNote)}</small>` : ""}
      <div class="journal-box">
        <input class="journal-title" placeholder="${t("日记标题")}" />
        <textarea class="journal-body" placeholder="${t("完成细节与感想")}"></textarea>
        <div class="inline-actions">
          <button class="save-journal">${t("保存日记")}</button>
          <button class="complete">${task.status === "done" ? t("撤销完成") : t("完成并保存")}</button>
        </div>
      </div>
      <div class="log-title-list">
        ${(task.journal || []).slice(0, 4).map((entry) => `<button class="log-button" data-log="${entry.id}">${escapeHTML(entry.title)} · ${dateText(entry.createdAt)}</button>`).join("")}
      </div>
    `;
    node.querySelector(".save-journal").addEventListener("click", async () => {
      const title = node.querySelector(".journal-title").value.trim();
      const body = node.querySelector(".journal-body").value.trim();
      if (!title && !body) return;
      task.journal.unshift(normalizeLogEntry({ title, body, createdAt: nowISO() }));
      await save();
    });
    node.querySelector(".complete").addEventListener("click", async () => {
      if (task.status === "done") {
        task.status = "planned";
        task.completedAt = null;
      } else {
        const title = node.querySelector(".journal-title").value.trim();
        const body = node.querySelector(".journal-body").value.trim();
        task.status = "done";
        task.completedAt = nowISO();
        if (title || body) {
          task.completionNote = body || title;
          task.journal.unshift(normalizeLogEntry({ title, body, createdAt: nowISO() }));
        }
      }
      await save();
    });
    node.querySelectorAll("[data-log]").forEach((button) => {
      button.addEventListener("click", () => openLogModal(task.journal.find((entry) => entry.id === button.dataset.log), `${t("计划")}: ${task.title}`));
    });
    container.appendChild(node);
  }
}

function renderTodayGoals() {
  const container = byId("todayGoals");
  container.innerHTML = "";
  if (!db.goals.length) {
    container.innerHTML = `<p>${t("暂无长期目标")}</p>`;
    return;
  }
  for (const goal of [...db.goals].sort((a, b) => String(a.targetDate).localeCompare(String(b.targetDate)))) {
    const node = document.createElement("div");
    node.className = "item";
    node.innerHTML = `
      <div class="item-title"><strong>${escapeHTML(goal.title)}</strong><span class="tag">${t("截止")} ${dayKey(goal.targetDate)}</span></div>
      ${goal.purpose ? `<p>${escapeHTML(goal.purpose)}</p>` : ""}
      <small>${t("衡量")}: ${escapeHTML(goal.metric || t("完成可验证产出"))}</small>
      <div class="list milestones">
        ${(goal.milestones || []).map((m) => `<button data-id="${m.id}">${m.isDone ? "✓" : "□"} ${escapeHTML(m.title)}</button>`).join("")}
      </div>
      <div class="journal-box">
        <input class="goal-log-title" placeholder="${t("阶段日志标题")}" />
        <textarea class="goal-log-body" placeholder="${t("阶段完成情况、细节与感想")}"></textarea>
        <button class="add-log">${t("保存阶段日志")}</button>
      </div>
      <div class="log-title-list">
        ${(goal.logs || []).slice(0, 4).map((entry) => `<button class="log-button" data-log="${entry.id}">${escapeHTML(entry.title)} · ${dateText(entry.createdAt)}</button>`).join("")}
      </div>
    `;
    node.querySelectorAll(".milestones button").forEach((button) => {
      button.addEventListener("click", async () => {
        const milestone = goal.milestones.find((item) => item.id === button.dataset.id);
        if (milestone) milestone.isDone = !milestone.isDone;
        await save();
      });
    });
    node.querySelector(".add-log").addEventListener("click", async () => {
      const title = node.querySelector(".goal-log-title").value.trim();
      const body = node.querySelector(".goal-log-body").value.trim();
      if (!title && !body) return;
      goal.logs.unshift(normalizeLogEntry({ title, body, createdAt: nowISO() }));
      await save();
    });
    node.querySelectorAll("[data-log]").forEach((button) => {
      button.addEventListener("click", () => openLogModal(goal.logs.find((entry) => entry.id === button.dataset.log), `${t("目标")}: ${goal.title}`));
    });
    container.appendChild(node);
  }
}

function renderPlanCalendar() {
  const container = byId("planCalendar");
  container.innerHTML = "";
  if (!db.tasks.length) {
    container.innerHTML = `<p>${t("暂无计划")}</p>`;
    return;
  }
  const grouped = new Map();
  for (const task of db.tasks) {
    const key = dayKey(task.targetDate);
    grouped.set(key, [...(grouped.get(key) || []), task]);
  }
  for (const key of [...grouped.keys()].sort()) {
    const group = document.createElement("div");
    group.className = "item";
    group.innerHTML = `<h3>${key}</h3><div class="list"></div>`;
    const list = group.querySelector(".list");
    for (const task of grouped.get(key).sort((a, b) => String(a.targetDate).localeCompare(String(b.targetDate)))) {
      const row = document.createElement("div");
      row.className = "item";
      row.innerHTML = `
        <div class="item-title"><strong>${escapeHTML(task.title)}</strong><button class="delete">${t("删除")}</button></div>
        ${task.note ? `<p>${escapeHTML(task.note)}</p>` : ""}
        <div class="tags">
          <span class="tag">${t("开始")} ${dayKey(task.startDate)}</span>
          <span class="tag">${t("完成")} ${dayKey(task.targetDate)}</span>
          <span class="tag">${statusText(task.status)}</span>
          <span class="tag">${escapeHTML(task.project || t("学习"))}</span>
          <span class="tag">${task.estimatedMinutes || 45} ${t("分")}</span>
        </div>
      `;
      row.querySelector(".delete").addEventListener("click", async () => {
        db.tasks = db.tasks.filter((item) => item.id !== task.id);
        await save();
      });
      list.appendChild(row);
    }
    container.appendChild(group);
  }
}

function renderGoalBoard() {
  const container = byId("goalBoard");
  container.innerHTML = "";
  if (!db.goals.length) {
    container.innerHTML = `<p>${t("暂无目标")}</p>`;
    return;
  }
  for (const goal of db.goals) {
    const node = document.createElement("div");
    node.className = "item";
    const logs = [...(goal.logs || [])].sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    node.innerHTML = `
      <div class="item-title"><strong>${escapeHTML(goal.title)}</strong><button class="delete">${t("删除")}</button></div>
      ${goal.purpose ? `<p>${escapeHTML(goal.purpose)}</p>` : ""}
      <small>${t("为什么做")}: ${escapeHTML(goal.purpose || t("未填写"))} · ${t("衡量方式")}: ${escapeHTML(goal.metric || t("完成可验证产出"))}</small>
      <div class="goal-browser"></div>
    `;
    node.querySelector(".delete").addEventListener("click", async () => {
      db.goals = db.goals.filter((item) => item.id !== goal.id);
      await save();
    });
    renderGoalLogBrowser(node.querySelector(".goal-browser"), goal, logs);
    container.appendChild(node);
  }
}

function renderGoalLogBrowser(container, goal, logs) {
  container.innerHTML = "";
  if (!logs.length) {
    container.innerHTML = `<p>${t("暂无阶段日志")}</p>`;
    return;
  }
  const months = [...new Set(logs.map((entry) => monthKey(entry.createdAt)))].sort().reverse();
  if (months.length > 1) {
    const selected = goalMonthSelection.get(goal.id) || months[0];
    goalMonthSelection.set(goal.id, selected);
    const monthList = document.createElement("div");
    monthList.className = "month-list";
    for (const key of months) {
      const button = document.createElement("button");
      button.className = "month-button";
      button.textContent = `${monthLabel(key)}（${logs.filter((entry) => monthKey(entry.createdAt) === key).length}）`;
      button.addEventListener("click", () => {
        goalMonthSelection.set(goal.id, key);
        renderGoalBoard();
      });
      monthList.appendChild(button);
    }
    container.appendChild(monthList);
    renderLogTitleList(container, goal, logs.filter((entry) => monthKey(entry.createdAt) === selected));
  } else {
    renderLogTitleList(container, goal, logs);
  }
}

function renderLogTitleList(container, goal, logs) {
  const list = document.createElement("div");
  list.className = "log-title-list";
  for (const entry of logs) {
    const button = document.createElement("button");
    button.className = "log-button";
    button.textContent = `${entry.title} · ${dateText(entry.createdAt)}`;
    button.addEventListener("click", () => openLogModal(entry, `目标：${goal.title}`));
    list.appendChild(button);
  }
  container.appendChild(list);
}

function renderMonitor() {
  byId("monitorOverview").innerHTML = `
    <div><span>${t("时长")}</span><strong>${totalMinutes()} ${t("分钟")}</strong></div>
    <div><span>${t("样本")}</span><strong>${todaysSamples().length}</strong></div>
    <div><span>${t("状态")}</span><strong>${timer ? t("正在记录") : t("暂停")}</strong></div>
  `;
  renderUsage();
  renderTimeline();
}

function renderUsage() {
  const container = byId("appUsage");
  container.innerHTML = "";
  const items = durations();
  if (!items.length) {
    container.innerHTML = `<p>${t("开始记录后显示")}</p>`;
    return;
  }
  for (const item of items.slice(0, 8)) {
    const node = document.createElement("div");
    node.className = "item";
    node.innerHTML = `<div class="item-title"><strong>${escapeHTML(item.appName)}</strong><span>${item.minutes} ${t("分")}</span></div>`;
    container.appendChild(node);
  }
}

function renderTimeline() {
  const container = byId("timeline");
  container.innerHTML = "";
  const samples = todaysSamples().slice(-28).reverse();
  if (!samples.length) {
    container.innerHTML = `<p>${t("暂无轨迹")}</p>`;
    return;
  }
  for (const sample of samples) {
    const node = document.createElement("div");
    node.className = "item";
    node.innerHTML = `<strong>${timeText(sample.timestamp)} ${escapeHTML(sample.appName)}</strong><br><small>${escapeHTML(sample.windowTitle || "")}</small>`;
    container.appendChild(node);
  }
}

function renderCoach() {
  byId("coachSubtitle").textContent = `${conversationDisplayTitle(activeConversation())} · ${identityTitle()}`;
  const messages = byId("coachMessages");
  messages.innerHTML = "";
  for (const message of activeMessages()) {
    const node = document.createElement("div");
    node.className = `message ${message.role || "assistant"}`;
    node.innerHTML = `<small>${roleText(message.role)} ${timeText(message.createdAt)}</small><div class="markdown">${renderMarkdown(message.content)}</div>`;
    messages.appendChild(node);
  }
  messages.scrollTop = messages.scrollHeight;

  byId("coachMemory").innerHTML = `
    <p>${escapeHTML(db.coachMemory.summary || t("暂无长期记忆"))}</p>
    <div class="list">${(db.coachMemory.keyFacts || []).slice(0, 8).map((fact) => `<small>⌖ ${escapeHTML(fact)}</small>`).join("")}</div>
  `;

  const latest = latestSummary();
  byId("summaryBody").innerHTML = latest ? renderMarkdown(latest.body) : t("暂无复盘");
}

function renderSettings() {
  byId("languageSelect").value = db.settings.language || "en";
  byId("identityTitle").value = document.activeElement === byId("identityTitle") ? byId("identityTitle").value : db.coachIdentity.title;
  byId("identityState").textContent = `${t("当前：")}${identityTitle()}`;
  byId("baseURL").value = db.settings.baseURL || "https://api.openai.com/v1";
  byId("model").value = db.settings.model || "gpt-4o-mini";
  byId("sampleInterval").value = String(db.settings.sampleInterval || 30);
  byId("includeWindowTitles").checked = db.settings.includeWindowTitles !== false;
  byId("captureScreenshots").checked = Boolean(db.settings.captureScreenshots);
  byId("screenshotInterval").value = db.settings.screenshotIntervalMinutes || 15;

  document.querySelectorAll(".theme-tab").forEach((button) => {
    button.classList.toggle("active", button.dataset.theme === db.settings.visualTheme);
  });
  const color = db.settings.customSidebarColor;
  byId("colorRed").value = color.red;
  byId("colorGreen").value = color.green;
  byId("colorBlue").value = color.blue;
  byId("colorRedValue").textContent = color.red;
  byId("colorGreenValue").textContent = color.green;
  byId("colorBlueValue").textContent = color.blue;
  byId("customColorPanel").style.display = db.settings.visualTheme === "custom" ? "grid" : "none";

  renderArchives();
}

function renderArchives() {
  const container = byId("archives");
  container.innerHTML = "";
  if (!db.archivedCoachConversations.length) {
    container.innerHTML = `<p>${t("暂无归档")}</p>`;
    return;
  }
  const grouped = new Map();
  for (const archive of db.archivedCoachConversations) {
    const key = archive.identityTitle || t("未设置身份");
    grouped.set(key, [...(grouped.get(key) || []), archive]);
  }
  for (const [identity, archives] of [...grouped.entries()].sort((a, b) => a[0].localeCompare(b[0], "zh-Hans-CN"))) {
    const group = document.createElement("div");
    group.className = "item";
    group.innerHTML = `<strong>${escapeHTML(identity)}</strong><div class="archive-list"></div>`;
    const list = group.querySelector(".archive-list");
    for (const archive of archives.sort((a, b) => String(b.archivedAt).localeCompare(String(a.archivedAt)))) {
      const row = document.createElement("div");
      row.className = "archive-row";
      row.innerHTML = `<strong>${escapeHTML(archive.title)}</strong><br><small>${dateTimeText(archive.archivedAt)} · ${archive.messages.length} ${t("条消息")}${archive.filePath ? ` · ${escapeHTML(archive.filePath)}` : ""}</small>`;
      list.appendChild(row);
    }
    container.appendChild(group);
  }
}

async function addTaskFromForm() {
  const title = byId("taskTitle").value.trim();
  if (!title) return;
  const start = byId("taskStartDate").value || todayKey();
  const target = byId("taskDate").value || start;
  if (target < start) {
    alert(t("完成日期不能早于开始日期。"));
    return;
  }
  db.tasks.unshift(normalizeTask({
    title,
    note: byId("taskNote").value.trim(),
    project: byId("taskProject").value.trim() || t("学习"),
    startDate: dateInputToISO(start),
    targetDate: dateInputToISO(target),
    estimatedMinutes: Number(byId("taskMinutes").value || 45),
    priority: byId("taskPriority").value,
    status: "planned",
    createdAt: nowISO()
  }));
  byId("taskTitle").value = "";
  byId("taskNote").value = "";
  await save();
}

async function addGoalFromForm() {
  const title = byId("goalTitle").value.trim();
  if (!title) return;
  db.goals.unshift(normalizeGoal({
    title,
    purpose: byId("goalPurpose").value.trim(),
    metric: byId("goalMetric").value.trim() || t("完成可验证产出"),
    targetDate: addDaysISO(Number(byId("goalDays").value || 30)),
    createdAt: nowISO()
  }));
  byId("goalTitle").value = "";
  byId("goalPurpose").value = "";
  byId("goalMetric").value = "";
  await save();
}

async function saveIdentity() {
  const title = byId("identityTitle").value.trim();
  if (!title) return;
  const oldTitle = db.coachIdentity.title.trim();
  if (oldTitle && oldTitle !== title) {
    const ok = confirm(t("修改身份信息会归档当前身份下的教练记忆和全部对话，并开启新的身份记忆。是否继续？"));
    if (!ok) {
      byId("identityTitle").value = oldTitle;
      return;
    }
    await archiveAllConversations(`${t("身份信息从")} “${oldTitle}” ${t("修改为")} “${title}”`);
    db.coachIdentity = normalizeIdentity({ title });
    db.coachMemory = { summary: "", keyFacts: [], updatedAt: "" };
    db.coachConversations = [];
    startNewConversation(t("新身份对话"));
    appendCoachMessage({ role: "assistant", content: `${t("已切换到身份")} “${title}”. ${t("我会基于这个身份重新建立对话记忆。")}`, createdAt: nowISO() });
  } else {
    db.coachIdentity.title = title;
    db.coachIdentity.updatedAt = nowISO();
    for (const conversation of db.coachConversations) conversation.identityId = db.coachIdentity.id;
  }
  await save();
}

async function saveSettings() {
  db.settings.baseURL = byId("baseURL").value.trim() || "https://api.openai.com/v1";
  db.settings.model = byId("model").value.trim() || "gpt-4o-mini";
  const apiKey = byId("apiKey").value.trim();
  if (apiKey) {
    db.apiKeyDraft = apiKey;
    byId("apiKey").value = "";
  }
  await save();
  byId("settingsStatus").textContent = t("设置已保存");
}

async function sampleNow() {
  const sample = await window.studyAI.sampleActiveWindow(db.settings);
  db.samples.push(sample);
  trimSamples();
  await save();
}

function setRecording(active) {
  if (active && !timer) {
    sampleNow();
    timer = setInterval(sampleNow, Math.max(5, Number(db.settings.sampleInterval || 30)) * 1000);
  } else if (!active && timer) {
    clearInterval(timer);
    timer = null;
  }
  byId("recordDot").classList.toggle("active", Boolean(timer));
  byId("recordState").textContent = timer ? t("正在记录") : t("记录暂停");
  byId("toggleRecord").checked = Boolean(timer);
  renderMonitor();
}

async function sendCoachMessage() {
  const input = byId("coachInput");
  const content = input.value.trim();
  if (!content || coachThinking) return;
  input.value = "";

  await archiveStaleCoachConversationIfNeeded();
  appendCoachMessage({ id: uuid(), role: "user", content, createdAt: nowISO() });
  await save();

  coachThinking = true;
  byId("sendCoach").disabled = true;
  try {
    const response = await window.studyAI.runCoach(db, content);
    const toolResults = await applyCoachActions(response.actions || []);
    for (const result of toolResults) {
      appendCoachMessage({ id: uuid(), role: "tool", content: result.message, toolName: result.action, isError: !result.success, createdAt: nowISO() });
    }
    if (response.memory_update) {
      db.coachMemory.summary = response.memory_update;
      db.coachMemory.updatedAt = nowISO();
    }
    if (response.key_facts?.length) {
      db.coachMemory.keyFacts = [...new Set([...(db.coachMemory.keyFacts || []), ...response.key_facts])].slice(0, 24);
      db.coachMemory.updatedAt = nowISO();
    }
    if (response.daily_summary) {
      const summary = renderDailySummary(response.daily_summary);
      db.summaries = db.summaries.filter((item) => item.dateKey !== summary.dateKey);
      db.summaries.push(summary);
    }
    appendCoachMessage({ id: uuid(), role: "assistant", content: response.reply || t("我已读取当前规划上下文。"), createdAt: nowISO() });
    await save();
  } finally {
    coachThinking = false;
    byId("sendCoach").disabled = false;
  }
}

async function applyCoachActions(actions) {
  const results = [];
  for (const action of actions.slice(0, 12)) {
    const type = action.type;
    if (type === "add_plan") {
      const title = String(action.title || "").trim();
      if (!title) {
        results.push({ action: type, success: false, message: t("新增计划失败：缺少标题。") });
        continue;
      }
      const start = action.start_date || action.startDate || action.date || todayKey();
      const target = action.target_date || action.targetDate || action.date || start;
      db.tasks.unshift(normalizeTask({
        title,
        note: action.note || "",
        project: action.project || t("学习"),
        startDate: dateInputToISO(start),
        targetDate: dateInputToISO(target),
        estimatedMinutes: Math.max(5, Number(action.estimated_minutes || action.estimatedMinutes || 45)),
        status: "planned",
        priority: action.priority || "medium",
        createdAt: nowISO()
      }));
      results.push({ action: type, success: true, message: `${t("已新增计划")}: ${title}.` });
    } else if (type === "update_plan") {
      const task = db.tasks.find((item) => item.id === action.target_id);
      if (!task) {
        results.push({ action: type, success: false, message: t("更新计划失败：未找到目标计划。") });
        continue;
      }
      if (action.title) task.title = action.title;
      if (action.note !== undefined) task.note = action.note;
      if (action.project) task.project = action.project;
      if (action.start_date || action.startDate) task.startDate = dateInputToISO(action.start_date || action.startDate);
      if (action.target_date || action.targetDate || action.date) task.targetDate = dateInputToISO(action.target_date || action.targetDate || action.date);
      if (action.estimated_minutes || action.estimatedMinutes) task.estimatedMinutes = Math.max(5, Number(action.estimated_minutes || action.estimatedMinutes));
      if (action.priority) task.priority = action.priority;
      results.push({ action: type, success: true, message: `${t("已更新计划")}: ${task.title}.` });
    } else if (type === "delete_plan") {
      const task = db.tasks.find((item) => item.id === action.target_id);
      db.tasks = db.tasks.filter((item) => item.id !== action.target_id);
      results.push({ action: type, success: Boolean(task), message: task ? `${t("已删除计划")}: ${task.title}.` : t("删除计划失败：未找到目标计划。") });
    } else if (type === "complete_plan") {
      const task = db.tasks.find((item) => item.id === action.target_id);
      if (!task) {
        results.push({ action: type, success: false, message: t("完成计划失败：未找到目标计划。") });
        continue;
      }
      task.status = "done";
      task.completedAt = nowISO();
      if (action.body || action.title) {
        task.completionNote = action.body || action.title || "";
        task.journal.unshift(normalizeLogEntry({ title: action.title || "", body: action.body || "", createdAt: nowISO() }));
      }
      results.push({ action: type, success: true, message: `${t("已标记完成")}: ${task.title}.` });
    } else if (type === "add_plan_log") {
      const task = db.tasks.find((item) => item.id === action.target_id);
      if (!task || !(action.body || action.title)) {
        results.push({ action: type, success: false, message: t("添加计划日记失败。") });
        continue;
      }
      task.journal.unshift(normalizeLogEntry({ title: action.title || "", body: action.body || "", createdAt: nowISO() }));
      results.push({ action: type, success: true, message: `${t("已添加计划日记")}: ${task.title}.` });
    } else if (type === "add_goal") {
      const title = String(action.title || "").trim();
      if (!title) {
        results.push({ action: type, success: false, message: t("新增目标失败：缺少标题。") });
        continue;
      }
      db.goals.unshift(normalizeGoal({
        title,
        purpose: action.purpose || "",
        metric: action.metric || t("完成可验证产出"),
        targetDate: addDaysISO(Number(action.days || 30)),
        createdAt: nowISO()
      }));
      results.push({ action: type, success: true, message: `${t("已新增目标")}: ${title}.` });
    } else if (type === "update_goal") {
      const goal = db.goals.find((item) => item.id === action.target_id);
      if (!goal) {
        results.push({ action: type, success: false, message: t("更新目标失败：未找到目标。") });
        continue;
      }
      if (action.title) goal.title = action.title;
      if (action.purpose !== undefined) goal.purpose = action.purpose;
      if (action.metric) goal.metric = action.metric;
      if (action.days) goal.targetDate = addDaysISO(Number(action.days));
      results.push({ action: type, success: true, message: `${t("已更新目标")}: ${goal.title}.` });
    } else if (type === "delete_goal") {
      const goal = db.goals.find((item) => item.id === action.target_id);
      db.goals = db.goals.filter((item) => item.id !== action.target_id);
      results.push({ action: type, success: Boolean(goal), message: goal ? `${t("已删除目标")}: ${goal.title}.` : t("删除目标失败：未找到目标。") });
    } else if (type === "add_goal_log") {
      const goal = db.goals.find((item) => item.id === action.target_id);
      if (!goal || !(action.body || action.title)) {
        results.push({ action: type, success: false, message: t("添加目标日志失败。") });
        continue;
      }
      goal.logs.unshift(normalizeLogEntry({ title: action.title || "", body: action.body || "", createdAt: nowISO() }));
      results.push({ action: type, success: true, message: `${t("已添加目标日志")}: ${goal.title}.` });
    } else if (type === "read_planning_context") {
      results.push({ action: type, success: true, message: `${t("已读取上下文")}: ${t("计划")} ${db.tasks.length}, ${t("目标")} ${db.goals.length}.` });
    } else if (type === "list_coach_files") {
      const files = await window.studyAI.listCoachFiles();
      results.push({ action: type, success: true, message: files.length ? `${t("教练文件")}: ${files.map((file) => file.name).join("、")}` : t("教练文件区暂无文件。") });
    } else if (type === "read_coach_file") {
      const output = await window.studyAI.readCoachFile(action.file_name || "coach-note.md");
      results.push({ action: type, success: output.ok, message: output.ok ? `${t("已读取")} ${output.name}: ${output.content.slice(0, 1200)}` : `${t("读取文件失败")}: ${output.error}` });
    } else if (type === "write_coach_file") {
      const output = await window.studyAI.writeCoachFile(action.file_name || "coach-note.md", action.content || action.body || "");
      results.push({ action: type, success: output.ok, message: output.ok ? `${t("已写入教练文件")}: ${output.name}.` : `${t("写入文件失败")}: ${output.error}` });
    }
  }
  return results;
}

function renderDailySummary(report) {
  const done = tasksForToday().filter((task) => task.status === "done").length;
  const score = Math.max(1, Math.min(10, Math.round(2 + done + Math.min(3, totalMinutes() / 60))));
  const lines = [
    `# ${t("总评")}`,
    report.executive_summary || t("今天已有可复盘的规划记录。"),
    "",
    `## ${t("评分依据")}`,
    `- ${score}/10`,
    `- ${t("今日任务完成")} ${done}/${tasksForToday().length}`,
    `- ${t("记录时长约")} ${totalMinutes()} ${t("分钟")}`,
    "",
    `## ${t("亮点")}`,
    ...asList(report.highlights, 2),
    "",
    `## ${t("阻碍")}`,
    ...asList(report.obstacles, 2),
    "",
    `## ${t("改进建议")}`,
    ...asList(report.recommendations, 3),
    "",
    `## ${t("明日计划")}`,
    ...asList(report.tomorrow_plan, 3)
  ];
  const warnings = asList(report.data_warnings || [], 2);
  if (warnings.length) lines.push("", `## ${t("数据边界")}`, ...warnings);
  return { id: uuid(), dateKey: todayKey(), generatedAt: nowISO(), score, model: db.settings.model || t("教练"), body: lines.join("\n") };
}

function applyTheme() {
  const theme = db.settings.visualTheme;
  const color = db.settings.customSidebarColor || { red: 8, green: 27, blue: 20 };
  const root = document.documentElement;
  const set = (name, value) => root.style.setProperty(name, value);
  if (theme === "night") {
    set("--canvas", "#10131d");
    set("--surface", "#171b28");
    set("--sidebar", "rgba(20, 23, 34, 0.72)");
    set("--text", "#eff2f4");
    set("--muted", "#aab3c1");
    set("--border", "#353a4e");
    set("--accent", "#80d8be");
    set("--selection", "#242a3b");
    set("--warning", "#ff9d66");
    set("--good", "#7bdf8d");
  } else if (theme === "custom") {
    const rgb = colorRGB(color);
    set("--canvas", mixColor(rgb, [255, 255, 255], 0.94));
    set("--surface", mixColor(rgb, [255, 255, 255], 0.86));
    set("--sidebar", `rgba(${rgb.join(", ")}, 0.28)`);
    set("--text", "#1f2421");
    set("--muted", "#69706d");
    set("--border", `rgba(${rgb.join(", ")}, 0.34)`);
    set("--accent", `rgb(${rgb.join(", ")})`);
    set("--selection", `rgba(${rgb.join(", ")}, 0.18)`);
    set("--warning", "#bd4e30");
    set("--good", "#1f8a50");
  } else {
    set("--canvas", "#fbfbf5");
    set("--surface", "#fffdf7");
    set("--sidebar", "rgba(255, 255, 255, 0.54)");
    set("--text", "#1f2421");
    set("--muted", "#6b706b");
    set("--border", "#d7dccd");
    set("--accent", "#176b51");
    set("--selection", "#edf5e6");
    set("--warning", "#bd4e30");
    set("--good", "#1f8a50");
  }
}

function renderMarkdown(text) {
  const lines = String(text || "").replace(/\r\n/g, "\n").split("\n");
  const html = [];
  let paragraph = [];
  let list = [];
  let ordered = false;
  let code = null;
  let math = null;

  const flushParagraph = () => {
    if (paragraph.length) {
      html.push(`<p>${renderInline(paragraph.join(" "))}</p>`);
      paragraph = [];
    }
  };
  const flushList = () => {
    if (list.length) {
      html.push(`<${ordered ? "ol" : "ul"}>${list.map((item) => `<li>${renderInline(item)}</li>`).join("")}</${ordered ? "ol" : "ul"}>`);
      list = [];
    }
  };

  for (const line of lines) {
    if (code !== null) {
      if (line.startsWith("```")) {
        html.push(`<pre><code>${escapeHTML(code.join("\n"))}</code></pre>`);
        code = null;
      } else {
        code.push(line);
      }
      continue;
    }
    if (math !== null) {
      if (line.trim() === "$$" || line.trim() === "\\]") {
        html.push(`<div class="math-block">${renderMath(math.join("\n"), true)}</div>`);
        math = null;
      } else {
        math.push(line);
      }
      continue;
    }
    const trimmed = line.trim();
    if (!trimmed) {
      flushParagraph();
      flushList();
      continue;
    }
    if (trimmed.startsWith("```")) {
      flushParagraph();
      flushList();
      code = [];
      continue;
    }
    if (trimmed === "$$" || trimmed === "\\[") {
      flushParagraph();
      flushList();
      math = [];
      continue;
    }
    const heading = trimmed.match(/^(#{1,3})\s+(.+)$/);
    if (heading) {
      flushParagraph();
      flushList();
      html.push(`<h${heading[1].length}>${renderInline(heading[2])}</h${heading[1].length}>`);
      continue;
    }
    const bullet = trimmed.match(/^[-*]\s+(.+)$/);
    if (bullet) {
      flushParagraph();
      if (list.length && ordered) flushList();
      ordered = false;
      list.push(bullet[1]);
      continue;
    }
    const number = trimmed.match(/^\d+[.)]\s+(.+)$/);
    if (number) {
      flushParagraph();
      if (list.length && !ordered) flushList();
      ordered = true;
      list.push(number[1]);
      continue;
    }
    paragraph.push(trimmed);
  }
  if (code !== null) html.push(`<pre><code>${escapeHTML(code.join("\n"))}</code></pre>`);
  if (math !== null) html.push(`<div class="math-block">${renderMath(math.join("\n"), true)}</div>`);
  flushParagraph();
  flushList();
  return html.join("");
}

function renderInline(text) {
  const tokens = [];
  let value = String(text || "").replace(/\\\((.+?)\\\)|(?<!\$)\$([^$\n]+?)\$(?!\$)/g, (_match, paren, dollar) => {
    const token = `@@MATH${tokens.length}@@`;
    tokens.push(renderMath(paren || dollar || "", false));
    return token;
  });
  value = escapeHTML(value)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*]+)\*/g, "<em>$1</em>");
  tokens.forEach((token, index) => {
    value = value.replace(`@@MATH${index}@@`, `<span class="math-inline">${token}</span>`);
  });
  return value;
}

function renderMath(source, displayMode) {
  const text = String(source || "").trim();
  if (!text) return "";
  if (window.katex?.renderToString) {
    try {
      return window.katex.renderToString(text, { throwOnError: false, displayMode });
    } catch {
      return escapeHTML(text);
    }
  }
  return escapeHTML(text);
}

function selectView(view) {
  document.querySelectorAll(".view").forEach((section) => section.classList.toggle("active", section.id === view));
  document.querySelectorAll(".nav").forEach((button) => button.classList.toggle("active", button.dataset.view === view));
}

function currentView() {
  return document.querySelector(".view.active")?.id || "today";
}

function openLogModal(entry, meta) {
  if (!entry) return;
  byId("modalMeta").textContent = `${meta} · ${dateTimeText(entry.createdAt)}`;
  byId("modalTitle").textContent = entry.title;
  byId("modalBody").innerHTML = renderMarkdown(entry.body || t("暂无正文"));
  byId("logModal").classList.remove("hidden");
}

function closeLogModal() {
  byId("logModal").classList.add("hidden");
}

function setDefaultFormDates() {
  byId("taskStartDate").value = todayKey();
  byId("taskDate").value = todayKey();
}

function tasksForToday(dateKey = todayKey()) {
  return db.tasks
    .filter((task) => {
      const start = dayKey(task.startDate);
      const target = dayKey(task.targetDate);
      const completed = task.completedAt ? dayKey(task.completedAt) : "";
      return (start <= dateKey && dateKey <= target && task.status !== "done") ||
        completed === dateKey ||
        (target < dateKey && task.status !== "done");
    })
    .sort((a, b) => todayTaskRank(a, dateKey) - todayTaskRank(b, dateKey) || String(a.targetDate).localeCompare(String(b.targetDate)));
}

function todayTaskRank(task, key) {
  if (task.status === "done") return 2;
  if (dayKey(task.targetDate) < key) return 0;
  return 1;
}

function taskStatusLabel(task) {
  if (task.status === "done") return t("已完成");
  if (dayKey(task.targetDate) < todayKey()) return t("逾期");
  if (task.status === "doing") return t("进行中");
  return t("待开始");
}

function todaysSamples() {
  return db.samples.filter((sample) => dayKey(sample.timestamp) === todayKey());
}

function durations() {
  const counts = new Map();
  for (const sample of todaysSamples()) counts.set(sample.appName, (counts.get(sample.appName) || 0) + 1);
  return [...counts.entries()]
    .map(([appName, count]) => ({ appName, minutes: Math.max(1, Math.round((count * Number(db.settings.sampleInterval || 30)) / 60)) }))
    .sort((a, b) => b.minutes - a.minutes);
}

function totalMinutes() {
  return durations().reduce((sum, item) => sum + item.minutes, 0);
}

function latestSummary() {
  return db.summaries.filter((summary) => summary.dateKey === todayKey()).sort((a, b) => String(b.generatedAt).localeCompare(String(a.generatedAt)))[0];
}

function trimSamples() {
  const limit = Math.max(200, Number(db.settings.maxSamplesPerDay || 2400));
  const grouped = new Map();
  for (const sample of db.samples) {
    const key = dayKey(sample.timestamp);
    grouped.set(key, [...(grouped.get(key) || []), sample]);
  }
  db.samples = [...grouped.values()].flatMap((samples) => samples.slice(-limit));
}

function asList(values, count) {
  return (values || []).slice(0, count).map((value) => `- ${value}`);
}

function statusText(status) {
  return { planned: t("待开始"), doing: t("进行中"), done: t("已完成") }[status] || t("待开始");
}

function priorityText(priority) {
  return { low: t("低"), medium: t("中"), high: t("高") }[priority] || t("中");
}

function roleText(role) {
  return { user: t("我"), assistant: t("教练"), tool: t("工具"), system: t("系统") }[role] || t("教练");
}

function identityTitle() {
  return db.coachIdentity.title?.trim() || t("未设置身份");
}

function todayKey() {
  return dayKey(new Date());
}

function dayKey(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value || Date.now());
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 10);
}

function monthKey(value = new Date()) {
  return dayKey(value).slice(0, 7);
}

function monthLabel(key) {
  const [year, month] = String(key).split("-");
  return `${year} 年 ${Number(month)} 月`;
}

function dateText(value) {
  return new Date(value || Date.now()).toLocaleDateString("zh-CN");
}

function dateTimeText(value) {
  return new Date(value || Date.now()).toLocaleString("zh-CN", { hour12: false });
}

function timeText(value) {
  return new Date(value || Date.now()).toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
}

function dateInputToISO(value) {
  return new Date(`${String(value || todayKey()).slice(0, 10)}T12:00:00`).toISOString();
}

function addDaysISO(days) {
  const date = new Date();
  date.setDate(date.getDate() + Math.max(1, Number(days || 1)));
  return date.toISOString();
}

function defaultLogTitle(body) {
  const clean = String(body || "").trim();
  return clean ? clean.slice(0, 18) : t("未命名记录");
}

function cleanTitle(value) {
  return String(value || "").trim() || t("未命名");
}

function clamp18(value) {
  return Math.max(0, Math.min(63, Number(value || 0)));
}

function colorRGB(color) {
  return [color.red, color.green, color.blue].map((value) => Math.round((clamp18(value) / 63) * 255));
}

function mixColor(foreground, background, backgroundWeight) {
  const rgb = foreground.map((value, index) => Math.round(value * (1 - backgroundWeight) + background[index] * backgroundWeight));
  return `rgb(${rgb.join(", ")})`;
}

function escapeHTML(value) {
  return String(value || "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#039;"
  }[char]));
}

function escapeAttribute(value) {
  return escapeHTML(value).replace(/`/g, "&#096;");
}
