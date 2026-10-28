// Feynos Music for Linux — Jam over Wi-Fi (same messages as the Android and Apple TV apps).
// Host: this computer plays; phones on the same network join and control it.
// Guest: join a jam hosted by an Apple TV, a phone or another computer.
'use strict';

const Jam = {
  role: 'none', // none | host | guest
  searching: false,
  found: new Map(), // id -> name
  connectingTo: null,
  hostId: null,
  hostName: '',
  members: [],
  addedBy: {}, // songId -> name
  error: null,
  // host side
  peers: new Map(), // id -> {name, hello}
  credits: new Map(), // songId -> peer id (or null for us)
  cursors: new Map(),
  lastSig: '',
  lastSent: 0,
  timer: null,

  init() {
    window.jamNet.onEvent((ev) => this.onEvent(ev));
    Player.on(() => this.broadcast(false));
  },

  isHost() {
    return this.role === 'host';
  },
  isGuest() {
    return this.role === 'guest';
  },
  myName() {
    return Settings.username || 'Linux';
  },
  people() {
    return this.role === 'host' ? [this.myName(), ...[...this.peers.values()].filter((p) => p.hello).map((p) => p.name)] : this.members;
  },

  send(id, obj) {
    window.jamNet.send(id, JSON.stringify(obj));
  },

  // ---------------- Host ----------------

  async start() {
    if (this.role !== 'none') return;
    const r = await window.jamNet.host(`${this.myName()}'s jam`);
    if (!r || !r.ok) {
      this.error = `Couldn't start the jam: ${(r && r.error) || 'unknown error'}`;
      UI.refresh();
      return;
    }
    Object.assign(this, { role: 'host', error: null, addedBy: {}, lastSig: '' });
    this.peers.clear();
    this.credits.clear();
    this.cursors.clear();
    this.timer = setInterval(() => this.broadcast(Date.now() - this.lastSent > 4000), 1000);
    toast('Jam started. Phones on this Wi-Fi can join from their Jam screen.');
    UI.refresh();
  },

  noteLocal(songs) {
    this.note(songs, null, this.myName());
  },
  note(songs, peer, name) {
    if (this.role !== 'host') return;
    for (const s of songs) {
      this.credits.set(s.id, peer);
      this.addedBy[s.id] = name;
    }
  },
  creditFor(songId) {
    if (this.role !== 'host') return null;
    const p = this.credits.get(songId);
    return p && this.peers.get(p) && this.peers.get(p).hello ? p : null;
  },
  sendListen(peer, song, at) {
    this.send(peer, { t: 'listen', song, at });
  },
  sendNowPlaying(peer, song) {
    this.send(peer, { t: 'nowPlaying', song });
  },

  hostMessage(id, m) {
    const peer = this.peers.get(id) || { name: 'Guest', hello: false };
    this.peers.set(id, peer);
    if (m.t === 'hello') {
      const isNew = !peer.hello;
      peer.name = m.name || 'Guest';
      peer.hello = true;
      if (isNew) toast(`${peer.name} joined the jam`);
      this.broadcast(true);
      UI.refresh();
      return;
    }
    if (m.t !== 'cmd') return;
    const songs = Array.isArray(m.songs) ? m.songs : [];
    const a = m.a | 0, b = m.b | 0;
    switch (m.op) {
      case 'toggle': Player.toggle(); break;
      case 'next': Player.next(); break;
      case 'previous': Player.previous(); break;
      case 'seek': Player.seek((m.ms || 0) / 1000); break;
      case 'skipTo': Player.skipTo(a); break;
      case 'remove': Player.removeAt(a); break;
      case 'move': Player.move(a, b); break;
      case 'shuffle': Player.toggleShuffle(); break;
      case 'repeat': Player.cycleRepeat(); break;
      case 'clear': Player.clearUpNext(); break;
      case 'play':
        this.note(songs, id, peer.name);
        this.cursors.set(id, Player.insert(songs, null, true));
        break;
      case 'playNext':
        this.note(songs, id, peer.name);
        this.cursors.set(id, Player.insert(songs, null, false));
        break;
      case 'more':
        this.note(songs, id, peer.name);
        this.cursors.set(id, Player.insert(songs, this.cursors.get(id) ?? null, false));
        break;
      case 'add':
        this.note(songs, id, peer.name);
        Player.insert(songs, Number.MAX_SAFE_INTEGER, false);
        break;
      default:
        break;
    }
    setTimeout(() => this.broadcast(true), 300);
  },

  broadcast(force) {
    if (this.role !== 'host') return;
    const ready = [...this.peers.entries()].filter(([, p]) => p.hello).map(([id]) => id);
    if (!ready.length) return;
    const next = Player.upNext().slice(0, 40);
    const cur = Player.current();
    const sig = [cur && cur.id, Player.isPlaying(), Player.shuffle, Player.repeat, ready.length, Object.keys(this.addedBy).length, ...next.map((n) => n.i + n.song.id)].join('|');
    if (!force && sig === this.lastSig) return;
    this.lastSig = sig;
    this.lastSent = Date.now();
    const ids = new Set(next.map((n) => n.song.id));
    if (cur) ids.add(cur.id);
    const by = {};
    for (const id of ids) if (this.addedBy[id]) by[id] = this.addedBy[id];
    const msg = {
      t: 'state',
      host: this.myName(),
      playing: Player.isPlaying(),
      pos: Math.round(Player.position() * 1000),
      dur: Math.round(Player.duration() * 1000),
      shuffle: Player.shuffle,
      repeat: Player.repeat === 'one' ? 1 : Player.repeat === 'all' ? 2 : 0, // same numbers as Android
      next: next.map((n) => ({ i: n.i, s: n.song })),
      members: this.people(),
      by,
    };
    if (cur) msg.song = cur;
    for (const id of ready) this.send(id, msg);
  },

  // ---------------- Guest ----------------

  async search() {
    if (this.role !== 'none') return;
    this.found.clear();
    this.searching = true;
    this.error = null;
    const r = await window.jamNet.browse();
    if (!r || !r.ok) this.error = `Couldn't search: ${(r && r.error) || 'unknown error'}`;
    UI.refresh();
  },

  async stopSearch() {
    this.searching = false;
    await window.jamNet.stopBrowse();
    UI.refresh();
  },

  async join(id) {
    this.connectingTo = id;
    this.error = null;
    UI.refresh();
    const r = await window.jamNet.connect(id);
    this.connectingTo = null;
    if (!r || !r.ok) {
      this.error = `Couldn't join: ${(r && r.error) || 'unknown error'}`;
      UI.refresh();
      return;
    }
    Object.assign(this, { role: 'guest', hostId: id, hostName: (this.found.get(id) || '').replace(/'s jam$/, ''), searching: false });
    window.jamNet.stopBrowse();
    this.send(id, { t: 'hello', name: this.myName() });
    toast('Joined the jam');
    UI.refresh();
  },

  async reconnect(attempt) {
    if (this.role !== 'guest') return;
    this.error = `Connection dropped. Reconnecting… (try ${attempt} of 6)`;
    UI.refresh();
    const r = await window.jamNet.connect(this.hostId);
    if (this.role !== 'guest') return;
    if (r && r.ok) {
      this.error = null;
      this.send(this.hostId, { t: 'hello', name: this.myName() });
      UI.refresh();
    } else if (attempt < 6) {
      setTimeout(() => this.reconnect(attempt + 1), 3000);
    } else {
      this.end();
      toast('Lost connection to the jam');
    }
  },

  /** Guest: sends a control command to the host. Long song lists go in chunks of 40. */
  command(op, opts = {}) {
    if (this.role !== 'guest' || !this.hostId) return;
    const base = { t: 'cmd', op };
    if (opts.a != null) base.a = opts.a;
    if (opts.b != null) base.b = opts.b;
    if (opts.ms != null) base.ms = opts.ms;
    const songs = opts.songs || [];
    if (!songs.length) {
      this.send(this.hostId, base);
      return;
    }
    for (let i = 0; i < songs.length; i += 40) {
      const chunkOp = i === 0 || op === 'add' ? op : 'more';
      this.send(this.hostId, { ...base, op: chunkOp, songs: songs.slice(i, i + 40) });
    }
    if (op === 'add') toast('Added to the jam queue');
    else if (op === 'playNext') toast('Playing next in the jam');
  },

  guestMessage(m) {
    switch (m.t) {
      case 'state':
        Player.setRemote({
          song: m.song || null,
          playing: !!m.playing,
          pos: m.pos || 0,
          dur: m.dur || 0,
          shuffle: !!m.shuffle,
          repeat: m.repeat === 1 ? 'one' : m.repeat === 2 ? 'all' : 'off',
          next: Array.isArray(m.next) ? m.next : [],
          at: Date.now(),
        });
        this.members = Array.isArray(m.members) ? m.members : [];
        this.addedBy = m.by || {};
        if (m.host) this.hostName = m.host;
        break;
      case 'listen':
        if (m.song) recordListen(m.song, m.at || Date.now());
        break;
      case 'nowPlaying':
        if (m.song) sendNowPlaying(m.song);
        break;
      case 'end':
        this.end();
        toast('The jam has ended');
        break;
      default:
        break;
    }
  },

  // ---------------- Both ----------------

  onEvent(ev) {
    switch (ev.type) {
      case 'found':
        this.found.set(ev.id, ev.name);
        UI.refresh();
        break;
      case 'lost':
        this.found.delete(ev.id);
        UI.refresh();
        break;
      case 'connected':
        if (this.role === 'host') this.peers.set(ev.id, { name: 'Guest', hello: false });
        break;
      case 'message': {
        let m;
        try {
          m = JSON.parse(ev.line);
        } catch (e) {
          return;
        }
        if (this.role === 'host') this.hostMessage(ev.id, m);
        else if (this.role === 'guest' && ev.id === this.hostId) this.guestMessage(m);
        break;
      }
      case 'disconnected':
        if (this.role === 'host') {
          const p = this.peers.get(ev.id);
          this.peers.delete(ev.id);
          this.cursors.delete(ev.id);
          if (p && p.hello) toast(`${p.name} left the jam`);
          UI.refresh();
        } else if (this.role === 'guest' && ev.id === this.hostId) {
          this.reconnect(1);
        }
        break;
      default:
        break;
    }
  },

  /** Host: ends the jam for everyone. Guest: leaves it. */
  async end() {
    if (this.role === 'host') {
      for (const [id, p] of this.peers) if (p.hello) this.send(id, { t: 'end' });
      await sleep(300);
    }
    const wasGuest = this.role === 'guest';
    clearInterval(this.timer);
    this.timer = null;
    this.role = 'none';
    await window.jamNet.stopAll();
    Object.assign(this, { hostId: null, hostName: '', members: [], addedBy: {}, searching: false, connectingTo: null });
    this.peers.clear();
    this.found.clear();
    this.credits.clear();
    if (wasGuest) Player.clearRemote();
    UI.refresh();
  },
};
