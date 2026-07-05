const { app, BrowserWindow, ipcMain, safeStorage } = require("electron");
const fs = require("fs/promises");
const path = require("path");
const { execFile } = require("child_process");
const { randomUUID } = require("crypto");

const DEFAULT_SETTINGS = {
  baseURL: "https://api.openai.com/v1",
  model: "gpt-4o-mini",
  visualTheme: "boulevard",
  sampleInterval: 30,
  includeWindowTitles: true,
  captureScreenshots: false,
  screenshotIntervalMinutes: 15,
  maxSamplesPerDay: 2400,
  encryptedAPIKey: ""
};

const DEFAULT_DB = {
  tasks: [],
  goals: [],
  samples: [],
  summaries: [],
  settings: DEFAULT_SETTINGS
};

let lastScreenshotAt = 0;

function databasePath() {
  return path.join(app.getPath("userData"), "database.json");
}

function snapshotFolder(dateKey) {
  return path.join(app.getPath("userData"), "Snapshots", dateKey);
}

async function readDatabase() {
  try {
    const raw = await fs.readFile(databasePath(), "utf8");
    const parsed = JSON.parse(raw);
    return {
      ...DEFAULT_DB,
      ...parsed,
      settings: { ...DEFAULT_SETTINGS, ...(parsed.settings || {}) }
    };
  } catch {
    return JSON.parse(JSON.stringify(DEFAULT_DB));
  }
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
    title: "StudyAI Recorder",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  window.loadFile(path.join(__dirname, "src", "index.html"));
}

function dayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
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

function analyzeDay(db) {
  const today = dayKey();
  const tasks = db.tasks.filter((task) => String(task.targetDate || "").slice(0, 10) === today);
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
  "executive_summary": "一句中文总评，60字以内",
  "highlights": ["恰好2条"],
  "obstacles": ["恰好2条"],
  "recommendations": ["恰好3条"],
  "tomorrow_plan": ["恰好3条"],
  "data_warnings": ["0到2条"]
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
          { role: "system", content: "你是 StudyAI Learning Agent。只使用证据，评分已锁定，不要改分。只返回 JSON。" },
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

ipcMain.handle("database:load", async () => {
  const db = await readDatabase();
  return publicDatabase(db);
});

ipcMain.handle("database:save", async (_event, db) => {
  const previous = await readDatabase();
  const next = {
    ...DEFAULT_DB,
    ...db,
    settings: { ...DEFAULT_SETTINGS, ...(db.settings || {}) }
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

app.whenReady().then(createWindow);
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
