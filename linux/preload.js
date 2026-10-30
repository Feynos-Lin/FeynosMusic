// Bridges the page to the main process (hashing, links, jam networking).
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('native', {
  md5: (s) => ipcRenderer.sendSync('app:md5', s),
  version: () => ipcRenderer.invoke('app:version'),
  keepAwake: (on) => ipcRenderer.invoke('app:keepAwake', !!on),
  openExternal: (url) => ipcRenderer.invoke('app:open', url),
});

contextBridge.exposeInMainWorld('jamNet', {
  host: (name) => ipcRenderer.invoke('jam:host', name),
  stopHost: () => ipcRenderer.invoke('jam:stopHost'),
  browse: () => ipcRenderer.invoke('jam:browse'),
  stopBrowse: () => ipcRenderer.invoke('jam:stopBrowse'),
  connect: (id) => ipcRenderer.invoke('jam:connect', id),
  send: (id, line) => ipcRenderer.send('jam:send', id, line),
  disconnect: (id) => ipcRenderer.invoke('jam:disconnect', id),
  stopAll: () => ipcRenderer.invoke('jam:stopAll'),
  onEvent: (cb) => ipcRenderer.on('jam:event', (_e, ev) => cb(ev)),
});
