// Feynos Music for Linux — data layer: helpers, settings, local storage, Navidrome and ListenBrainz.
'use strict';

// ---------------- Helpers ----------------

const $ = (sel, root = document) => root.querySelector(sel);

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

function fmtTime(sec) {
  sec = Math.max(0, Math.floor(sec || 0));
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
}

function totalDuration(sec) {
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
  return h > 0 ? `${h} hr ${m} min` : `${m} min`;
}

function timeAgo(ms) {
  const d = (Date.now() - ms) / 1000;
  if (d < 60) return 'just now';
  if (d < 3600) return `${Math.floor(d / 60)} min ago`;
  if (d < 86400) return `${Math.floor(d / 3600)} hr ago`;
  if (d < 86400 * 7) return `${Math.floor(d / 86400)} d ago`;
  return new Date(ms).toLocaleDateString();
}

function cleanTitle(t) {
  const r = String(t || '')
    .replace(/\s*[([][^)\]]*[)\]]/g, '')
    .replace(/\s+-\s+.*(remaster|version|edit|mix|live|mono|stereo).*/i, '')
    .trim();
  return r || String(t || '');
}

function norm(s) {
  return cleanTitle(s).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

function similar(a, b) {
  const x = norm(a), y = norm(b);
  if (!x || !y) return false;
  return x === y || (x.length >= 3 && y.includes(x)) || (y.length >= 3 && x.includes(y));
}

function shuffled(list) {
  const a = list.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function uniqueById(list) {
  const seen = new Set();
  return list.filter((s) => s && !seen.has(s.id) && seen.add(s.id));
}

function stripHtml(s) {
  return String(s || '').replace(/<a [^>]*>.*?<\/a>/g, '').replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'").trim();
}

function albumIdFromCover(c) {
  if (!c || !c.startsWith('al-')) return null;
  return c.slice(3).split('_')[0] || null;
}

function colorFor(seed) {
  const palette = ['#6c3ce0', '#1e88e5', '#00897b', '#e53935', '#f4511e', '#8e24aa', '#3949ab', '#43a047', '#d81b60', '#6d4c41', '#00acc1'];
  let h = 5381;
  for (const ch of String(seed)) h = ((h * 33) ^ ch.charCodeAt(0)) >>> 0;
  return palette[h % palette.length];
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function toast(msg) {
  const t = $('#toast');
  if (!t) return;
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => t.classList.remove('show'), 3000);
}

// ---------------- Local storage ----------------

const DB = {
  get(key, fallback) {
    try {
      const v = localStorage.getItem(key);
      return v == null ? fallback : JSON.parse(v);
    } catch (e) {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {
      console.warn('Storage full', e);
    }
  },
};

const Settings = Object.assign(
  {
    serverUrl: '', username: '', token: '', salt: '',
    lbToken: '', lbUser: '',
    scrobbleNavidrome: true, scrobbleLb: true,
    maxBitrate: 0, format: 'raw',
    syncMixes: false, autoCovers: true, autoUpdate: true,
    lastMixGen: 0, volume: 0.9, theme: 'feynos', layout: 'feynos',
  },
  DB.get('settings', {}),
);

// Colour themes. The "-style" ones borrow the colour feel of other music apps (no logos or branding).
const THEMES = [
  { id: 'feynos', name: 'Feynos purple', accent: '#a970ff', on: '#14002e', bg: '#0e0e12', panel: '#15151b', panel2: '#1c1c24', panel3: '#26262f', container: '#3a2766', side: '#000000' },
  { id: 'spotify', name: 'Green & black (Spotify-style)', accent: '#1ed760', on: '#000000', bg: '#121212', panel: '#181818', panel2: '#1f1f1f', panel3: '#2a2a2a', container: '#0f3d22', side: '#000000' },
  { id: 'apple', name: 'Rose red (Apple Music-style)', accent: '#fa2d48', on: '#ffffff', bg: '#1c1c1e', panel: '#232325', panel2: '#2a2a2c', panel3: '#3a3a3c', container: '#4a1019', side: '#141416' },
  { id: 'youtube', name: 'Red & black (YouTube Music-style)', accent: '#ff0033', on: '#ffffff', bg: '#030303', panel: '#0f0f0f', panel2: '#181818', panel3: '#272727', container: '#4a0010', side: '#000000' },
  { id: 'soundcloud', name: 'Orange (SoundCloud-style)', accent: '#ff5500', on: '#ffffff', bg: '#121212', panel: '#1a1a1a', panel2: '#222222', panel3: '#2e2e2e', container: '#4d1c00', side: '#0a0a0a' },
  { id: 'tidal', name: 'Black & cyan (Tidal-style)', accent: '#33ffee', on: '#00201d', bg: '#000000', panel: '#0d0d0d', panel2: '#171717', panel3: '#242424', container: '#0b3d3a', side: '#000000' },
  { id: 'amazon', name: 'Teal (Amazon Music-style)', accent: '#25d1da', on: '#00282a', bg: '#0b0f12', panel: '#12181d', panel2: '#19212a', panel3: '#232f3e', container: '#0e3b42', side: '#05080a' },
  { id: 'deezer', name: 'Violet (Deezer-style)', accent: '#a238ff', on: '#ffffff', bg: '#0f0d13', panel: '#191622', panel2: '#201c2b', panel3: '#2a2533', container: '#3b1a66', side: '#09080c' },
];

// Layouts. The "-style" ones follow the structure of other music apps (no logos or branding).
const LAYOUTS = [
  { id: 'feynos', name: 'Feynos', blurb: 'Sidebar with For You, quick-pick grid on Home' },
  { id: 'spotify', name: 'Spotify-style', blurb: 'Home, Search and Your Library, filter chips and an 8-tile quick grid' },
  { id: 'apple', name: 'Apple Music-style', blurb: 'Player along the top, Listen Now with big Top Picks, artwork that shrinks when paused' },
  { id: 'youtube', name: 'YouTube Music-style', blurb: 'Search bar on top, slim side rail, mood chips, Listen again and Quick picks' },
];

function applyTheme() {
  const t = THEMES.find((x) => x.id === Settings.theme) || THEMES[0];
  const r = document.documentElement.style;
  r.setProperty('--accent', t.accent);
  r.setProperty('--on-accent', t.on);
  r.setProperty('--bg', t.bg);
  r.setProperty('--panel', t.panel);
  r.setProperty('--panel2', t.panel2);
  r.setProperty('--panel3', t.panel3);
  r.setProperty('--container', t.container);
  r.setProperty('--side', t.side);
}

function saveSettings() {
  DB.set('settings', Settings);
}

const loggedIn = () => !!(Settings.serverUrl && Settings.username && Settings.token);
const lbConnected = () => !!(Settings.lbToken && Settings.lbUser);

const Store = {
  plays: DB.get('plays', []), // [{song, at}]
  mixes: DB.get('mixes', []), // [{id,title,description,createdAt,coverArt,songs}]
  covers: DB.get('covers', {}), // albumId -> {name, artist, coverArt, hash, missing, url, source, checkedAt}
  lbQueue: DB.get('lbQueue', []),
  matches: DB.get('matches', {}),
  stars: {},

  addPlay(song, at) {
    this.plays.push({ song, at });
    if (this.plays.length > 6000) this.plays.splice(0, this.plays.length - 6000);
    DB.set('plays', this.plays);
  },
  recentSongs(limit) {
    const seen = new Set(), out = [];
    for (let i = this.plays.length - 1; i >= 0 && out.length < limit; i--) {
      const s = this.plays[i].song;
      if (!seen.has(s.id)) {
        seen.add(s.id);
        out.push(s);
      }
    }
    return out;
  },
  topSongs(since, limit) {
    const m = new Map();
    for (const p of this.plays) if (p.at >= since) {
      const e = m.get(p.song.id) || [p.song, 0];
      e[1]++;
      m.set(p.song.id, e);
    }
    return [...m.values()].sort((a, b) => b[1] - a[1]).slice(0, limit);
  },
  topArtists(since, limit) {
    const m = new Map();
    for (const p of this.plays) if (p.at >= since && p.song.artist) {
      const e = m.get(p.song.artist) || { name: p.song.artist, id: p.song.artistId, count: 0 };
      e.count++;
      m.set(p.song.artist, e);
    }
    return [...m.values()].sort((a, b) => b.count - a.count).slice(0, limit);
  },
  playedIds() {
    return new Set(this.plays.map((p) => p.song.id));
  },
  forgotten(before, minPlays, limit) {
    const m = new Map();
    for (const p of this.plays) {
      const e = m.get(p.song.id) || { song: p.song, n: 0, last: 0 };
      e.n++;
      e.last = Math.max(e.last, p.at);
      m.set(p.song.id, e);
    }
    return [...m.values()].filter((e) => e.n >= minPlays && e.last < before).sort((a, b) => b.n - a.n).slice(0, limit).map((e) => e.song);
  },
  saveMixes(list) {
    this.mixes = list;
    DB.set('mixes', list);
  },
  coverOverride(albumId) {
    return albumId && this.covers[albumId] ? this.covers[albumId].url || null : null;
  },
  setCover(albumId, entry) {
    this.covers[albumId] = Object.assign(this.covers[albumId] || {}, entry);
    DB.set('covers', this.covers);
  },
  saveCovers() {
    DB.set('covers', this.covers);
  },
  isStarred(id, serverStarred) {
    return id in this.stars ? this.stars[id] : !!serverStarred;
  },
  queueListen(body) {
    this.lbQueue.push(body);
    DB.set('lbQueue', this.lbQueue);
  },
  async flushListens() {
    while (this.lbQueue.length) {
      if (!(await LB.submit(this.lbQueue[0]))) return;
      this.lbQueue.shift();
      DB.set('lbQueue', this.lbQueue);
    }
  },
  cachedMatch(key) {
    return this.matches[key];
  },
  cacheMatch(key, song) {
    this.matches[key] = { song, at: Date.now() };
    DB.set('matches', this.matches);
  },
};

// ---------------- Navidrome (Subsonic API) ----------------

const API = {
  url(endpoint, params = [], creds = null) {
    const c = creds || { server: Settings.serverUrl, user: Settings.username, token: Settings.token, salt: Settings.salt };
    const base = String(c.server).replace(/\/+$/, '');
    const all = [['u', c.user], ['t', c.token], ['s', c.salt], ['v', '1.16.1'], ['c', 'FeynosMusicLinux'], ['f', 'json'], ...params];
    const q = all.filter(([, v]) => v !== undefined && v !== null).map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
    return `${base}/rest/${endpoint}?${q}`;
  },

  async call(endpoint, params = [], creds = null) {
    let res;
    try {
      res = await fetch(this.url(endpoint, params, creds));
    } catch (e) {
      throw new Error("Can't reach the server");
    }
    if (!res.ok) throw new Error(`Server returned HTTP ${res.status}`);
    let body;
    try {
      body = await res.json();
    } catch (e) {
      throw new Error("This doesn't look like a Navidrome server");
    }
    const r = body && body['subsonic-response'];
    if (!r) throw new Error("This doesn't look like a Navidrome server");
    if (r.status !== 'ok') throw new Error((r.error && r.error.message) || 'Server error');
    return r;
  },

  async login(server, user, password) {
    let raw = server.trim().replace(/\/+$/, '');
    const candidates = /^https?:\/\//.test(raw) ? [raw] : [`https://${raw}`, `http://${raw}`];
    const salt = Math.random().toString(36).slice(2, 14);
    const token = window.native.md5(password + salt);
    let last = new Error("Couldn't connect");
    for (const c of candidates) {
      const creds = { server: c, user: user.trim(), token, salt };
      try {
        await this.call('ping', [], creds);
        Object.assign(Settings, { serverUrl: c, username: user.trim(), token, salt });
        saveSettings();
        return;
      } catch (e) {
        last = e;
      }
    }
    throw last;
  },

  list(x) {
    return Array.isArray(x) ? x : x ? [x] : [];
  },

  async albumList(type, size = 30, offset = 0, genre = null) {
    const p = [['type', type], ['size', size], ['offset', offset]];
    if (genre) p.push(['genre', genre]);
    return this.list((await this.call('getAlbumList2', p)).albumList2?.album);
  },
  async album(id) {
    const a = (await this.call('getAlbum', [['id', id]])).album;
    if (!a) throw new Error('Album not found');
    a.song = this.list(a.song);
    return a;
  },
  async artists() {
    const idx = this.list((await this.call('getArtists')).artists?.index);
    return idx.flatMap((i) => this.list(i.artist));
  },
  async artist(id) {
    const a = (await this.call('getArtist', [['id', id]])).artist;
    if (!a) throw new Error('Artist not found');
    a.album = this.list(a.album);
    return a;
  },
  async artistInfo(id) {
    const i = (await this.call('getArtistInfo2', [['id', id], ['count', 20]])).artistInfo2 || {};
    i.similarArtist = this.list(i.similarArtist);
    return i;
  },
  async topSongs(name, count = 20) {
    return this.list((await this.call('getTopSongs', [['artist', name], ['count', count]])).topSongs?.song);
  },
  async similarSongs(id, count = 50) {
    return this.list((await this.call('getSimilarSongs', [['id', id], ['count', count]])).similarSongs?.song);
  },
  async similarSongsForArtist(id, count = 50) {
    return this.list((await this.call('getSimilarSongs2', [['id', id], ['count', count]])).similarSongs2?.song);
  },
  async randomSongs(size = 50, genre = null) {
    const p = [['size', size]];
    if (genre) p.push(['genre', genre]);
    return this.list((await this.call('getRandomSongs', p)).randomSongs?.song);
  },
  async search(q, songCount = 50) {
    const r = (await this.call('search3', [['query', q], ['artistCount', 10], ['albumCount', 20], ['songCount', songCount]])).searchResult3 || {};
    return { artist: this.list(r.artist), album: this.list(r.album), song: this.list(r.song) };
  },
  async genres() {
    return this.list((await this.call('getGenres')).genres?.genre);
  },
  async songsByGenre(g, count = 200) {
    return this.list((await this.call('getSongsByGenre', [['genre', g], ['count', count]])).songsByGenre?.song);
  },
  async playlists() {
    return this.list((await this.call('getPlaylists')).playlists?.playlist);
  },
  async playlist(id) {
    const p = (await this.call('getPlaylist', [['id', id]])).playlist;
    if (!p) throw new Error('Playlist not found');
    p.entry = this.list(p.entry);
    return p;
  },
  async createPlaylist(name, songIds, playlistId = null) {
    const p = [];
    if (name) p.push(['name', name]);
    if (playlistId) p.push(['playlistId', playlistId]);
    songIds.forEach((id) => p.push(['songId', id]));
    await this.call('createPlaylist', p);
  },
  async addToPlaylist(id, songIds) {
    await this.call('updatePlaylist', [['playlistId', id], ...songIds.map((s) => ['songIdToAdd', s])]);
  },
  async removeFromPlaylist(id, index) {
    await this.call('updatePlaylist', [['playlistId', id], ['songIndexToRemove', index]]);
  },
  async deletePlaylist(id) {
    await this.call('deletePlaylist', [['id', id]]);
  },
  async savePlaylist(name, songs) {
    const existing = (await this.playlists()).find((p) => p.name === name);
    if (existing) await this.createPlaylist(null, songs.map((s) => s.id), existing.id);
    else await this.createPlaylist(name, songs.map((s) => s.id));
  },
  async starred() {
    const r = (await this.call('getStarred2')).starred2 || {};
    return { artist: this.list(r.artist), album: this.list(r.album), song: this.list(r.song) };
  },
  async setStar(on, kind, id) {
    const key = kind === 'album' ? 'albumId' : kind === 'artist' ? 'artistId' : 'id';
    await this.call(on ? 'star' : 'unstar', [[key, id]]);
  },
  async scrobble(id, at, submission) {
    await this.call('scrobble', [['id', id], ['time', at], ['submission', submission ? 'true' : 'false']]);
  },
  async lyrics(song) {
    try {
      const list = this.list((await this.call('getLyricsBySongId', [['id', song.id]])).lyricsList?.structuredLyrics);
      const pick = list.find((l) => l.synced) || list[0];
      if (pick && this.list(pick.line).length) return { synced: !!pick.synced, lines: this.list(pick.line).map((l) => ({ start: l.start, value: l.value || '' })) };
    } catch (e) { /* older server */ }
    if (!song.artist) return null;
    try {
      const text = (await this.call('getLyrics', [['artist', song.artist], ['title', song.title]])).lyrics?.value;
      if (!text) return null;
      const raw = text.split(/\r?\n/);
      const timed = [];
      for (const line of raw) {
        const m = line.trim().match(/^\[(\d+):(\d+)(?:[.:](\d+))?\](.*)$/);
        if (m) timed.push({ start: +m[1] * 60000 + +m[2] * 1000 + (m[3] ? +(m[3] + '00').slice(0, 3) : 0), value: m[4].trim() });
      }
      if (timed.length && timed.length >= raw.filter((l) => l.trim()).length / 2) return { synced: true, lines: timed };
      return { synced: false, lines: raw.map((value) => ({ value })) };
    } catch (e) {
      return null;
    }
  },
  coverUrl(id, size = 300) {
    if (!id || !loggedIn()) return null;
    return this.url('getCoverArt', [['id', id], ['size', size]]);
  },
  streamUrl(id) {
    const p = [['id', id]];
    if (Settings.maxBitrate > 0) p.push(['maxBitRate', Settings.maxBitrate]);
    if (Settings.format !== 'raw') p.push(['format', Settings.format]);
    return this.url('stream', p);
  },
};

/** Cover image URL, preferring art found by the cover art finder. */
function artUrl(coverArt, albumId, size = 300) {
  return Store.coverOverride(albumId || albumIdFromCover(coverArt)) || API.coverUrl(coverArt, size);
}

// ---------------- ListenBrainz ----------------

const LB = {
  base: 'https://api.listenbrainz.org',

  async get(path, token = null) {
    const headers = {};
    const t = token || Settings.lbToken;
    if (t) headers.Authorization = `Token ${t}`;
    const res = await fetch(this.base + path, { headers });
    if (res.status === 204 || res.status === 404) return null;
    if (!res.ok) throw new Error(`ListenBrainz returned HTTP ${res.status}`);
    return res.json();
  },
  user() {
    return encodeURIComponent(Settings.lbUser);
  },
  async validate(token) {
    const r = await this.get('/1/validate-token', token.trim());
    return r && r.valid ? r.user_name : null;
  },
  async submit(body) {
    if (!Settings.lbToken) return false;
    try {
      const res = await fetch(this.base + '/1/submit-listens', {
        method: 'POST',
        headers: { Authorization: `Token ${Settings.lbToken}`, 'Content-Type': 'application/json' },
        body: typeof body === 'string' ? body : JSON.stringify(body),
      });
      return res.ok;
    } catch (e) {
      return false;
    }
  },
  listenBody(type, song, at) {
    const info = { media_player: 'Feynos Music Linux', submission_client: 'Feynos Music Linux', submission_client_version: APP_VERSION };
    if (song.duration) info.duration_ms = song.duration * 1000;
    const meta = { artist_name: song.artist || 'Unknown Artist', track_name: song.title || '', additional_info: info };
    if (song.album) meta.release_name = song.album;
    const listen = { track_metadata: meta };
    if (at) listen.listened_at = Math.floor(at / 1000);
    return JSON.stringify({ listen_type: type, payload: [listen] });
  },
  track(m, at) {
    if (!m || !m.track_name) return null;
    return {
      title: m.track_name, artist: m.artist_name || '', album: m.release_name,
      mbid: m.mbid_mapping?.recording_mbid || m.additional_info?.recording_mbid, at,
    };
  },
  async recentListens(count = 100) {
    const r = await this.get(`/1/user/${this.user()}/listens?count=${count}`);
    return (r?.payload?.listens || []).map((l) => this.track(l.track_metadata, l.listened_at * 1000)).filter(Boolean);
  },
  async listenCount() {
    try {
      return (await this.get(`/1/user/${this.user()}/listen-count`))?.payload?.count ?? null;
    } catch (e) {
      return null;
    }
  },
  async topRecordings(range = 'month', count = 50) {
    const r = await this.get(`/1/stats/user/${this.user()}/recordings?range=${range}&count=${count}`);
    return (r?.payload?.recordings || []).map((x) => ({ title: x.track_name, artist: x.artist_name || '', album: x.release_name, mbid: x.recording_mbid, count: x.listen_count || 0 }));
  },
  async topArtists(range = 'month', count = 20) {
    const r = await this.get(`/1/stats/user/${this.user()}/artists?range=${range}&count=${count}`);
    return (r?.payload?.artists || []).map((x) => ({ name: x.artist_name, count: x.listen_count || 0 }));
  },
  async createdFor() {
    const r = await this.get(`/1/user/${this.user()}/playlists/createdfor?count=25`);
    return (r?.playlists || []).map((x) => x.playlist).filter((p) => p && p.identifier)
      .map((p) => ({ mbid: String(p.identifier).replace(/\/+$/, '').split('/').pop(), title: p.title || 'ListenBrainz playlist', date: p.date }));
  },
  async playlist(mbid) {
    const p = (await this.get(`/1/playlist/${encodeURIComponent(mbid)}`))?.playlist;
    if (!p) return null;
    const tracks = (p.track || []).filter((t) => t.title).map((t) => {
      const ident = Array.isArray(t.identifier) ? t.identifier[0] : t.identifier;
      return { title: t.title, artist: t.creator || '', album: t.album, mbid: ident ? String(ident).split('/').pop() : null };
    });
    return { title: p.title || 'ListenBrainz playlist', tracks };
  },
  async cfRecommendations(count = 100) {
    const r = await this.get(`/1/cf/recommendation/user/${this.user()}/recording?count=${count}`);
    return (r?.payload?.mbids || []).map((x) => x.recording_mbid).filter(Boolean);
  },
  async recordingMetadata(mbids) {
    const out = [];
    for (let i = 0; i < mbids.length; i += 25) {
      try {
        const r = await this.get(`/1/metadata/recording/?recording_mbids=${mbids.slice(i, i + 25).join(',')}&inc=artist`);
        for (const [mbid, v] of Object.entries(r || {})) {
          if (v?.recording?.name) out.push({ title: v.recording.name, artist: v.artist?.name || '', album: v.release?.name, mbid });
        }
      } catch (e) { /* skip */ }
    }
    return out;
  },
};

let APP_VERSION = '1.0';
