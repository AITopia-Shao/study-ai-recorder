const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("studyAI", {
  loadDatabase: () => ipcRenderer.invoke("database:load"),
  saveDatabase: (database) => ipcRenderer.invoke("database:save", database),
  sampleActiveWindow: () => ipcRenderer.invoke("activity:sample"),
  generateSummary: (database) => ipcRenderer.invoke("summary:generate", database)
});
