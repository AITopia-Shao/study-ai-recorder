const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("studyAI", {
  loadDatabase: () => ipcRenderer.invoke("database:load"),
  saveDatabase: (database) => ipcRenderer.invoke("database:save", database),
  sampleActiveWindow: (settings) => ipcRenderer.invoke("activity:sample", settings),
  generateSummary: (database) => ipcRenderer.invoke("summary:generate", database),
  runCoach: (database, message) => ipcRenderer.invoke("coach:turn", database, message),
  listCoachFiles: () => ipcRenderer.invoke("coach:file:list"),
  readCoachFile: (fileName) => ipcRenderer.invoke("coach:file:read", fileName),
  writeCoachFile: (fileName, content) => ipcRenderer.invoke("coach:file:write", fileName, content),
  writeCoachArchive: (archive, reason) => ipcRenderer.invoke("coach:archive:write", archive, reason)
});
