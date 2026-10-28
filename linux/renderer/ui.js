// Feynos Music for Linux — interface: navigation, screens, player bar and Now Playing.
'use strict';

const svg = (d) => `<svg viewBox="0 0 24 24" fill="currentColor"><path d="${d}"/></svg>`;
const ICON = {
  home: svg('M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z'),
  search: svg('M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z'),
  sparkles: svg('M19 9l1.25-2.75L23 5l-2.75-1.25L19 1l-1.25 2.75L15 5l2.75 1.25L19 9zm-7.5.5L9 4 6.5 9.5 1 12l5.5 2.5L9 20l2.5-5.5L17 12l-5.5-2.5zM19 15l-1.25 2.75L15 19l2.75 1.25L19 23l1.25-2.75L23 19l-2.75-1.25L19 15z'),
  library: svg('M20 2H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 5h-3v5.5a2.5 2.5 0 0 1-5 0 2.5 2.5 0 0 1 2.5-2.5c.57 0 1.08.19 1.5.51V5h4v2zM4 6H2v14c0 1.1.9 2 2 2h14v-2H4V6z'),
  heart: svg('M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55l-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z'),
  heartFill: svg('M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z'),
  history: svg('M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z'),
  chart: svg('M5 9.2h3V19H5zM10.6 5h2.8v14h-2.8zm5.6 8H19v6h-2.8z'),
  jam: svg('M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z'),
  settings: svg('M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.488.488 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.484.484 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z'),
  play: svg('M8 5v14l11-7z'),
  pause: svg('M6 19h4V5H6v14zm8-14v14h4V5h-4z'),
  next: svg('M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z'),
  prev: svg('M6 6h2v12H6zm3.5 6l8.5 6V6z'),
  shuffle: svg('M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z'),
  repeat: svg('M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z'),
  repeat1: svg('M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4zm-4-2V9h-1l-2 1v1h1.5v4H13z'),
  more: svg('M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z'),
  back: svg('M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z'),
  lyrics: svg('M6 17h3l2-4V7H5v6h3zm8 0h3l2-4V7h-6v6h3z'),
  queue: svg('M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z'),
  volume: svg('M3 9v6h4l5 5V4L7 9H3zm13.5 3A4.5 4.5 0 0 0 14 7.97v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'),
  close: svg('M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z'),
  down: svg('M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z'),
  radio: svg('M7.76 16.24C6.67 15.16 6 13.66 6 12s.67-3.16 1.76-4.24l1.42 1.42C8.45 9.9 8 10.9 8 12c0 1.1.45 2.1 1.17 2.83l-1.41 1.41zm8.48 0C17.33 15.16 18 13.66 18 12s-.67-3.16-1.76-4.24l-1.42 1.42C15.55 9.9 16 10.9 16 12c0 1.1-.45 2.1-1.17 2.83l1.41 1.41zM12 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm8 2c0 2.21-.9 4.21-2.35 5.65l1.42 1.42C20.88 17.26 22 14.76 22 12s-1.12-5.26-2.93-7.07l-1.42 1.42A7.94 7.94 0 0 1 20 12zM6.35 6.35L4.93 4.93C3.12 6.74 2 9.24 2 12s1.12 5.26 2.93 7.07l1.42-1.42C4.9 16.21 4 14.21 4 12s.9-4.21 2.35-5.65z'),
  plus: svg('M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z'),
  image: svg('M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z'),
  note: svg('M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z'),
  trash: svg('M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'),
  save: svg('M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z'),
};

const PLACEHOLDER = 'data:image/svg+xml;utf8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect width="24" height="24" fill="#26262f"/><path transform="translate(4 4) scale(.66)" fill="#55555f" d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>');

function img(coverArt, albumId, size, cls = 'art') {
  const src = artUrl(coverArt, albumId, size) || PLACEHOLDER;
  return `<img class="${cls}" src="${esc(src)}" loading="lazy" onerror="this.onerror=null;this.src='${PLACEHOLDER}'" alt="">`;
}

const UI = {
  route: { name: 'home', params: {} },
  stack: [],
  lists: {},
  listSeq: 0,
  token: 0,
  npOpen: false,
  npTab: 'lyrics',
  lyrics: null,
  lyricsFor: null,
  menuSongs: null,
  menuExtra: null,
  state: { libTab: 'playlists', statsRange: 7, histSource: 'local' },
  lastSig: '',
  refreshTimer: null,

  async start() {
    applyTheme();
    APP_VERSION = await window.native.version();
    Player.init();
    Jam.init();
    this.bindEvents();
    this.shell();
    if (loggedIn()) {
      this.go('home', {}, false);
      Store.flushListens();
      setTimeout(() => Mixes.maybeGenerate(), 3000);
      if (Settings.autoUpdate) setTimeout(() => this.checkUpdate(true), 5000);
    }
    Player.on(() => this.onPlayer());
  },

  // ---------------- Layout ----------------

  shell() {
    const app = $('#app');
    if (!loggedIn()) {
      app.innerHTML = this.loginView();
      return;
    }
    const navs = [
      ['home', 'Home', ICON.home], ['search', 'Search', ICON.search], ['foryou', 'For You', ICON.sparkles],
      ['library', 'Your Library', ICON.library], ['liked', 'Liked Songs', ICON.heart],
    ];
    const navs2 = [['history', 'History', ICON.history], ['stats', 'Stats', ICON.chart], ['jam', 'Jam', ICON.jam], ['settings', 'Settings', ICON.settings]];
    app.innerHTML = `
      <aside class="side">
        <div class="logo"><div class="mark">${ICON.note}</div>Feynos Music</div>
        ${navs.map(([r, l, i]) => `<div class="nav" data-act="nav" data-route="${r}">${i}${l}</div>`).join('')}
        <div class="sep"></div>
        ${navs2.map(([r, l, i]) => `<div class="nav" data-act="nav" data-route="${r}">${i}${l}</div>`).join('')}
        <div id="jampill"></div>
        <div class="sep"></div>
        <div class="small">${esc(Settings.username)} · ${esc(Settings.serverUrl.replace(/^https?:\/\//, ''))}</div>
      </aside>
      <main class="main" id="main"></main>
      <footer class="bar" id="bar"></footer>`;
    this.renderBar();
  },

  setActiveNav() {
    document.querySelectorAll('.nav').forEach((n) => n.classList.toggle('on', n.dataset.route === this.route.name));
    const pill = $('#jampill');
    if (pill) {
      pill.innerHTML = Jam.role === 'none' ? '' : `<div class="jam-pill" data-act="nav" data-route="jam">${Jam.role === 'host' ? `Jam live · ${Jam.people().length} people` : `In ${esc(Jam.hostName)}'s jam`}</div>`;
    }
  },

  go(name, params = {}, push = true) {
    if (push) this.stack.push(this.route);
    if (this.stack.length > 50) this.stack.shift();
    this.route = { name, params };
    this.closeNp();
    this.render();
  },

  back() {
    const prev = this.stack.pop();
    if (prev) {
      this.route = prev;
      this.render();
    }
  },

  async render(keepScroll = false) {
    const main = $('#main');
    if (!main) return;
    const t = ++this.token;
    const scroll = keepScroll ? main.scrollTop : 0;
    if (!keepScroll) main.innerHTML = '<div class="spinner"></div>';
    this.setActiveNav();
    let html;
    try {
      const fn = this['view_' + this.route.name];
      html = fn ? await fn.call(this, this.route.params) : '<div class="empty">Not found</div>';
    } catch (e) {
      html = `<div class="empty"><p>${esc(e.message || e)}</p><button class="btn" data-act="retry">Retry</button></div>`;
    }
    if (t !== this.token) return;
    const top = this.stack.length ? `<div class="topbar"><button class="iconbtn" data-act="back" title="Back">${ICON.back}</button></div>` : '';
    main.innerHTML = top + html;
    main.scrollTop = scroll;
    this.markCurrent();
    const focus = main.querySelector('[data-autofocus]');
    if (focus && !keepScroll) focus.focus();
  },

  /** Re-renders things that show live state (jam, mixes, cover scan). */
  refresh() {
    clearTimeout(this.refreshTimer);
    this.refreshTimer = setTimeout(() => {
      this.setActiveNav();
      this.renderBar();
      if (['jam', 'covers', 'foryou', 'settings'].includes(this.route.name) && !document.activeElement?.matches('input')) this.render(true);
    }, 150);
  },

  // ---------------- Song lists ----------------

  reg(songs) {
    const key = 'l' + ++this.listSeq;
    this.lists[key] = songs;
    return key;
  },

  songRows(songs, opts = {}) {
    const key = this.reg(songs);
    if (!songs.length) return `<div class="empty">${esc(opts.empty || 'No songs')}</div>`;
    const cover = opts.cover !== false;
    return `<div class="songs">${songs.map((s, i) => `
      <div class="song ${cover ? '' : 'nocover'}" data-id="${esc(s.id)}" data-act="play-song" data-list="${key}" data-i="${i}" data-menu="1">
        <div class="n">${opts.numbers === 'track' ? (s.track || i + 1) : i + 1}</div>
        ${cover ? img(s.coverArt, s.albumId, 100, '') : ''}
        <div class="tt"><div>${esc(s.title)}</div><div class="a">${opts.sub ? esc(opts.sub(s, i)) : (s.artistId ? `<span class="link" data-act="go-artist" data-id="${esc(s.artistId)}">${esc(s.artist || '')}</span>` : esc(s.artist || ''))}</div></div>
        <div class="al">${s.albumId ? `<span class="link" data-act="go-album" data-id="${esc(s.albumId)}">${esc(s.album || '')}</span>` : esc(s.album || '')}</div>
        <div class="d">${Store.isStarred(s.id, s.starred) ? '<span style="color:var(--accent)">♥</span> ' : ''}${fmtTime(s.duration)}</div>
        <button class="iconbtn more" data-act="song-menu" data-list="${key}" data-i="${i}">${ICON.more}</button>
      </div>`).join('')}</div>`;
  },

  markCurrent() {
    const cur = Player.current();
    document.querySelectorAll('.song').forEach((r) => r.classList.toggle('cur', !!cur && r.dataset.id === cur.id));
  },

  albumCard(a) {
    return `<div class="card" data-act="go-album" data-id="${esc(a.id)}">${img(a.coverArt, a.id, 300)}<div class="t">${esc(a.name)}</div><div class="s">${esc(a.artist || '')}${a.year ? ' · ' + a.year : ''}</div></div>`;
  },
  artistCard(a) {
    return `<div class="card round" ${a.id ? `data-act="go-artist" data-id="${esc(a.id)}"` : ''}>${img(a.coverArt, null, 300)}<div class="t">${esc(a.name)}</div><div class="s">Artist</div></div>`;
  },
  mixArt(m) {
    const c = colorFor(m.id + m.title);
    return `<div class="mixart" style="background:linear-gradient(135deg, ${c}, #0e0e12)"><div class="mt">${esc(m.title)}</div>${m.coverArt ? `<img src="${esc(artUrl(m.coverArt, null, 300) || '')}" alt="" onerror="this.remove()">` : ''}<div class="bar"></div></div>`;
  },
  mixCard(m) {
    return `<div class="card" data-act="go-mix" data-id="${esc(m.id)}">${this.mixArt(m)}<div class="s" style="white-space:normal;margin-top:10px">${esc(m.description)}</div></div>`;
  },
  hero(art, kind, title, meta, extra = '') {
    return `<div class="hero">${art}<div><div class="kind">${esc(kind)}</div><div class="title">${esc(title)}</div><div class="meta">${meta}</div>${extra}</div></div>`;
  },
  actions(key, extra = '') {
    return `<div class="actions"><button class="play-big" data-act="play-list" data-list="${key}">${ICON.play}</button>
      <button class="iconbtn" data-act="shuffle-list" data-list="${key}" title="Shuffle">${ICON.shuffle}</button>
      <button class="iconbtn" data-act="queue-list" data-list="${key}" title="Add to queue">${ICON.queue}</button>
      <button class="iconbtn" data-act="pl-list" data-list="${key}" title="Add to playlist">${ICON.plus}</button>${extra}</div>`;
  },

  // ---------------- Views ----------------

  loginView() {
    return `<div class="login"><div class="box form">
      <div class="logo" style="padding:0 0 10px"><div class="mark">${ICON.note}</div>Feynos Music</div>
      <p class="muted">Sign in to your Navidrome server. If you leave out http:// or https://, both are tried. Your password isn't stored, only a salted token.</p>
      <div class="field"><label>Server address</label><input id="l-server" placeholder="music.example.com or 192.168.1.10:4533" data-autofocus></div>
      <div class="field"><label>Username</label><input id="l-user"></div>
      <div class="field"><label>Password</label><input id="l-pass" type="password"></div>
      <button class="btn primary" style="width:100%;justify-content:center" data-act="login">Connect</button>
      <p id="l-err" class="err"></p></div></div>`;
  },

  async view_home() {
    const safe = (p) => p.catch(() => []);
    const [recent, newest, frequent, starred, random] = await Promise.all([
      safe(API.albumList('recent', 20)), API.albumList('newest', 20), safe(API.albumList('frequent', 20)), safe(API.albumList('starred', 20)), safe(API.albumList('random', 20)),
    ]);
    const h = new Date().getHours();
    const greet = h < 5 ? 'Good evening' : h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
    const quick = [
      `<div class="q" data-act="nav" data-route="liked"><div class="qa" style="background:linear-gradient(135deg,var(--container),var(--accent));display:grid;place-items:center">${ICON.heartFill}</div>Liked Songs</div>`,
      ...Store.mixes.slice(0, 3).map((m) => `<div class="q" data-act="go-mix" data-id="${esc(m.id)}"><div class="qa" style="background:${colorFor(m.id + m.title)}"></div>${esc(m.title)}</div>`),
      ...recent.slice(0, 4).map((a) => `<div class="q" data-act="go-album" data-id="${esc(a.id)}">${img(a.coverArt, a.id, 120, '')}${esc(a.name)}</div>`),
    ].slice(0, 8);
    const jump = Store.recentSongs(20);
    const jumpKey = this.reg(jump);
    const shelf = (title, list, type) => list.length ? `<h2>${esc(title)}<span class="see" data-act="go-albums" data-type="${type}" data-title="${esc(title)}">See all</span></h2><div class="row">${list.map((a) => this.albumCard(a)).join('')}</div>` : '';
    return `<h1>${greet}</h1><div class="quick">${quick.join('')}</div>
      ${Store.mixes.length ? `<h2>Made for you<span class="see" data-act="nav" data-route="foryou">See all</span></h2><div class="row">${Store.mixes.map((m) => this.mixCard(m)).join('')}</div>` : ''}
      ${jump.length ? `<h2>Jump back in<span class="see" data-act="nav" data-route="history">See all</span></h2><div class="row">${jump.map((s, i) => `<div class="card" data-act="play-song" data-list="${jumpKey}" data-i="${i}" data-menu="1">${img(s.coverArt, s.albumId, 300)}<div class="t">${esc(s.title)}</div><div class="s">${esc(s.artist || '')}</div></div>`).join('')}</div>` : ''}
      ${shelf('Recently played albums', recent, 'recent')}${shelf('Recently added', newest, 'newest')}${shelf('Your most played', frequent, 'frequent')}${shelf('Liked albums', starred, 'starred')}${shelf('Something different', random, 'random')}`;
  },

  async view_search(p) {
    const q = p.q || '';
    let body;
    if (!q.trim()) {
      const genres = (await API.genres().catch(() => [])).sort((a, b) => (b.songCount || 0) - (a.songCount || 0));
      body = `<h2>Browse genres</h2><div class="grid">${genres.map((g) => `<div class="genre" style="background:linear-gradient(135deg, ${colorFor(g.value)}, #0e0e12)" data-act="go-genre" data-name="${esc(g.value)}">${esc(g.value)}<span>${g.songCount || 0} songs</span></div>`).join('')}</div>`;
    } else {
      const r = await API.search(q.trim());
      body = (!r.song.length && !r.album.length && !r.artist.length) ? `<div class="empty">Nothing in your library matches "${esc(q)}".</div>` : `
        ${r.artist.length ? `<h2>Artists</h2><div class="row">${r.artist.map((a) => this.artistCard(a)).join('')}</div>` : ''}
        ${r.album.length ? `<h2>Albums</h2><div class="row">${r.album.map((a) => this.albumCard(a)).join('')}</div>` : ''}
        ${r.song.length ? `<h2>Songs</h2>${this.songRows(r.song)}` : ''}`;
    }
    return `<h1>Search</h1><input class="search" id="searchbox" placeholder="What do you want to listen to?" value="${esc(q)}" data-autofocus>${body}`;
  },

  async view_foryou() {
    const lbOn = lbConnected();
    let lb = '';
    if (!lbOn) {
      lb = '<p class="muted">Connect ListenBrainz in Settings to keep your history in your MusicBrainz account and get weekly Jams and Exploration playlists.</p>';
    } else {
      if (!this.lbCache || Date.now() - this.lbCache.at > 600000) {
        const safe = (p) => p.catch(() => []);
        const [pls, tracks, artists, count] = await Promise.all([safe(LB.createdFor()), safe(LB.topRecordings('week', 10)), safe(LB.topArtists('week', 10)), LB.listenCount()]);
        this.lbCache = { pls, tracks, artists, count, at: Date.now() };
      }
      const c = this.lbCache;
      const max = Math.max(1, ...c.artists.map((a) => a.count));
      lb = `<p class="muted">Signed in as ${esc(Settings.lbUser)}${c.count != null ? ` · ${c.count} listens` : ''}</p>
        ${c.pls.length ? `<h2>Created for you</h2><div class="row">${c.pls.map((p) => `<div class="card" data-act="go-lb" data-id="${esc(p.mbid)}" data-title="${esc(p.title)}"><div class="mixart" style="background:linear-gradient(160deg, ${colorFor(p.title)}, #000)"><div class="mt">${esc(p.title.split(' for ')[0])}</div><div class="bar"></div></div><div class="s" style="white-space:normal;margin-top:8px">${esc(p.title)}</div></div>`).join('')}</div>` : ''}
        ${c.tracks.length ? `<h2>Your top tracks this week</h2>${c.tracks.map((t, i) => `<div class="list-item" data-act="lb-play" data-k="tracks" data-i="${i}"><div class="grow"><div>${esc(t.title)}</div><div class="muted">${esc(t.artist)}</div></div><div class="muted">${t.count} plays</div></div>`).join('')}` : ''}
        ${c.artists.length ? `<h2>Your top artists this week</h2>${c.artists.map((a) => this.hbar(a.name, a.count, max)).join('')}` : ''}`;
    }
    const last = Settings.lastMixGen ? `last updated ${timeAgo(Settings.lastMixGen)}` : 'not made yet';
    return `<h1>Made for you</h1><div class="actions"><span class="muted">Your mixes refresh every week · ${last}</span>
      <button class="btn" data-act="mixes-refresh" ${Mixes.generating ? 'disabled' : ''}>${Mixes.generating ? 'Making your mixes…' : 'Refresh now'}</button></div>
      ${Store.mixes.length ? `<div class="grid">${Store.mixes.map((m) => this.mixCard(m)).join('')}</div>` : '<div class="empty">No mixes yet. Mixes are built from what you play, your Navidrome library and ListenBrainz. Play some music, then press Refresh.</div>'}
      <h2>ListenBrainz</h2>${lb}`;
  },

  hbar(label, value, max) {
    return `<div class="hbar"><div class="top"><span>${esc(label)}</span><span class="muted">${value}</span></div><div class="track"><div class="fill" style="width:${(value / max) * 100}%"></div></div></div>`;
  },

  chips(group, options, current) {
    return `<div class="chips">${options.map(([v, l]) => `<div class="chip ${String(v) === String(current) ? 'on' : ''}" data-act="chip" data-group="${group}" data-val="${v}">${esc(l)}</div>`).join('')}</div>`;
  },

  async view_library() {
    const tab = this.state.libTab;
    let body = '';
    if (tab === 'playlists') {
      const pls = await API.playlists();
      body = `<div class="actions"><button class="btn" data-act="new-playlist">${ICON.plus} New playlist</button></div>
        <div class="grid">${pls.map((p) => `<div class="card" data-act="go-playlist" data-id="${esc(p.id)}">${img(p.coverArt, null, 300)}<div class="t">${esc(p.name)}</div><div class="s">Playlist · ${p.songCount || 0} songs</div></div>`).join('')}</div>`;
    } else if (tab === 'albums') {
      const albums = await API.albumList('alphabeticalByName', 500, 0);
      body = `<div class="grid">${albums.map((a) => this.albumCard(a)).join('')}</div>${albums.length === 500 ? '<p class="muted">Showing the first 500 albums. Use Search to find others.</p>' : ''}`;
    } else {
      const artists = (await API.artists()).sort((a, b) => String(a.name).localeCompare(String(b.name)));
      body = `<div class="grid">${artists.map((a) => this.artistCard(a)).join('')}</div>`;
    }
    return `<h1>Your Library</h1>${this.chips('libTab', [['playlists', 'Playlists'], ['albums', 'Albums'], ['artists', 'Artists']], tab)}${body}`;
  },

  async view_album({ id }) {
    const a = await API.album(id);
    const key = this.reg(a.song);
    const starred = Store.isStarred(a.id, a.starred);
    const meta = [a.artistId ? `<span class="link" data-act="go-artist" data-id="${esc(a.artistId)}"><b>${esc(a.artist)}</b></span>` : esc(a.artist || ''), a.year, `${a.song.length} songs`, totalDuration(a.duration || 0)].filter(Boolean).join(' · ');
    return this.hero(img(a.coverArt, a.id, 600), 'Album', a.name, meta) + this.actions(key, `
      <button class="iconbtn ${starred ? 'on' : ''}" data-act="star" data-kind="album" data-id="${esc(a.id)}" data-on="${starred ? 1 : 0}" title="Like">${starred ? ICON.heartFill : ICON.heart}</button>
      <button class="iconbtn" data-act="cover-pick" data-id="${esc(a.id)}" title="Find cover art">${ICON.image}</button>`)
      + this.songRows(a.song, { cover: false, numbers: 'track' });
  },

  async view_artist({ id }) {
    const artist = await API.artist(id);
    const [info, top] = await Promise.all([API.artistInfo(id).catch(() => ({ similarArtist: [] })), API.topSongs(artist.name, 20).catch(() => [])]);
    const starred = Store.isStarred(artist.id, artist.starred);
    const image = info.largeImageUrl && /^http/.test(info.largeImageUrl) && !info.largeImageUrl.includes('2a96cbd8b46e442fc41c2b86b821562f')
      ? `<img class="art round" src="${esc(info.largeImageUrl)}" alt="">` : img(artist.coverArt, null, 600, 'art round');
    const albums = artist.album.slice().sort((a, b) => (b.year || 0) - (a.year || 0));
    const key = this.reg(top);
    this.lists.artistAlbums = albums;
    return this.hero(image, 'Artist', artist.name, `${artist.albumCount || albums.length} albums`) + `
      <div class="actions"><button class="play-big" data-act="play-list" data-list="${key}">${ICON.play}</button>
      <button class="iconbtn" data-act="artist-shuffle" title="Shuffle all">${ICON.shuffle}</button>
      <button class="iconbtn" data-act="artist-radio" data-id="${esc(artist.id)}" data-name="${esc(artist.name)}" title="Artist radio">${ICON.radio}</button>
      <button class="btn" data-act="star" data-kind="artist" data-id="${esc(artist.id)}" data-on="${starred ? 1 : 0}">${starred ? 'Following' : 'Follow'}</button></div>
      ${top.length ? `<h2>Popular</h2>${this.songRows(top.slice(0, 10))}` : ''}
      ${albums.length ? `<h2>Discography</h2><div class="row">${albums.map((a) => this.albumCard(a)).join('')}</div>` : ''}
      ${info.similarArtist.length ? `<h2>Fans also like</h2><div class="row">${info.similarArtist.map((a) => this.artistCard(a)).join('')}</div>` : ''}
      ${info.biography ? `<h2>About</h2><p class="muted" style="max-width:900px;line-height:1.6">${esc(stripHtml(info.biography))}</p>` : ''}`;
  },

  async view_playlist({ id }) {
    const p = await API.playlist(id);
    const key = this.reg(p.entry);
    this.currentPlaylist = p;
    return this.hero(img(p.coverArt, null, 600), 'Playlist', p.name, `${esc(p.owner ? 'by ' + p.owner : '')} · ${p.entry.length} songs · ${totalDuration(p.duration || 0)}`)
      + this.actions(key, `<button class="iconbtn" data-act="delete-playlist" data-id="${esc(p.id)}" title="Delete playlist">${ICON.trash}</button>`)
      + this.songRows(p.entry, { empty: 'This playlist is empty. Add songs with the ⋯ menu on any track.' });
  },

  async view_mix({ id }) {
    const m = Store.mixes.find((x) => x.id === id);
    if (!m) return '<div class="empty">This mix has been refreshed. Open it again from For You.</div>';
    const key = this.reg(m.songs);
    return this.hero(`<div style="width:220px;flex:none">${this.mixArt(m)}</div>`, 'Made for you', m.title, `${esc(m.description)}<br>${m.songs.length} songs · updated ${timeAgo(m.createdAt)}`)
      + this.actions(key, `<button class="iconbtn" data-act="save-mix" data-id="${esc(m.id)}" title="Save to Navidrome">${ICON.save}</button>`)
      + this.songRows(m.songs);
  },

  async view_lb({ id, title }) {
    const pl = await LB.playlist(id);
    if (!pl) return '<div class="empty">Playlist not found on ListenBrainz.</div>';
    const matched = await Matcher.matchAll(pl.tracks);
    const songs = matched.filter(Boolean);
    const key = this.reg(songs);
    const missing = pl.tracks.filter((_, i) => !matched[i]);
    return this.hero(`<div class="art" style="background:linear-gradient(160deg, ${colorFor(title || pl.title)}, #000)"></div>`, 'ListenBrainz', pl.title, `${songs.length} of ${pl.tracks.length} songs are in your library`)
      + this.actions(key, `<button class="iconbtn" data-act="save-lb" data-list="${key}" data-title="${esc(pl.title)}" title="Save to Navidrome">${ICON.save}</button>`)
      + this.songRows(songs)
      + (missing.length ? `<h2>Not in your library</h2>${missing.map((t) => `<div class="list-item muted"><div class="grow">${esc(t.title)} · ${esc(t.artist)}</div></div>`).join('')}` : '');
  },

  async view_genre({ name }) {
    const [songs, albums] = await Promise.all([API.songsByGenre(name, 300), API.albumList('byGenre', 30, 0, name).catch(() => [])]);
    const key = this.reg(songs);
    return this.hero(`<div class="art" style="background:linear-gradient(135deg, ${colorFor(name)}, #000)"></div>`, 'Genre', name, `${songs.length} songs`)
      + this.actions(key) + (albums.length ? `<h2>Albums</h2><div class="row">${albums.map((a) => this.albumCard(a)).join('')}</div><h2>Songs</h2>` : '') + this.songRows(songs);
  },

  async view_albums({ type, title }) {
    const albums = await API.albumList(type, 200, 0);
    return `<h1>${esc(title || 'Albums')}</h1><div class="grid">${albums.map((a) => this.albumCard(a)).join('')}</div>`;
  },

  async view_liked() {
    const st = await API.starred();
    const key = this.reg(st.song);
    return this.hero(`<div class="art" style="background:linear-gradient(135deg,var(--container),var(--accent));display:grid;place-items:center;color:#fff">${ICON.heartFill.replace('<svg', '<svg width="90" height="90"')}</div>`, 'Playlist', 'Liked Songs', `${st.song.length} songs`)
      + this.actions(key) + this.songRows(st.song, { empty: 'Like songs with the heart to see them here.' })
      + (st.album.length ? `<h2>Liked albums</h2><div class="row">${st.album.map((a) => this.albumCard(a)).join('')}</div>` : '')
      + (st.artist.length ? `<h2>Followed artists</h2><div class="row">${st.artist.map((a) => this.artistCard(a)).join('')}</div>` : '');
  },

  async view_history() {
    const src = lbConnected() ? this.state.histSource : 'local';
    const tabs = lbConnected() ? this.chips('histSource', [['local', 'On this computer'], ['lb', 'ListenBrainz']], src) : '';
    if (src === 'lb') {
      const list = await LB.recentListens(100);
      this.lbHistory = list;
      return `<h1>Listening history</h1>${tabs}${list.map((t, i) => `<div class="list-item" data-act="lb-play" data-k="history" data-i="${i}"><div class="grow"><div>${esc(t.title)}</div><div class="muted">${esc(t.artist)}</div></div><div class="muted">${t.at ? timeAgo(t.at) : ''}</div></div>`).join('') || '<div class="empty">No listens yet.</div>'}`;
    }
    const plays = Store.plays.slice(-300).reverse();
    return `<h1>Listening history</h1>${tabs}${this.songRows(plays.map((p) => p.song), { empty: 'Songs you listen to show up here.', sub: (s, i) => `${s.artist || ''} · ${timeAgo(plays[i].at)}` })}`;
  },

  async view_stats() {
    const days = this.state.statsRange;
    const since = days ? Date.now() - days * 86400000 : 0;
    const list = Store.plays.filter((p) => p.at >= since);
    const minutes = Math.round(list.reduce((a, p) => a + (p.song.duration || 0), 0) / 60);
    const artists = Store.topArtists(since, 10);
    const songs = Store.topSongs(since, 10);
    const n = days === 7 ? 7 : 30;
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const counts = [];
    for (let i = n - 1; i >= 0; i--) {
      const d0 = start.getTime() - i * 86400000;
      counts.push([new Date(d0), Store.plays.filter((p) => p.at >= d0 && p.at < d0 + 86400000).length]);
    }
    const maxc = Math.max(1, ...counts.map((c) => c[1]));
    const maxa = Math.max(1, ...artists.map((a) => a.count));
    return `<h1>Your stats</h1>${this.chips('statsRange', [[7, '7 days'], [30, '30 days'], [365, '1 year'], [0, 'All time']], days)}
      <div class="stat-tiles"><div class="tile"><div class="v">${list.length}</div><div class="muted">Plays</div></div><div class="tile"><div class="v">${minutes}</div><div class="muted">Minutes</div></div>
      <div class="tile"><div class="v">${new Set(list.map((p) => p.song.id)).size}</div><div class="muted">Songs</div></div><div class="tile"><div class="v">${new Set(list.map((p) => p.song.artist)).size}</div><div class="muted">Artists</div></div></div>
      <h2>Plays per day</h2><div class="bars" style="margin-bottom:30px">${counts.map(([d, c]) => `<div style="height:${(c / maxc) * 100}%" title="${c} plays"><span>${n === 7 ? d.toLocaleDateString(undefined, { weekday: 'short' }) : (d.getDate() % 5 === 0 ? d.getDate() : '')}</span></div>`).join('')}</div>
      ${artists.length ? `<h2>Top artists</h2>${artists.map((a) => this.hbar(a.name, a.count, maxa)).join('')}` : ''}
      ${songs.length ? `<h2>Top songs</h2>${this.songRows(songs.map((x) => x[0]), { sub: (s, i) => `${s.artist || ''} · ${songs[i][1]} plays` })}` : ''}`;
  },

  async view_jam() {
    const people = Jam.people();
    let body;
    if (Jam.role === 'none') {
      body = `<div class="actions"><button class="btn primary" data-act="jam-start">Start a jam</button><button class="btn" data-act="jam-search">Join a jam</button></div>
        <p class="muted">Start a jam to play through this computer while friends on the same Wi-Fi add songs and control the music from Feynos Music on their phones. Or join a jam hosted by an Apple TV, a phone or another computer.</p>
        ${Jam.searching ? `<h2>Jams on this network</h2>${[...Jam.found.entries()].map(([id, name]) => `<div class="list-item" data-act="jam-join" data-id="${esc(id)}"><div class="avatar" style="background:${colorFor(name)}">${esc(name[0] || '?')}</div><div class="grow">${esc(name)}</div><div class="muted">${Jam.connectingTo === id ? 'Joining…' : 'Join'}</div></div>`).join('') || '<div class="empty">Looking for jams… The other device needs to tap Start a jam.</div>'}` : ''}`;
    } else {
      body = `<p class="muted">${Jam.role === 'host' ? 'Music plays from this computer. Phones on the same Wi-Fi can join from their Jam screen and control everything.' : `Music plays on ${esc(Jam.hostName)}'s device. Anything you play, queue or skip happens there.`}</p>
        <h2>In the jam (${people.length})</h2>${people.map((n, i) => `<div class="list-item"><div class="avatar" style="background:${colorFor(n)}">${esc((n[0] || '?').toUpperCase())}</div><div class="grow">${esc(n)}${i === 0 ? '<div class="muted">Playing the music</div>' : ''}</div></div>`).join('')}
        <p class="muted">Each person's listens go to their own Navidrome and ListenBrainz history for the songs they added.</p>
        <button class="btn danger" data-act="jam-leave">${Jam.role === 'host' ? 'End jam for everyone' : 'Leave jam'}</button>`;
    }
    const title = Jam.role === 'host' ? 'Your jam is live' : Jam.role === 'guest' ? `You're in ${esc(Jam.hostName)}'s jam` : 'Listen together';
    return `<h1>${title}</h1>${Jam.error ? `<p class="err">${esc(Jam.error)}</p>` : ''}${body}`;
  },

  async view_covers() {
    const entries = Object.entries(Store.covers).filter(([, e]) => e.missing || e.url).sort((a, b) => String(a[1].name).localeCompare(String(b[1].name)));
    const fixed = entries.filter(([, e]) => e.url), missing = entries.filter(([, e]) => !e.url && e.missing);
    const tile = ([id, e]) => `<div class="card" data-act="go-album" data-id="${esc(id)}">${img(e.coverArt, id, 300)}<div class="t">${esc(e.name)}</div><div class="s">${esc(e.source === 'manual' ? 'picked by you' : e.source || e.artist)}</div></div>`;
    return `<h1>Cover art</h1><p class="muted" style="max-width:800px">Finds albums that only show Navidrome's placeholder image and looks up the real cover on MusicBrainz (Cover Art Archive), Deezer and iTunes. To pick one by hand, open the album and use the image button.</p>
      ${Covers.running ? `<p>${esc(Covers.phase)}… ${Covers.done}/${Covers.total} · found ${Covers.found}</p><button class="btn" data-act="covers-stop">Stop</button>`
        : '<div class="actions"><button class="btn primary" data-act="covers-scan" data-full="0">Scan library</button><button class="btn" data-act="covers-scan" data-full="1">Re-check everything</button></div>'}
      ${fixed.length ? `<h2>Fixed (${fixed.length})</h2><div class="grid">${fixed.map(tile).join('')}</div>` : ''}
      ${missing.length ? `<h2>Still missing (${missing.length})</h2><div class="grid">${missing.map(tile).join('')}</div>` : ''}`;
  },

  async view_settings() {
    const sw = (key, label, sub) => `<div class="setting"><div class="l"><div>${label}</div>${sub ? `<div class="s">${sub}</div>` : ''}</div><div class="switch ${Settings[key] ? 'on' : ''}" data-act="set-toggle" data-key="${key}"></div></div>`;
    const sel = (key, label, opts) => `<div class="setting"><div class="l">${label}</div><select data-set="${key}" class="field" style="background:var(--panel3);border:0;border-radius:8px;padding:8px">${opts.map(([v, l]) => `<option value="${v}" ${String(Settings[key]) === String(v) ? 'selected' : ''}>${l}</option>`).join('')}</select></div>`;
    return `<h1>Settings</h1><div class="form">
      <h2>Navidrome</h2><div class="setting"><div class="l"><div>${esc(Settings.username)}</div><div class="s">${esc(Settings.serverUrl)}</div></div><button class="btn danger" data-act="logout">Sign out</button></div>
      <h2>ListenBrainz</h2>${lbConnected()
        ? `<div class="setting"><div class="l"><div>Connected as ${esc(Settings.lbUser)}</div><div class="s">Listens are stored in your MetaBrainz account${Store.lbQueue.length ? ` · ${Store.lbQueue.length} waiting to upload` : ''}</div></div><button class="btn" data-act="lb-disconnect">Disconnect</button></div>${sw('scrobbleLb', 'Send listens to ListenBrainz')}`
        : `<p class="muted">Paste your user token from <a href="#" data-act="open-url" data-url="https://listenbrainz.org/settings/">listenbrainz.org/settings</a> to keep your listening history in your MusicBrainz account and unlock weekly playlists.</p>
           <div class="field"><input id="lb-token" placeholder="User token" type="password"></div><button class="btn primary" data-act="lb-connect">Connect</button>`}
      <h2>Playback</h2>${sw('scrobbleNavidrome', 'Scrobble to Navidrome', 'Updates play counts (and Last.fm, if set up on the server)')}
      ${sel('maxBitrate', 'Streaming quality', [[0, 'Original'], [320, '320 kbps'], [256, '256 kbps'], [192, '192 kbps'], [128, '128 kbps']])}
      ${sel('format', 'Transcode format', [['raw', 'Server default'], ['opus', 'Opus'], ['mp3', 'MP3'], ['aac', 'AAC']])}
      <h2>Weekly mixes</h2><div class="setting"><div class="l"><div>Refresh mixes now</div><div class="s">${Settings.lastMixGen ? 'Last updated ' + timeAgo(Settings.lastMixGen) : 'Not made yet'}</div></div><button class="btn" data-act="mixes-refresh" ${Mixes.generating ? 'disabled' : ''}>${Mixes.generating ? 'Working…' : 'Refresh'}</button></div>
      ${sw('syncMixes', 'Save mixes to Navidrome', 'Keep a copy of each mix as a server playlist')}
      <h2>Cover art</h2><div class="setting"><div class="l"><div>Find missing cover art</div><div class="s">Looks up art on MusicBrainz, Deezer and iTunes</div></div><button class="btn" data-act="nav" data-route="covers">Open</button></div>
      ${sw('autoCovers', 'Fix new albums automatically', 'Checks for missing art when your mixes refresh')}
      <h2>Theme</h2><div class="themes">${THEMES.map((t) => `<div class="theme ${t.id === Settings.theme ? 'on' : ''}" data-act="theme" data-id="${t.id}"><div class="sw" style="background:${t.bg}"><span style="background:${t.accent}"></span></div>${esc(t.name.split(' (')[0])}${t.name.includes('(') ? `<div class="sub">${esc(t.name.split('(')[1].replace(')', ''))}</div>` : ''}</div>`).join('')}</div>
      <h2>Updates</h2>${sw('autoUpdate', 'Check for updates on start')}
      <div class="setting"><div class="l"><div>Feynos Music for Linux ${esc(APP_VERSION)}</div></div><button class="btn" data-act="check-update">Check now</button></div></div>`;
  },

  // ---------------- Player bar & Now Playing ----------------

  sig() {
    const s = Player.current();
    return [s && s.id, Player.isPlaying(), Player.shuffleOn(), Player.repeatMode(), Player.upNext().length, Jam.role, s && Store.isStarred(s.id, s.starred)].join('|');
  },

  onPlayer() {
    const sig = this.sig();
    if (sig !== this.lastSig) {
      this.lastSig = sig;
      this.renderBar();
      this.markCurrent();
      if (this.npOpen) this.renderNp();
    }
    this.updateProgress();
  },

  renderBar() {
    const bar = $('#bar');
    if (!bar) return;
    const s = Player.current();
    const rep = Player.repeatMode();
    const liked = s && Store.isStarred(s.id, s.starred);
    bar.innerHTML = `
      <div class="np" data-act="np-open">${s ? `${img(s.coverArt, s.albumId, 120, '')}<div class="tt"><div><b>${esc(s.title)}</b></div><div class="muted">${esc(s.artist || '')}</div></div>
        <button class="iconbtn ${liked ? 'on' : ''}" data-act="star" data-kind="song" data-id="${esc(s.id)}" data-on="${liked ? 1 : 0}">${liked ? ICON.heartFill : ICON.heart}</button>` : '<span class="muted">Nothing playing</span>'}</div>
      <div class="center"><div class="ctl">
        <button class="iconbtn ${Player.shuffleOn() ? 'on' : ''}" data-act="p-shuffle" title="Shuffle">${ICON.shuffle}</button>
        <button class="iconbtn" data-act="p-prev" title="Previous">${ICON.prev}</button>
        <button class="pp" data-act="p-toggle" title="Play/pause (space)">${Player.isPlaying() ? ICON.pause : ICON.play}</button>
        <button class="iconbtn" data-act="p-next" title="Next">${ICON.next}</button>
        <button class="iconbtn ${rep !== 'off' ? 'on' : ''}" data-act="p-repeat" title="Repeat">${rep === 'one' ? ICON.repeat1 : ICON.repeat}</button></div>
        <div class="seek"><span id="pos">0:00</span><input type="range" id="seek" min="0" max="1000" value="0"><span id="dur">0:00</span></div></div>
      <div class="right">${Jam.role !== 'none' ? `<button class="iconbtn on" data-act="nav" data-route="jam" title="Jam">${ICON.jam}</button>` : ''}
        <button class="iconbtn ${this.npOpen && this.npTab === 'lyrics' ? 'on' : ''}" data-act="np-tab" data-tab="lyrics" title="Lyrics">${ICON.lyrics}</button>
        <button class="iconbtn ${this.npOpen && this.npTab === 'queue' ? 'on' : ''}" data-act="np-tab" data-tab="queue" title="Queue">${ICON.queue}</button>
        ${Jam.isGuest() ? '' : `${ICON.volume.replace('<svg', '<svg width="20" height="20" style="color:var(--muted)"')}<input type="range" id="vol" min="0" max="100" value="${Math.round(Player.audio.volume * 100)}" style="--p:${Math.round(Player.audio.volume * 100)}%">`}</div>`;
    this.updateProgress();
  },

  updateProgress() {
    const seek = $('#seek');
    if (!seek || this.seeking) return;
    const d = Player.duration(), p = Player.position();
    const v = d > 0 ? Math.round((p / d) * 1000) : 0;
    seek.value = v;
    seek.style.setProperty('--p', v / 10 + '%');
    $('#pos').textContent = fmtTime(p);
    $('#dur').textContent = fmtTime(d);
    if (this.npOpen && this.npTab === 'lyrics' && this.lyrics && this.lyrics.synced) this.highlightLyric(p);
  },

  openNp(tab) {
    if (tab) this.npTab = tab;
    this.npOpen = true;
    this.renderNp();
    this.renderBar();
  },

  closeNp() {
    this.npOpen = false;
    const v = $('.np-view');
    if (v) v.remove();
    this.renderBar();
  },

  async renderNp() {
    let v = $('.np-view');
    const s = Player.current();
    if (!v) {
      v = document.createElement('div');
      v.className = 'np-view';
      document.body.appendChild(v);
    }
    if (!s) {
      v.innerHTML = `<button class="iconbtn np-close" data-act="np-close">${ICON.down}</button><div class="empty" style="grid-column:1/-1">Nothing playing</div>`;
      return;
    }
    const art = artUrl(s.coverArt, s.albumId, 800) || PLACEHOLDER;
    const by = Jam.role === 'none' ? {} : Jam.role === 'host' ? Jam.addedBy : Jam.addedBy;
    const next = Player.upNext();
    const queueHtml = `<h2>Now playing</h2>${this.songRows([s], { sub: () => s.artist || '' })}
      <h2>${Player.shuffleOn() ? 'Next up (shuffled)' : 'Next up'}${next.length ? '<span class="see" data-act="q-clear">Clear</span>' : ''}</h2>
      ${next.length ? next.slice(0, 200).map(({ i, song }) => `<div class="list-item" data-act="q-skip" data-i="${i}">${img(song.coverArt, song.albumId, 100, '').replace('<img', '<img style="width:44px;height:44px;border-radius:4px;object-fit:cover"')}
        <div class="grow"><div>${esc(song.title)}</div><div class="muted">${esc(song.artist || '')}${by[song.id] ? ' · added by ' + esc(by[song.id]) : ''}</div></div>
        <button class="iconbtn" data-act="q-up" data-i="${i}" title="Move up">▲</button><button class="iconbtn" data-act="q-down" data-i="${i}" title="Move down">▼</button>
        <button class="iconbtn" data-act="q-remove" data-i="${i}" title="Remove">${ICON.close}</button></div>`).join('') : '<p class="muted">Nothing queued</p>'}`;
    v.innerHTML = `<div class="bg" style="background-image:url('${esc(art)}')"></div>
      <button class="iconbtn np-close" data-act="np-close" title="Close">${ICON.down}</button>
      <div class="left"><img src="${esc(art)}" alt="" onerror="this.src='${PLACEHOLDER}'"><div class="t">${esc(s.title)}</div>
        <div class="muted">${s.artistId ? `<span class="link" data-act="go-artist" data-id="${esc(s.artistId)}">${esc(s.artist || '')}</span>` : esc(s.artist || '')}${s.album ? ` · ${s.albumId ? `<span class="link" data-act="go-album" data-id="${esc(s.albumId)}">${esc(s.album)}</span>` : esc(s.album)}` : ''}</div>
        ${Jam.role !== 'none' ? `<div style="color:var(--accent);font-weight:700">Jam · ${esc(Jam.people().join(', '))}</div>` : ''}</div>
      <div class="right">${this.chips('npTab', [['lyrics', 'Lyrics'], ['queue', 'Up next']], this.npTab)}<div class="panel" id="nppanel">${this.npTab === 'queue' ? queueHtml : '<div class="spinner"></div>'}</div></div>`;
    this.markCurrent();
    if (this.npTab === 'lyrics') {
      if (this.lyricsFor !== s.id) {
        this.lyricsFor = s.id;
        this.lyrics = null;
        this.lyrics = await API.lyrics(s);
        if (Player.current()?.id !== s.id) return;
      }
      const panel = $('#nppanel');
      if (!panel) return;
      const l = this.lyrics;
      panel.innerHTML = l && l.lines.length
        ? l.lines.map((x, i) => `<div class="lyric ${l.synced ? '' : 'plain'}" data-li="${i}" ${l.synced ? `data-act="lyric-seek" data-ms="${x.start || 0}"` : ''}>${esc(x.value || '♪')}</div>`).join('')
        : '<div class="empty">No lyrics found for this song</div>';
      this.curLyric = -1;
      this.highlightLyric(Player.position());
    }
  },

  highlightLyric(pos) {
    const l = this.lyrics;
    if (!l || !l.synced) return;
    let cur = -1;
    for (let i = 0; i < l.lines.length; i++) if ((l.lines[i].start || 0) / 1000 <= pos + 0.3) cur = i;
    if (cur === this.curLyric) return;
    this.curLyric = cur;
    document.querySelectorAll('.lyric').forEach((el, i) => {
      el.classList.toggle('cur', i === cur);
      el.classList.toggle('past', i < cur);
    });
    const el = document.querySelector(`.lyric[data-li="${cur}"]`);
    if (el) el.scrollIntoView({ block: 'center', behavior: 'smooth' });
  },

  // ---------------- Menus & dialogs ----------------

  showMenu(x, y, items) {
    const m = $('#menu');
    m.innerHTML = items.map((it, i) => `<div data-mi="${i}">${esc(it[0])}</div>`).join('');
    m.classList.remove('hidden');
    this.menuItems = items;
    const r = m.getBoundingClientRect();
    m.style.left = Math.min(x, window.innerWidth - r.width - 8) + 'px';
    m.style.top = Math.min(y, window.innerHeight - r.height - 8) + 'px';
  },
  hideMenu() {
    $('#menu').classList.add('hidden');
  },

  songMenu(x, y, song, listKey, index) {
    const liked = Store.isStarred(song.id, song.starred);
    const items = [
      ['Play next', () => { Player.playNext([song]); toast('Playing next'); }],
      ['Add to queue', () => { Player.addToQueue([song]); toast('Added to queue'); }],
      ['Start radio', () => this.startRadio(song)],
      [liked ? 'Remove from Liked' : 'Like', () => this.toggleStar('song', song.id, liked)],
      ['Add to playlist', () => this.addToPlaylist([song])],
    ];
    if (song.albumId) items.push(['Go to album', () => this.go('album', { id: song.albumId })]);
    if (song.artistId) items.push(['Go to artist', () => this.go('artist', { id: song.artistId })]);
    if (this.route.name === 'playlist' && this.currentPlaylist && this.lists[listKey] === this.currentPlaylist.entry) {
      items.push(['Remove from this playlist', async () => {
        try {
          await API.removeFromPlaylist(this.currentPlaylist.id, index);
          this.render(true);
        } catch (e) {
          toast(`Couldn't remove: ${e.message}`);
        }
      }]);
    }
    this.showMenu(x, y, items);
  },

  modal(html) {
    const m = $('#modal');
    m.innerHTML = `<div class="box">${html}</div>`;
    m.classList.remove('hidden');
  },
  closeModal() {
    $('#modal').classList.add('hidden');
  },

  async addToPlaylist(songs) {
    this.pendingSongs = songs;
    this.modal('<div class="spinner"></div>');
    let pls = [];
    try {
      pls = await API.playlists();
    } catch (e) { /* show empty */ }
    this.modal(`<h2 style="margin-top:0">Add to playlist</h2>
      <div class="actions"><input id="newpl" class="search" placeholder="New playlist name" style="max-width:none"><button class="btn primary" data-act="create-pl">Create</button></div>
      ${pls.map((p) => `<div class="list-item" data-act="add-to-pl" data-id="${esc(p.id)}" data-name="${esc(p.name)}">${img(p.coverArt, null, 100, '').replace('<img', '<img style="width:44px;height:44px;border-radius:4px;object-fit:cover"')}<div class="grow">${esc(p.name)}</div><div class="muted">${p.songCount || 0} songs</div></div>`).join('')}
      <div class="actions"><button class="btn" data-act="modal-close">Close</button></div>`);
  },

  async coverPicker(albumId) {
    const album = await API.album(albumId).catch(() => null);
    if (!album) return;
    this.coverAlbum = album;
    this.modal('<h2 style="margin-top:0">Cover art</h2><p class="muted">Searching MusicBrainz, Deezer and iTunes…</p><div class="spinner"></div>');
    const c = await Covers.candidates(album.artist || '', album.name);
    this.coverCands = c;
    const current = Store.coverOverride(album.id);
    this.modal(`<h2 style="margin-top:0">Cover art for ${esc(album.name)}</h2>
      ${c.length ? `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(130px,1fr))">${c.map((x, i) => `<div class="card" data-act="cover-set" data-i="${i}" style="${x.url === current ? 'outline:3px solid var(--accent)' : ''}"><img class="art" src="${esc(x.thumb)}" alt=""><div class="s" style="color:var(--accent)">${esc(x.source)}</div><div class="s">${esc([x.title, x.artist].filter(Boolean).join(' · '))}</div></div>`).join('')}</div>` : '<p class="muted">No artwork found online for this album.</p>'}
      <div class="actions">${current ? '<button class="btn" data-act="cover-reset">Use server art</button>' : ''}<button class="btn" data-act="modal-close">Close</button></div>`);
  },

  // ---------------- Actions ----------------

  async toggleStar(kind, id, liked) {
    Store.stars[id] = !liked;
    this.onPlayer();
    try {
      await API.setStar(!liked, kind, id);
      toast(liked ? 'Removed from Liked' : 'Added to Liked');
    } catch (e) {
      Store.stars[id] = liked;
      toast(`Couldn't update: ${e.message}`);
    }
    this.lastSig = '';
    this.onPlayer();
    if (['album', 'artist', 'liked'].includes(this.route.name)) this.render(true);
  },

  async startRadio(song) {
    toast('Starting radio…');
    const list = [song];
    const add = (songs) => list.push(...songs.filter((s) => !list.some((x) => x.id === s.id)));
    add(await API.similarSongs(song.id, 50).catch(() => []));
    if (list.length < 15 && song.artist) add(await API.topSongs(song.artist, 15).catch(() => []));
    if (list.length < 25) add(await API.randomSongs(30, song.genre).catch(() => []));
    Player.play([song, ...shuffled(list.slice(1))]);
  },

  async checkUpdate(quiet) {
    try {
      const res = await fetch('https://api.github.com/repos/Feynos-Lin/FeynosMusic/releases?per_page=30');
      const rels = await res.json();
      const linux = (Array.isArray(rels) ? rels : []).find((r) => String(r.tag_name).startsWith('linux-v'));
      if (!linux) {
        if (!quiet) toast("You're on the latest version");
        return;
      }
      const latest = String(linux.tag_name).replace('linux-v', '');
      const newer = latest.split('.').map(Number).reduce((acc, n, i) => acc ?? (n > (+APP_VERSION.split('.')[i] || 0) ? true : n < (+APP_VERSION.split('.')[i] || 0) ? false : null), null);
      if (!newer) {
        if (!quiet) toast("You're on the latest version");
        return;
      }
      const rpm = (linux.assets || []).find((a) => a.name.endsWith('.rpm'));
      this.updateUrl = rpm ? rpm.browser_download_url : linux.html_url;
      this.modal(`<h2 style="margin-top:0">Update available: ${esc(latest)}</h2><p class="muted" style="white-space:pre-wrap">${esc(linux.body || '')}</p>
        <p class="muted">Download the new .rpm and open it to install, or run <code>sudo dnf install ./${esc(rpm ? rpm.name : 'feynos-music.rpm')}</code>.</p>
        <div class="actions"><button class="btn primary" data-act="open-url" data-url="${esc(this.updateUrl)}">Download</button><button class="btn" data-act="modal-close">Later</button></div>`);
    } catch (e) {
      if (!quiet) toast("Couldn't check for updates");
    }
  },

  async act(a, el, ev) {
    const d = el.dataset;
    const list = d.list ? this.lists[d.list] || [] : [];
    switch (a) {
      case 'nav': this.stack = []; this.go(d.route, {}, false); break;
      case 'back': this.back(); break;
      case 'retry': this.render(); break;
      case 'go-album': this.go('album', { id: d.id }); break;
      case 'go-artist': this.go('artist', { id: d.id }); break;
      case 'go-playlist': this.go('playlist', { id: d.id }); break;
      case 'go-mix': this.go('mix', { id: d.id }); break;
      case 'go-lb': this.go('lb', { id: d.id, title: d.title }); break;
      case 'go-genre': this.go('genre', { name: d.name }); break;
      case 'go-albums': this.go('albums', { type: d.type, title: d.title }); break;
      case 'play-song': Player.play(list, +d.i); break;
      case 'song-menu': {
        const s = list[+d.i];
        if (s) this.songMenu(ev.clientX, ev.clientY, s, d.list, +d.i);
        break;
      }
      case 'play-list': Player.play(list); break;
      case 'shuffle-list': Player.play(list, 0, true); break;
      case 'queue-list': Player.addToQueue(list); toast('Added to queue'); break;
      case 'pl-list': this.addToPlaylist(list); break;
      case 'star': this.toggleStar(d.kind, d.id, d.on === '1'); break;
      case 'artist-shuffle': {
        toast('Loading all songs…');
        const all = [];
        for (const al of this.lists.artistAlbums || []) all.push(...((await API.album(al.id).catch(() => null))?.song || []));
        Player.play(all, 0, true);
        break;
      }
      case 'artist-radio': {
        toast('Starting radio…');
        const songs = [...(await API.topSongs(d.name, 10).catch(() => [])), ...(await API.similarSongsForArtist(d.id, 50).catch(() => []))];
        if (songs.length) Player.play(shuffled(uniqueById(songs)));
        else toast('Nothing to play');
        break;
      }
      case 'p-toggle': Player.toggle(); break;
      case 'p-next': Player.next(); break;
      case 'p-prev': Player.previous(); break;
      case 'p-shuffle': Player.toggleShuffle(); break;
      case 'p-repeat': Player.cycleRepeat(); break;
      case 'np-open': if (!ev.target.closest('[data-act="star"]')) (this.npOpen ? this.closeNp() : this.openNp()); break;
      case 'np-close': this.closeNp(); break;
      case 'np-tab':
        if (this.npOpen && this.npTab === d.tab) this.closeNp();
        else this.openNp(d.tab);
        break;
      case 'lyric-seek': Player.seek((+d.ms || 0) / 1000); break;
      case 'q-skip': if (!ev.target.closest('button')) Player.skipTo(+d.i); break;
      case 'q-remove': Player.removeAt(+d.i); break;
      case 'q-up': Player.move(+d.i, +d.i - 1); break;
      case 'q-down': Player.move(+d.i, +d.i + 1); break;
      case 'q-clear': Player.clearUpNext(); break;
      case 'chip':
        if (d.group === 'npTab') {
          this.npTab = d.val;
          this.renderNp();
          this.renderBar();
        } else {
          this.state[d.group] = d.group === 'statsRange' ? +d.val : d.val;
          this.render();
        }
        break;
      case 'lb-play': {
        const t = d.k === 'tracks' ? this.lbCache.tracks[+d.i] : this.lbHistory[+d.i];
        const s = t && (await Matcher.match(t));
        if (s) Player.play([s]);
        else toast("That song isn't in your library");
        break;
      }
      case 'mixes-refresh': Mixes.generate(); break;
      case 'save-mix': {
        const m = Store.mixes.find((x) => x.id === d.id);
        if (m) API.savePlaylist(`Feynos · ${m.title}`, m.songs).then(() => toast('Saved to Navidrome'), (e) => toast(`Couldn't save: ${e.message}`));
        break;
      }
      case 'save-lb': API.savePlaylist(d.title.split(' for ')[0], list).then(() => toast('Saved to Navidrome'), (e) => toast(`Couldn't save: ${e.message}`)); break;
      case 'covers-scan': Covers.scan(d.full === '1'); break;
      case 'covers-stop': Covers.stop(); break;
      case 'cover-pick': this.coverPicker(d.id); break;
      case 'cover-set': {
        const c = this.coverCands[+d.i];
        if (c) Covers.set(this.coverAlbum, c.url, 'manual');
        toast('Cover updated');
        this.closeModal();
        this.render(true);
        break;
      }
      case 'cover-reset':
        Covers.set(this.coverAlbum, null, null);
        this.closeModal();
        this.render(true);
        break;
      case 'jam-start': Jam.start(); break;
      case 'jam-search': Jam.search(); break;
      case 'jam-join': Jam.join(d.id); break;
      case 'jam-leave': Jam.end(); break;
      case 'set-toggle':
        Settings[d.key] = !Settings[d.key];
        saveSettings();
        el.classList.toggle('on', !!Settings[d.key]);
        break;
      case 'logout':
        if (confirm('Sign out of this server?')) {
          await Jam.end();
          Player.stop();
          Object.assign(Settings, { serverUrl: '', username: '', token: '', salt: '' });
          saveSettings();
          this.stack = [];
          this.shell();
        }
        break;
      case 'lb-connect': {
        const token = $('#lb-token').value.trim();
        if (!token) break;
        try {
          const user = await LB.validate(token);
          if (!user) return toast("That token isn't valid");
          Object.assign(Settings, { lbToken: token, lbUser: user });
          saveSettings();
          toast(`Connected to ListenBrainz as ${user}`);
          this.render();
          Mixes.generate(true);
        } catch (e) {
          toast(`Couldn't reach ListenBrainz: ${e.message}`);
        }
        break;
      }
      case 'lb-disconnect':
        Object.assign(Settings, { lbToken: '', lbUser: '' });
        saveSettings();
        this.render();
        break;
      case 'theme':
        Settings.theme = d.id;
        saveSettings();
        applyTheme();
        this.render(true);
        break;
      case 'check-update': this.checkUpdate(false); break;
      case 'open-url': ev.preventDefault(); window.native.openExternal(d.url); break;
      case 'new-playlist': this.addToPlaylist([]); break;
      case 'create-pl': {
        const name = $('#newpl').value.trim();
        if (!name) break;
        try {
          await API.createPlaylist(name, (this.pendingSongs || []).map((s) => s.id));
          toast(`Created "${name}"`);
          this.closeModal();
          if (this.route.name === 'library') this.render(true);
        } catch (e) {
          toast(`Couldn't create playlist: ${e.message}`);
        }
        break;
      }
      case 'add-to-pl':
        if (!(this.pendingSongs || []).length) {
          this.closeModal();
          this.go('playlist', { id: d.id });
          break;
        }
        try {
          await API.addToPlaylist(d.id, this.pendingSongs.map((s) => s.id));
          toast(`Added to ${d.name}`);
        } catch (e) {
          toast(`Couldn't add: ${e.message}`);
        }
        this.closeModal();
        break;
      case 'delete-playlist':
        if (confirm('Delete this playlist from your Navidrome server?')) {
          try {
            await API.deletePlaylist(d.id);
            toast('Playlist deleted');
            this.back();
          } catch (e) {
            toast(`Couldn't delete: ${e.message}`);
          }
        }
        break;
      case 'modal-close': this.closeModal(); break;
      case 'login': {
        const err = $('#l-err');
        err.textContent = 'Connecting…';
        try {
          await API.login($('#l-server').value, $('#l-user').value, $('#l-pass').value);
          this.shell();
          this.go('home', {}, false);
          setTimeout(() => Mixes.maybeGenerate(), 3000);
        } catch (e) {
          err.textContent = e.message;
        }
        break;
      }
      default: break;
    }
  },

  bindEvents() {
    document.addEventListener('click', (ev) => {
      const mi = ev.target.closest('[data-mi]');
      if (mi) {
        const it = this.menuItems && this.menuItems[+mi.dataset.mi];
        this.hideMenu();
        if (it) it[1]();
        return;
      }
      this.hideMenu();
      if (ev.target.id === 'modal') return this.closeModal();
      const el = ev.target.closest('[data-act]');
      if (!el) return;
      // Links inside a song row act on their own.
      this.act(el.dataset.act, el, ev);
    });
    document.addEventListener('contextmenu', (ev) => {
      const row = ev.target.closest('[data-menu]');
      if (!row) return;
      ev.preventDefault();
      const s = (this.lists[row.dataset.list] || [])[+row.dataset.i];
      if (s) this.songMenu(ev.clientX, ev.clientY, s, row.dataset.list, +row.dataset.i);
    });
    document.addEventListener('input', (ev) => {
      const t = ev.target;
      if (t.id === 'searchbox') {
        clearTimeout(this.searchTimer);
        this.searchTimer = setTimeout(() => {
          this.route = { name: 'search', params: { q: t.value } };
          this.render(true).then(() => {
            const box = $('#searchbox');
            if (box) {
              box.focus();
              box.setSelectionRange(box.value.length, box.value.length);
            }
          });
        }, 350);
      } else if (t.id === 'seek') {
        this.seeking = true;
        t.style.setProperty('--p', t.value / 10 + '%');
        $('#pos').textContent = fmtTime((t.value / 1000) * Player.duration());
      } else if (t.id === 'vol') {
        t.style.setProperty('--p', t.value + '%');
        Player.setVolume(t.value / 100);
      }
    });
    document.addEventListener('change', (ev) => {
      const t = ev.target;
      if (t.id === 'seek') {
        this.seeking = false;
        Player.seek((t.value / 1000) * Player.duration());
      } else if (t.dataset.set) {
        const k = t.dataset.set;
        Settings[k] = typeof Settings[k] === 'number' ? +t.value : t.value;
        saveSettings();
      }
    });
    document.addEventListener('keydown', (ev) => {
      const typing = ev.target.matches('input, select, textarea');
      if (ev.key === 'Enter' && ev.target.id && ev.target.id.startsWith('l-')) this.act('login', ev.target, ev);
      if (typing) return;
      if (ev.code === 'Space') {
        ev.preventDefault();
        Player.toggle();
      } else if (ev.key === 'Escape') {
        this.hideMenu();
        this.closeModal();
        this.closeNp();
      } else if (ev.altKey && ev.key === 'ArrowLeft') {
        this.back();
      } else if (ev.ctrlKey && ev.key === 'ArrowRight') {
        Player.next();
      } else if (ev.ctrlKey && ev.key === 'ArrowLeft') {
        Player.previous();
      } else if (ev.ctrlKey && ev.key.toLowerCase() === 'f') {
        this.go('search', {});
      }
    });
    document.addEventListener('mouseup', (ev) => {
      if (ev.button === 3) this.back();
    });
  },
};

window.addEventListener('DOMContentLoaded', () => UI.start());
