// Feynos Music for Linux: Electron main process.
// Handles the window, opening links, and the network side of jams
// (TCP + Bonjour "_feynosjam._tcp", compatible with the Android and Apple TV apps).
const { app, BrowserWindow, ipcMain, shell, Menu, powerSaveBlocker } = require('electron');
const path = require('path');
const net = require('net');
const crypto = require('crypto');

let Bonjour = null;
try {
  ({ Bonjour } = require('bonjour-service'));
} catch (e) {
  Bonjour = null;
}

let win = null;

function createWindow() {
  win = new BrowserWindow({
    width: 1320,
    height: 860,
    minWidth: 900,
    minHeight: 600,
    backgroundColor: '#0e0e12',
    title: 'Feynos Music',
    icon: path.join(__dirname, 'build', 'icon.png'),
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      // The app talks to your own Navidrome server and a few public music APIs
      // (ListenBrainz, MusicBrainz, Deezer, iTunes), many of which don't send CORS headers.
      webSecurity: false,
      backgroundThrottling: false,
    },
  });
  Menu.setApplicationMenu(null);
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
  win.on('closed', () => {
    win = null;
  });
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });
  app.whenReady().then(createWindow);
  app.on('window-all-closed', () => {
    stopAll();
    app.quit();
  });
}

ipcMain.on('app:md5', (e, s) => {
  e.returnValue = crypto.createHash('md5').update(String(s), 'utf8').digest('hex');
});
ipcMain.handle('app:version', () => app.getVersion());

// Keeps the screen from going to sleep while the app is open (Settings can turn this off).
let awakeId = null;
ipcMain.handle('app:keepAwake', (e, on) => {
  if (on && awakeId === null) awakeId = powerSaveBlocker.start('prevent-display-sleep');
  if (!on && awakeId !== null) {
    powerSaveBlocker.stop(awakeId);
    awakeId = null;
  }
  return awakeId !== null;
});
ipcMain.handle('app:open', (_e, url) => shell.openExternal(url));

// ---------------- Jam networking ----------------

const jam = { server: null, peers: new Map(), next: 1, bonjour: null, published: null, browser: null, services: new Map() };

function emit(ev) {
  if (win && !win.isDestroyed()) win.webContents.send('jam:event', ev);
}

function bonjour() {
  if (!Bonjour) throw new Error('Bonjour is not available');
  if (!jam.bonjour) jam.bonjour = new Bonjour();
  return jam.bonjour;
}

function attach(id, socket, announce) {
  socket.setNoDelay(true);
  socket.setEncoding('utf8');
  socket.setKeepAlive(true, 10000);
  let buf = '';
  jam.peers.set(id, socket);
  if (announce) emit({ type: 'connected', id });
  socket.on('data', (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i);
      buf = buf.slice(i + 1);
      if (line.trim()) emit({ type: 'message', id, line });
    }
  });
  const done = () => {
    if (jam.peers.get(id) === socket) {
      jam.peers.delete(id);
      emit({ type: 'disconnected', id });
    }
  };
  socket.on('close', done);
  socket.on('error', () => socket.destroy());
}

function stopHost() {
  try { if (jam.published) jam.published.stop(); } catch (e) { /* ignore */ }
  jam.published = null;
  try { if (jam.server) jam.server.close(); } catch (e) { /* ignore */ }
  jam.server = null;
}

function stopBrowse() {
  try { if (jam.browser) jam.browser.stop(); } catch (e) { /* ignore */ }
  jam.browser = null;
}

function stopAll() {
  stopHost();
  stopBrowse();
  for (const s of jam.peers.values()) {
    try { s.destroy(); } catch (e) { /* ignore */ }
  }
  jam.peers.clear();
  jam.services.clear();
}

ipcMain.handle('jam:host', (_e, name) => new Promise((resolve) => {
  stopHost();
  const server = net.createServer((sock) => attach('wifi:' + (jam.next++), sock, true));
  server.on('error', (e) => resolve({ ok: false, error: e.message }));
  server.listen(0, () => {
    jam.server = server;
    const port = server.address().port;
    try {
      jam.published = bonjour().publish({ name, type: 'feynosjam', protocol: 'tcp', port });
    } catch (e) {
      resolve({ ok: false, error: 'Wi-Fi discovery unavailable: ' + e.message });
      return;
    }
    resolve({ ok: true, port });
  });
}));

ipcMain.handle('jam:stopHost', () => {
  stopHost();
  return true;
});

ipcMain.handle('jam:browse', () => {
  stopBrowse();
  try {
    jam.browser = bonjour().find({ type: 'feynosjam', protocol: 'tcp' });
  } catch (e) {
    return { ok: false, error: e.message };
  }
  jam.browser.on('up', (s) => {
    const id = 'wifi:' + s.name;
    const addresses = s.addresses || [];
    const host = addresses.find((a) => a.includes('.')) || (s.referer && s.referer.address) || s.host;
    jam.services.set(id, { host, port: s.port });
    emit({ type: 'found', id, name: s.name });
  });
  jam.browser.on('down', (s) => {
    const id = 'wifi:' + s.name;
    jam.services.delete(id);
    emit({ type: 'lost', id });
  });
  return { ok: true };
});

ipcMain.handle('jam:stopBrowse', () => {
  stopBrowse();
  return true;
});

ipcMain.handle('jam:connect', (_e, id) => new Promise((resolve) => {
  const s = jam.services.get(id);
  if (!s) {
    resolve({ ok: false, error: 'That jam is no longer available' });
    return;
  }
  let settled = false;
  const finish = (r) => {
    if (!settled) {
      settled = true;
      resolve(r);
    }
  };
  const sock = net.createConnection({ host: s.host, port: s.port });
  sock.setTimeout(8000);
  sock.once('connect', () => {
    sock.setTimeout(0);
    attach(id, sock, false);
    finish({ ok: true });
  });
  sock.once('timeout', () => {
    sock.destroy();
    finish({ ok: false, error: 'Timed out connecting to the jam' });
  });
  sock.once('error', (e) => finish({ ok: false, error: e.message }));
}));

ipcMain.on('jam:send', (_e, id, line) => {
  const s = jam.peers.get(id);
  if (s && !s.destroyed) s.write(line + '\n');
});

ipcMain.handle('jam:disconnect', (_e, id) => {
  const s = jam.peers.get(id);
  if (s) s.destroy();
  return true;
});

ipcMain.handle('jam:stopAll', () => {
  stopAll();
  return true;
});
