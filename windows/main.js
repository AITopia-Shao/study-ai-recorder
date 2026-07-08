const { app, BrowserWindow, ipcMain, safeStorage } = require("electron");
const fs = require("fs/promises");
const path = require("path");
const { execFile } = require("child_process");
const { randomUUID } = require("crypto");

const DEFAULT_SETTINGS = {
  baseURL: "https://api.openai.com/v1",
  model: "gpt-4o-mini",
  language: "en",
  visualTheme: "day",
  sampleInterval: 30,
  includeWindowTitles: true,
  captureScreenshots: false,
  screenshotIntervalMinutes: 15,
  maxSamplesPerDay: 2400,
  enabledAgentSkillIDs: [
    "evidenceAudit",
    "scoringRubric",
    "trajectorySynthesis",
    "goalAlignment",
    "focusRecovery",
    "tomorrowPlanning"
  ],
  deterministicScoring: true,
  compactSummaryStyle: true,
  customSidebarColor: { red: 8, green: 27, blue: 20 },
  encryptedAPIKey: ""
};

const DEFAULT_DB = {
  tasks: [],
  goals: [],
  samples: [],
  summaries: [],
  coachMessages: [],
  coachIdentity: { id: "", title: "", createdAt: "", updatedAt: "" },
  coachConversations: [],
  activeCoachConversationId: "",
  archivedCoachConversations: [],
  coachMemory: { summary: "", keyFacts: [], updatedAt: "" },
  settings: DEFAULT_SETTINGS
};

let lastScreenshotAt = 0;

function databasePath() {
  return path.join(app.getPath("userData"), "database.json");
}

function snapshotFolder(dateKey) {
  return path.join(app.getPath("userData"), "Snapshots", dateKey);
}

function coachFilesFolder() {
  return path.join(app.getPath("userData"), "CoachFiles");
}

function coachArchiveFolder(identityTitle) {
  return path.join(app.getPath("userData"), "CoachArchives", safePathSegment(identityTitle || "未设置身份"));
}

async function readDatabase() {
  try {
    const raw = await fs.readFile(databasePath(), "utf8");
    const parsed = JSON.parse(raw);
    const settings = { ...DEFAULT_SETTINGS, ...(parsed.settings || {}) };
    settings.language = normalizeLanguage(settings.language);
    if (settings.visualTheme === "boulevard" || settings.visualTheme === "system") settings.visualTheme = "day";
    if (settings.visualTheme === "starlight") settings.visualTheme = "night";
    settings.customSidebarColor = {
      ...DEFAULT_SETTINGS.customSidebarColor,
      ...(settings.customSidebarColor || {})
    };
    return {
      ...DEFAULT_DB,
      ...parsed,
      settings
    };
  } catch {
    return JSON.parse(JSON.stringify(DEFAULT_DB));
  }
}

function normalizeLanguage(value) {
  return ["en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "es"].includes(value) ? value : "en";
}

function languageName(value) {
  return {
    en: "English",
    "zh-Hans": "Simplified Chinese",
    "zh-Hant": "Traditional Chinese",
    ja: "Japanese",
    ko: "Korean",
    fr: "French",
    es: "Spanish"
  }[normalizeLanguage(value)] || "English";
}

function languageInstruction(settings = {}) {
  return `Reply to the user in ${languageName(settings.language)}. Keep tool action JSON keys unchanged.`;
}

async function writeDatabase(next) {
  await fs.mkdir(app.getPath("userData"), { recursive: true });
  await fs.writeFile(databasePath(), JSON.stringify(next, null, 2), "utf8");
  return next;
}

function publicDatabase(db) {
  const copy = JSON.parse(JSON.stringify(db));
  copy.settings = { ...DEFAULT_SETTINGS, ...(copy.settings || {}), encryptedAPIKey: "" };
  copy.apiKeyConfigured = Boolean(decryptAPIKey(db.settings?.encryptedAPIKey || ""));
  delete copy.apiKeyDraft;
  return copy;
}

function encryptAPIKey(value) {
  if (!value) return "";
  if (!safeStorage.isEncryptionAvailable()) {
    return Buffer.from(value, "utf8").toString("base64");
  }
  return safeStorage.encryptString(value).toString("hex");
}

function decryptAPIKey(value) {
  if (!value) return "";
  try {
    if (!safeStorage.isEncryptionAvailable()) {
      return Buffer.from(value, "base64").toString("utf8");
    }
    return safeStorage.decryptString(Buffer.from(value, "hex"));
  } catch {
    return "";
  }
}

function createWindow() {
  const window = new BrowserWindow({
    width: 1180,
    height: 760,
    minWidth: 1080,
    minHeight: 720,
    title: "Trace",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  window.loadFile(path.join(__dirname, "src", "index.html"));
}

function dayKey(date = new Date()) {
  const value = date instanceof Date ? date : new Date(date || Date.now());
  const local = new Date(value.getTime() - value.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 10);
}

function dateTimeText(value) {
  return new Date(value || Date.now()).toLocaleString("zh-CN", { hour12: false });
}

function monthKey(value = new Date()) {
  return dayKey(value).slice(0, 7);
}

function uuid() {
  return randomUUID();
}

function runPowerShell(script) {
  return new Promise((resolve) => {
    execFile("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script], { windowsHide: true }, (error, stdout, stderr) => {
      if (error) {
        resolve({ ok: false, error: stderr || error.message, stdout: "" });
        return;
      }
      resolve({ ok: true, stdout: stdout.trim() });
    });
  });
}

function activeWindowScript(includeWindowTitles) {
  return `
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@
$h = [Win32]::GetForegroundWindow()
$builder = New-Object System.Text.StringBuilder 1024
[void][Win32]::GetWindowText($h, $builder, $builder.Capacity)
$pidValue = 0
[void][Win32]::GetWindowThreadProcessId($h, [ref]$pidValue)
$proc = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
[PSCustomObject]@{
  timestamp = (Get-Date).ToUniversalTime().ToString("o")
  appName = if ($proc) { $proc.ProcessName } else { "未知应用" }
  bundleIdentifier = ""
  processID = $pidValue
  windowTitle = if (${includeWindowTitles ? "$true" : "$false"}) { $builder.ToString() } else { "" }
} | ConvertTo-Json -Compress
`;
}

function screenshotScript(filePath) {
  const escaped = filePath.replace(/'/g, "''");
  return `
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$path = '${escaped}'
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
$path
`;
}

function ocrScript(filePath) {
  const escaped = filePath.replace(/'/g, "''");
  return `
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
  $null = [Windows.Storage.FileAccessMode, Windows.Storage, ContentType=WindowsRuntime]
  $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
  $null = [Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType=WindowsRuntime]
  $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation\`1'
  })[0]
  function Await($operation, $type) {
    $asTask = $asTaskGeneric.MakeGenericMethod($type)
    $task = $asTask.Invoke($null, @($operation))
    $task.Wait() | Out-Null
    $task.Result
  }
  $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync('${escaped}')) ([Windows.Storage.StorageFile])
  $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
  if ($null -eq $engine) { "" } else {
    $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $result.Text
  }
} catch {
  ""
}
`;
}

async function captureSnapshotIfNeeded(settings) {
  if (!settings.captureScreenshots) return { snapshotPath: "", screenText: "" };
  const interval = Math.max(1, settings.screenshotIntervalMinutes || 15) * 60 * 1000;
  if (lastScreenshotAt && Date.now() - lastScreenshotAt < interval) {
    return { snapshotPath: "", screenText: "" };
  }

  const folder = snapshotFolder(dayKey());
  await fs.mkdir(folder, { recursive: true });
  const filePath = path.join(folder, `snapshot-${Math.floor(Date.now() / 1000)}.png`);
  const capture = await runPowerShell(screenshotScript(filePath));
  if (!capture.ok) return { snapshotPath: "", screenText: "" };
  lastScreenshotAt = Date.now();
  const ocr = await runPowerShell(ocrScript(filePath));
  return {
    snapshotPath: filePath,
    screenText: ocr.ok ? ocr.stdout.slice(0, 3000) : ""
  };
}

async function sampleActiveWindow(settings) {
  const output = await runPowerShell(activeWindowScript(settings.includeWindowTitles));
  let sample;
  try {
    sample = output.ok ? JSON.parse(output.stdout) : {};
  } catch {
    sample = {};
  }

  const snapshot = await captureSnapshotIfNeeded(settings);
  return {
    id: uuid(),
    timestamp: sample.timestamp || new Date().toISOString(),
    appName: sample.appName || "未知应用",
    bundleIdentifier: sample.bundleIdentifier || "",
    processID: sample.processID || 0,
    windowTitle: sample.windowTitle || "",
    snapshotPath: snapshot.snapshotPath,
    screenText: snapshot.screenText
  };
}

function samplesOnToday(samples) {
  const today = dayKey();
  return samples.filter((sample) => String(sample.timestamp || "").slice(0, 10) === today);
}

function appDurations(samples, sampleInterval) {
  const counts = new Map();
  for (const sample of samples) {
    counts.set(sample.appName, (counts.get(sample.appName) || 0) + 1);
  }
  return [...counts.entries()]
    .map(([appName, count]) => ({ appName, minutes: Math.max(1, Math.round((count * sampleInterval) / 60)) }))
    .sort((a, b) => b.minutes - a.minutes);
}

function tasksForToday(tasks, date = new Date()) {
  const key = dayKey(date);
  return (tasks || [])
    .filter((task) => {
      const start = dayKey(task.startDate || task.createdAt || task.targetDate || date);
      const target = dayKey(task.targetDate || date);
      const completed = task.completedAt ? dayKey(task.completedAt) : "";
      const isActive = start <= key && key <= target && task.status !== "done";
      const completedToday = completed === key;
      const overdue = target < key && task.status !== "done";
      return isActive || completedToday || overdue;
    })
    .sort((a, b) => {
      const rank = (task) => {
        if (task.status === "done") return 2;
        if (dayKey(task.targetDate) < key) return 0;
        return 1;
      };
      return rank(a) - rank(b) || String(a.targetDate || "").localeCompare(String(b.targetDate || ""));
    });
}

function analyzeDay(db) {
  const today = dayKey();
  const tasks = tasksForToday(db.tasks, new Date());
  const goals = db.goals || [];
  const samples = samplesOnToday(db.samples || []);
  const done = tasks.filter((task) => task.status === "done").length;
  const activeMinutes = appDurations(samples, db.settings.sampleInterval || 30).reduce((sum, item) => sum + item.minutes, 0);
  const appCount = new Set(samples.map((sample) => sample.appName)).size;

  let score = 2;
  if (activeMinutes >= 120 && samples.length >= 6) score += 3;
  else if (activeMinutes >= 35 && samples.length >= 3) score += 2;
  else if (activeMinutes >= 8 || tasks.length || goals.length) score += 1;

  if (tasks.length) {
    const ratio = done / tasks.length;
    if (ratio >= 0.8) score += 2;
    else if (ratio >= 0.4) score += 1;
  }

  if (activeMinutes >= 180) score += 2;
  else if (activeMinutes >= 60) score += 1;

  if (goals.length && tasks.some((task) => task.mode === "goal" || task.priority === "high")) score += 1;
  if (appCount >= 7 && activeMinutes < 120) score -= 1;

  return {
    today,
    tasks,
    goals,
    samples,
    done,
    activeMinutes,
    score: Math.max(1, Math.min(10, score)),
    appText: appDurations(samples, db.settings.sampleInterval || 30)
      .slice(0, 8)
      .map((item) => `- ${item.appName}: ${item.minutes} 分钟`)
      .join("\\n"),
    timelineText: samples.slice(-50).map((sample) => `- ${new Date(sample.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })} ${sample.appName}${sample.windowTitle ? ` · ${sample.windowTitle}` : ""}`).join("\\n"),
    screenText: samples.map((sample) => sample.screenText).filter(Boolean).slice(-12).join("\\n---\\n")
  };
}

function localSummary(db, reason = "") {
  const day = analyzeDay(db);
  return {
    id: uuid(),
    dateKey: day.today,
    generatedAt: new Date().toISOString(),
    score: day.score,
    model: reason ? "本地启发式" : "本地",
    body: [
      "总评",
      day.activeMinutes ? `今天记录到约 ${day.activeMinutes} 分钟轨迹。` : "今天缺少连续轨迹，先补齐任务并开启记录。",
      "",
      "评分依据",
      `- ${day.score}/10`,
      `- 今日任务完成 ${day.done}/${day.tasks.length}`,
      `- 应用分布:\\n${day.appText || "暂无应用分布"}`,
      "",
      "亮点",
      day.done ? `1. 已完成 ${day.done} 个今日任务。` : "1. 已建立任务和记录入口。",
      "2. 可以用窗口轨迹辅助复盘。",
      "",
      "阻碍",
      day.tasks.length ? "1. 计划闭环仍需加强。" : "1. 缺少明确今日任务。",
      day.samples.length ? "2. 需要继续观察分心来源。" : "2. 轨迹样本不足。",
      "",
      "改进建议",
      "1. 明早先写一个主线任务和完成信号。",
      "2. 每段学习后补一句产出记录。",
      "3. 至少记录一个完整专注时段后再总结。",
      reason ? `\\n数据边界\\n1. AI 请求未完成：${reason}` : ""
    ].filter(Boolean).join("\\n")
  };
}

async function generateAISummary(db) {
  const apiKey = decryptAPIKey(db.settings.encryptedAPIKey);
  if (!apiKey) return localSummary(db, "API Key 未配置。");

  const day = analyzeDay(db);
  const endpoint = `${String(db.settings.baseURL || "").replace(/\/+$/, "")}/chat/completions`;
  const prompt = `
SCORING_LOCK: ${day.score}/10
TASKS: ${JSON.stringify(day.tasks)}
GOALS: ${JSON.stringify(day.goals)}
APP_DURATIONS:
${day.appText || "暂无"}
TIMELINE:
${day.timelineText || "暂无"}
SCREEN_OCR:
${day.screenText || "暂无"}

Return JSON only:
{
  "executive_summary": "one short overall judgment in the selected language",
  "highlights": ["exactly 2 items in the selected language"],
  "obstacles": ["exactly 2 items in the selected language"],
  "recommendations": ["exactly 3 items in the selected language"],
  "tomorrow_plan": ["exactly 3 items in the selected language"],
  "data_warnings": ["0 to 2 items in the selected language"]
}
`;

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: db.settings.model,
        temperature: 0.1,
        messages: [
          { role: "system", content: `You are Trace Coach's summary sub-agent. Use evidence only. The score is locked; do not change it. Return JSON only. ${languageInstruction(db.settings)}` },
          { role: "user", content: prompt }
        ]
      })
    });

    if (!response.ok) {
      return localSummary(db, (await response.text()).slice(0, 180));
    }

    const payload = await response.json();
    const text = payload.choices?.[0]?.message?.content || "";
    const report = JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
    const lines = [
      "总评",
      report.executive_summary,
      "",
      "评分依据",
      `- ${day.score}/10`,
      `- 今日任务完成 ${day.done}/${day.tasks.length}`,
      `- 记录时长约 ${day.activeMinutes} 分钟`,
      "",
      "亮点",
      ...asList(report.highlights, 2),
      "",
      "阻碍",
      ...asList(report.obstacles, 2),
      "",
      "改进建议",
      ...asList(report.recommendations, 3),
      "",
      "明日计划",
      ...asList(report.tomorrow_plan, 3)
    ];
    const warnings = asList(report.data_warnings || [], 2);
    if (warnings.length) lines.push("", "数据边界", ...warnings);

    return {
      id: uuid(),
      dateKey: day.today,
      generatedAt: new Date().toISOString(),
      score: day.score,
      model: db.settings.model,
      body: lines.join("\\n")
    };
  } catch (error) {
    return localSummary(db, error.message);
  }
}

function asList(values, count) {
  return (values || []).slice(0, count).map((value, index) => `${index + 1}. ${value}`);
}

function planningContext(db) {
  const tasks = (db.tasks || []).map((task) => {
    const journal = (task.journal || []).slice(0, 3).map((entry) => `${entry.createdAt}: ${entry.title || "未命名记录"} - ${entry.body}`).join("；");
    return `- id=${task.id} | 开始:${dayKey(task.startDate || task.createdAt || task.targetDate)} | 完成:${dayKey(task.targetDate)} | [${task.status}] ${task.title} | 项目:${task.project || "学习"} | 预计:${task.estimatedMinutes || 45} 分 | 优先级:${task.priority || "medium"} | 备注:${task.note || ""} | 完成记录:${task.completionNote || ""} | 日记:${journal}`;
  }).join("\n") || "无计划";

  const goals = (db.goals || []).map((goal) => {
    const milestones = (goal.milestones || []).map((item) => `${item.isDone ? "已完成" : "未完成"}-${item.title}`).join("；");
    const logs = (goal.logs || []).slice(0, 5).map((entry) => `${entry.createdAt}: ${entry.title || "未命名记录"} - ${entry.body}`).join("；");
    return `- id=${goal.id} | ${goal.title} | 目的:${goal.purpose || ""} | 衡量:${goal.metric || "完成可验证产出"} | 截止:${dayKey(goal.targetDate)} | 里程碑:${milestones} | 阶段日志:${logs}`;
  }).join("\n") || "无目标";

  const day = analyzeDay(db);
  const activeMessages = activeCoachMessages(db);
  const messages = activeMessages.slice(-16).map((message) => `- ${message.role}: ${String(message.content || "").slice(0, 260)}`).join("\n");
  const memory = db.coachMemory || {};
  const identity = db.coachIdentity?.title?.trim() || "未设置身份";

  return `
TODAY: ${day.today}
IDENTITY: ${identity}
MEMORY:
摘要:${memory.summary || "暂无长期记忆"}
关键事实:${(memory.keyFacts || []).join("；")}

PLANS:
${tasks}

GOALS:
${goals}

ACTIVITY:
记录时长:${day.activeMinutes} 分钟
应用分布:
${day.appText || "暂无"}
窗口轨迹:
${day.timelineText || "暂无"}

RECENT_CONVERSATION:
${messages || "暂无"}
`;
}

function activeCoachMessages(db) {
  const activeId = db.activeCoachConversationId;
  const conversation = (db.coachConversations || []).find((item) => item.id === activeId) || (db.coachConversations || [])[0];
  return conversation?.messages || db.coachMessages || [];
}

function localCoachTurn(db, reason = "") {
  const day = analyzeDay(db);
  return {
    reply: `AI 服务暂时不可用，我先读取本地上下文：计划 ${(db.tasks || []).length} 个，目标 ${(db.goals || []).length} 个，今日记录约 ${day.activeMinutes} 分钟。${reason ? `服务原因：${reason}` : ""}`,
    actions: [],
    memory_update: db.coachMemory?.summary || "",
    key_facts: db.coachMemory?.keyFacts || []
  };
}

function normalizeCoachResponse(text, db) {
  try {
    const jsonText = text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1);
    const parsed = JSON.parse(jsonText);
    return {
      reply: String(parsed.reply || "我已读取当前规划上下文。").slice(0, 1200),
      actions: Array.isArray(parsed.actions) ? parsed.actions.slice(0, 12) : [],
      memory_update: parsed.memory_update || "",
      key_facts: Array.isArray(parsed.key_facts) ? parsed.key_facts.slice(0, 8) : [],
      daily_summary: parsed.daily_summary || null
    };
  } catch (error) {
    return localCoachTurn(db, `教练 JSON 解析失败：${error.message}`);
  }
}

async function runPlanningCoach(db, userInput) {
  const apiKey = decryptAPIKey(db.settings.encryptedAPIKey);
  if (!apiKey) return localCoachTurn(db, "API Key 未配置。");

  const endpoint = `${String(db.settings.baseURL || "").replace(/\/+$/, "")}/chat/completions`;
  const system = `
You are Trace's Coach, not a simple summary tool. You operate with claw-code-style agent boundaries: conversation messages, tool actions, permission boundaries, file operations, memory updates, and context compaction.
Language: ${languageInstruction(db.settings)}

语义：
- 计划 = 短期、明确、可执行的战术动作。
- 目标 = 长期、笼统、战略性的方向，必须体现目的、衡量方式、阶段日志。

可输出工具动作：
add_plan, update_plan, delete_plan, complete_plan, add_plan_log,
add_goal, update_goal, delete_goal, add_goal_log,
read_planning_context, list_coach_files, read_coach_file, write_coach_file.

权限边界：
- 只能操作计划、目标、日志、总结、活动记录和教练文件区。
- 删除前必须在 reply 中明确说明删除对象；无法确定 target_id 时不要删除。
- 不编造活动记录、日志或文件内容。
- 文件操作只限教练文件区。

只返回 JSON:
{
  "reply": "natural language reply in the selected language",
  "actions": [{"type":"add_plan","target_id":"可选","title":"可选","note":"可选","project":"可选","start_date":"yyyy-MM-dd","target_date":"yyyy-MM-dd","date":"yyyy-MM-dd","estimated_minutes":45,"priority":"low|medium|high","purpose":"可选","metric":"可选","days":30,"body":"可选","file_name":"可选.md","content":"可选"}],
  "memory_update": "可选",
  "key_facts": [],
  "daily_summary": {"executive_summary":"可选","highlights":[],"obstacles":[],"recommendations":[],"tomorrow_plan":[],"data_warnings":[]}
}`;

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: db.settings.model,
        temperature: 0.2,
        messages: [
          { role: "system", content: system },
          { role: "user", content: `USER_INPUT:\n${userInput}\n\nCONTEXT:\n${planningContext(db)}` }
        ]
      })
    });

    if (!response.ok) return localCoachTurn(db, (await response.text()).slice(0, 220));
    const payload = await response.json();
    return normalizeCoachResponse(payload.choices?.[0]?.message?.content || "", db);
  } catch (error) {
    return localCoachTurn(db, error.message);
  }
}

function safeCoachFileName(value) {
  const raw = String(value || "coach-note.md").trim();
  const cleaned = raw.replace(/[^a-zA-Z0-9._ -]/g, "-").replace(/^[. ]+|[. ]+$/g, "");
  return cleaned ? (cleaned.includes(".") ? cleaned : `${cleaned}.md`) : "coach-note.md";
}

function safePathSegment(value) {
  const clean = String(value || "未设置身份")
    .replace(/[\\/:*?"<>|]/g, "-")
    .replace(/^[. ]+|[. ]+$/g, "")
    .slice(0, 80);
  return clean || "未设置身份";
}

async function listCoachFiles() {
  try {
    await fs.mkdir(coachFilesFolder(), { recursive: true });
    const names = await fs.readdir(coachFilesFolder());
    const files = [];
    for (const name of names) {
      const filePath = path.join(coachFilesFolder(), name);
      const stat = await fs.stat(filePath);
      if (!stat.isFile()) continue;
      const content = await fs.readFile(filePath, "utf8").catch(() => "");
      files.push({ name, path: filePath, modifiedAt: stat.mtime.toISOString(), preview: content.slice(0, 160) });
    }
    return files.sort((a, b) => String(b.modifiedAt).localeCompare(String(a.modifiedAt)));
  } catch {
    return [];
  }
}

async function readCoachFile(fileName) {
  try {
    const name = safeCoachFileName(fileName);
    const content = await fs.readFile(path.join(coachFilesFolder(), name), "utf8");
    return { ok: true, name, content };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function writeCoachFile(fileName, content) {
  try {
    const name = safeCoachFileName(fileName);
    const text = String(content || "");
    if (!text.trim()) return { ok: false, error: "内容为空" };
    await fs.mkdir(coachFilesFolder(), { recursive: true });
    await fs.writeFile(path.join(coachFilesFolder(), name), text, "utf8");
    return { ok: true, name };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function writeCoachArchive(archive, reason) {
  try {
    const identityTitle = archive?.identityTitle || "未设置身份";
    const folder = coachArchiveFolder(identityTitle);
    await fs.mkdir(folder, { recursive: true });
    const archivedAt = archive?.archivedAt || new Date().toISOString();
    const shortId = String(archive?.id || uuid()).slice(0, 8);
    const fileName = `${dayKey(archivedAt)}-${shortId}.md`;
    const filePath = path.join(folder, fileName);
    const messages = (archive?.messages || []).map((message) => {
      const role = { user: "我", assistant: "教练", tool: "工具", system: "系统" }[message.role] || "教练";
      return `## ${role} · ${dateTimeText(message.createdAt)}\n\n${message.content || ""}`;
    }).join("\n\n");
    const content = `# ${archive?.title || "归档对话"}\n\n身份：${identityTitle}\n归档时间：${dateTimeText(archivedAt)}\n原因：${reason || "每日自动归档"}\n\n## 记忆\n\n${archive?.memorySummary || "暂无记忆摘要"}\n\n${(archive?.keyFacts || []).length ? `关键事实：${archive.keyFacts.join("；")}\n\n` : ""}## 对话\n\n${messages || "暂无对话"}\n`;
    await fs.writeFile(filePath, content, "utf8");
    return { ok: true, path: filePath };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

ipcMain.handle("database:load", async () => {
  const db = await readDatabase();
  return publicDatabase(db);
});

ipcMain.handle("database:save", async (_event, db) => {
  const previous = await readDatabase();
  const settings = { ...DEFAULT_SETTINGS, ...(db.settings || {}) };
  settings.language = normalizeLanguage(settings.language);
  if (settings.visualTheme === "boulevard" || settings.visualTheme === "system") settings.visualTheme = "day";
  if (settings.visualTheme === "starlight") settings.visualTheme = "night";
  settings.customSidebarColor = {
    ...DEFAULT_SETTINGS.customSidebarColor,
    ...(settings.customSidebarColor || {})
  };
  const next = {
    ...DEFAULT_DB,
    ...db,
    settings
  };
  if (db.apiKeyDraft !== undefined) {
    next.settings.encryptedAPIKey = encryptAPIKey(db.apiKeyDraft);
    delete next.apiKeyDraft;
  } else {
    next.settings.encryptedAPIKey = previous.settings.encryptedAPIKey || "";
  }
  delete next.apiKeyConfigured;
  delete next.apiKeyDraft;
  const written = await writeDatabase(next);
  return publicDatabase(written);
});

ipcMain.handle("activity:sample", async (_event, settings) => sampleActiveWindow({ ...DEFAULT_SETTINGS, ...(settings || {}) }));
ipcMain.handle("summary:generate", async (_event, db) => {
  const stored = await readDatabase();
  const input = {
    ...stored,
    ...db,
    settings: {
      ...stored.settings,
      ...(db.settings || {}),
      encryptedAPIKey: stored.settings.encryptedAPIKey || ""
    }
  };
  return generateAISummary(input);
});
ipcMain.handle("coach:turn", async (_event, db, userInput) => {
  const stored = await readDatabase();
  const input = {
    ...stored,
    ...db,
    settings: {
      ...stored.settings,
      ...(db.settings || {}),
      encryptedAPIKey: stored.settings.encryptedAPIKey || ""
    }
  };
  return runPlanningCoach(input, userInput);
});
ipcMain.handle("coach:file:list", async () => listCoachFiles());
ipcMain.handle("coach:file:read", async (_event, fileName) => readCoachFile(fileName));
ipcMain.handle("coach:file:write", async (_event, fileName, content) => writeCoachFile(fileName, content));
ipcMain.handle("coach:archive:write", async (_event, archive, reason) => writeCoachArchive(archive, reason));

app.whenReady().then(() => {
  app.setName("Trace");
  app.setPath("userData", path.join(app.getPath("appData"), "StudyAI Recorder"));
  createWindow();
});
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
