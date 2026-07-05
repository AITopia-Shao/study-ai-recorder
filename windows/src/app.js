let db;
let timer;

const byId = (id) => document.getElementById(id);
const today = () => new Date().toISOString().slice(0, 10);

async function load() {
  db = await window.studyAI.loadDatabase();
  db.tasks ||= [];
  db.goals ||= [];
  db.samples ||= [];
  db.summaries ||= [];
  db.settings ||= {};
  db.selectedMode ||= "plan";
  render();
}

async function save(extra = {}) {
  db = await window.studyAI.saveDatabase({ ...db, ...extra });
  render();
}

function applyTheme() {
  document.body.classList.toggle("starlight", db.settings.visualTheme === "starlight");
}

function todaysTasks(mode = null) {
  return db.tasks.filter((task) => String(task.targetDate || "").slice(0, 10) === today() && (!mode || task.mode === mode));
}

function todaysSamples() {
  return db.samples.filter((sample) => String(sample.timestamp || "").slice(0, 10) === today());
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
  return db.summaries.filter((summary) => summary.dateKey === today()).at(-1);
}

function render() {
  applyTheme();
  byId("todayDate").textContent = new Date().toLocaleDateString();
  byId("modePicker").value = db.selectedMode || "plan";
  const tasks = todaysTasks();
  byId("metricTasks").textContent = tasks.length;
  byId("metricDone").textContent = tasks.filter((task) => task.status === "done").length;
  byId("metricMinutes").textContent = `${totalMinutes()} 分`;
  byId("metricScore").textContent = latestSummary()?.score ?? "-";
  byId("taskListTitle").textContent = db.selectedMode === "plan" ? "今日计划" : "目标动作";
  renderTasks("taskList", todaysTasks(db.selectedMode), "暂无任务");
  renderTasks("planTasks", todaysTasks("plan"), "暂无计划任务");
  renderGoals();
  renderUsage();
  renderTimeline();
  renderSettings();
  const latest = db.samples.at(-1);
  byId("latestApp").textContent = latest?.appName || "等待采样";
  byId("latestSample").textContent = latest ? JSON.stringify(latest, null, 2) : "暂无采样";
  byId("summaryBody").textContent = latestSummary()?.body || "还没有总结。";
}

function renderSettings() {
  byId("baseURL").value = db.settings.baseURL || "https://api.openai.com/v1";
  byId("model").value = db.settings.model || "gpt-4o-mini";
  byId("theme").value = db.settings.visualTheme || "boulevard";
  byId("sampleInterval").value = String(db.settings.sampleInterval || 30);
  byId("includeWindowTitles").checked = db.settings.includeWindowTitles !== false;
  byId("captureScreenshots").checked = Boolean(db.settings.captureScreenshots);
  byId("screenshotInterval").value = db.settings.screenshotIntervalMinutes || 15;
}

function renderTasks(containerId, tasks, emptyText) {
  const container = byId(containerId);
  container.innerHTML = "";
  if (!tasks.length) {
    container.innerHTML = `<p>${emptyText}</p>`;
    return;
  }
  for (const task of tasks) {
    const node = document.createElement("div");
    node.className = `item ${task.status === "done" ? "done" : ""}`;
    node.innerHTML = `
      <div class="item-title">
        <strong>${escapeHTML(task.title)}</strong>
        <button>${task.status === "done" ? "撤销" : "完成"}</button>
      </div>
      <small>${escapeHTML(task.project || "学习")} · ${task.estimatedMinutes || 45} 分 · ${priorityText(task.priority)}</small>
      ${task.note ? `<p>${escapeHTML(task.note)}</p>` : ""}
    `;
    node.querySelector("button").addEventListener("click", async () => {
      task.status = task.status === "done" ? "planned" : "done";
      task.completedAt = task.status === "done" ? new Date().toISOString() : null;
      await save();
    });
    container.appendChild(node);
  }
}

function renderGoals() {
  const container = byId("goalList");
  container.innerHTML = "";
  if (!db.goals.length) {
    container.innerHTML = "<p>暂无目标</p>";
    return;
  }
  for (const goal of db.goals) {
    const node = document.createElement("div");
    node.className = "item";
    node.innerHTML = `
      <div class="item-title"><strong>${escapeHTML(goal.title)}</strong><span>${Math.round((goal.progress || 0) * 100)}%</span></div>
      <p>${escapeHTML(goal.purpose || goal.metric || "")}</p>
      <small>衡量：${escapeHTML(goal.metric || "完成可验证产出")} · 截止：${new Date(goal.targetDate).toLocaleDateString()}</small>
    `;
    container.appendChild(node);
  }
}

function renderUsage() {
  const container = byId("appUsage");
  container.innerHTML = "";
  const items = durations();
  if (!items.length) {
    container.innerHTML = "<p>开始监控后显示</p>";
    return;
  }
  for (const item of items.slice(0, 8)) {
    const node = document.createElement("div");
    node.className = "item";
    node.innerHTML = `<div class="item-title"><strong>${escapeHTML(item.appName)}</strong><span>${item.minutes} 分</span></div>`;
    container.appendChild(node);
  }
}

function renderTimeline() {
  const container = byId("timeline");
  container.innerHTML = "";
  const samples = todaysSamples().slice(-12).reverse();
  if (!samples.length) {
    container.innerHTML = "<p>暂无轨迹</p>";
    return;
  }
  for (const sample of samples) {
    const node = document.createElement("div");
    node.className = "item";
    const time = new Date(sample.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    node.innerHTML = `<strong>${time} ${escapeHTML(sample.appName)}</strong><br><small>${escapeHTML(sample.windowTitle || "")}</small>`;
    container.appendChild(node);
  }
}

function priorityText(priority) {
  return { low: "低", medium: "中", high: "高" }[priority] || "中";
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

async function sampleNow() {
  const sample = await window.studyAI.sampleActiveWindow(db.settings);
  db.samples.push(sample);
  trimSamples();
  await save();
}

function trimSamples() {
  const limit = Math.max(200, Number(db.settings.maxSamplesPerDay || 2400));
  const grouped = new Map();
  for (const sample of db.samples) {
    const key = String(sample.timestamp || "").slice(0, 10);
    grouped.set(key, [...(grouped.get(key) || []), sample]);
  }
  db.samples = [...grouped.values()].flatMap((samples) => samples.slice(-limit));
}

function setRecording(active) {
  byId("recordDot").classList.toggle("active", active);
  byId("recordState").textContent = active ? "正在记录" : "记录暂停";
  byId("toggleRecord").textContent = active ? "暂停" : "开始";
}

document.querySelectorAll(".nav").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".nav").forEach((item) => item.classList.remove("active"));
    document.querySelectorAll(".view").forEach((view) => view.classList.remove("active"));
    button.classList.add("active");
    byId(button.dataset.view).classList.add("active");
  });
});

byId("modePicker").addEventListener("change", async (event) => {
  db.selectedMode = event.target.value;
  await save();
});

byId("toggleRecord").addEventListener("click", async () => {
  if (timer) {
    clearInterval(timer);
    timer = null;
    setRecording(false);
    return;
  }
  await sampleNow();
  timer = setInterval(sampleNow, Math.max(10, Number(db.settings.sampleInterval || 30)) * 1000);
  setRecording(true);
});

byId("sampleNow").addEventListener("click", sampleNow);

byId("addTask").addEventListener("click", async () => {
  const title = byId("taskTitle").value.trim();
  if (!title) return;
  db.tasks.unshift({
    id: crypto.randomUUID(),
    title,
    note: byId("taskNote").value.trim(),
    mode: db.selectedMode || "plan",
    project: byId("taskProject").value.trim() || "学习",
    targetDate: new Date().toISOString(),
    estimatedMinutes: Math.max(5, Number(byId("taskMinutes").value || 45)),
    status: "planned",
    priority: byId("taskPriority").value,
    createdAt: new Date().toISOString(),
    completedAt: null
  });
  byId("taskTitle").value = "";
  byId("taskNote").value = "";
  await save();
});

byId("addGoal").addEventListener("click", async () => {
  const title = byId("goalTitle").value.trim();
  if (!title) return;
  const days = Math.max(1, Number(byId("goalDays").value || 14));
  const target = new Date();
  target.setDate(target.getDate() + days);
  db.goals.unshift({
    id: crypto.randomUUID(),
    title,
    purpose: byId("goalPurpose").value.trim(),
    metric: byId("goalMetric").value.trim() || "完成可验证产出",
    targetDate: target.toISOString(),
    progress: 0,
    milestones: [
      { id: crypto.randomUUID(), title: "明确下一步动作", isDone: false },
      { id: crypto.randomUUID(), title: "完成一次阶段复盘", isDone: false },
      { id: crypto.randomUUID(), title: "产出可展示成果", isDone: false }
    ],
    createdAt: new Date().toISOString()
  });
  byId("goalTitle").value = "";
  byId("goalPurpose").value = "";
  byId("goalMetric").value = "";
  await save();
});

async function generateSummary() {
  const summary = await window.studyAI.generateSummary(db);
  db.summaries = db.summaries.filter((item) => item.dateKey !== summary.dateKey);
  db.summaries.push(summary);
  await save();
}

byId("quickSummary").addEventListener("click", generateSummary);
byId("generateSummary").addEventListener("click", generateSummary);

byId("saveSettings").addEventListener("click", async () => {
  db.settings.baseURL = byId("baseURL").value.trim();
  db.settings.model = byId("model").value.trim();
  db.settings.visualTheme = byId("theme").value;
  db.settings.sampleInterval = Number(byId("sampleInterval").value || 30);
  db.settings.includeWindowTitles = byId("includeWindowTitles").checked;
  db.settings.captureScreenshots = byId("captureScreenshots").checked;
  db.settings.screenshotIntervalMinutes = Math.max(5, Number(byId("screenshotInterval").value || 15));
  const draft = byId("apiKey").value.trim();
  await save(draft ? { apiKeyDraft: draft } : {});
  byId("apiKey").value = "";
  byId("settingsStatus").textContent = draft ? "设置已保存，API Key 已加密写入本机。" : "设置已保存。";
});

load();
