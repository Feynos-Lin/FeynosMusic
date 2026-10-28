// Feynos Music for Linux — ListenBrainz matching, weekly mixes and the cover art finder.
'use strict';

const Matcher = {
  score(s, t) {
    if (t.mbid && s.musicBrainzId === t.mbid) return 100;
    const st = norm(s.title), tt = norm(t.title);
    if (!st || !tt) return 0;
    let sc;
    if (st === tt) sc = 50;
    else if (st.startsWith(tt) || tt.startsWith(st)) sc = 35;
    else if (st.includes(tt) || tt.includes(st)) sc = 25;
    else return 0;
    const sa = norm(s.artist), a = norm(t.artist);
    if (sa && a) {
      if (sa === a) sc += 50;
      else if (a.includes(sa) || sa.includes(a)) sc += 40;
      else if (a.split(' ').some((w) => w.length > 2 && sa.includes(w))) sc += 20;
    }
    return sc;
  },

  async match(t) {
    const key = norm(t.artist) + '|' + norm(t.title);
    const c = Store.cachedMatch(key);
    if (c && (c.song || Date.now() - c.at < 7 * 86400000)) return c.song;
    const first = String(t.artist || '').split(/,|&| feat\.| ft\./i)[0].trim();
    let best = null, bestScore = 0;
    for (const q of [...new Set([`${cleanTitle(t.title)} ${first}`, cleanTitle(t.title)])]) {
      let res;
      try {
        res = (await API.search(q, 25)).song;
      } catch (e) {
        return null;
      }
      for (const s of res) {
        const sc = this.score(s, t);
        if (sc > bestScore) {
          bestScore = sc;
          best = s;
        }
      }
      if (bestScore >= 85) break;
    }
    const result = bestScore >= 60 ? best : null;
    Store.cacheMatch(key, result);
    return result;
  },

  async matchAll(tracks, onEach) {
    const out = new Array(tracks.length).fill(null);
    let next = 0;
    const worker = async () => {
      while (next < tracks.length) {
        const i = next++;
        out[i] = await this.match(tracks[i]);
        if (onEach) onEach(i, out[i]);
      }
    };
    await Promise.all([worker(), worker(), worker(), worker()]);
    return out;
  },
};

const Mixes = {
  generating: false,

  async maybeGenerate() {
    if (loggedIn() && Date.now() - (Settings.lastMixGen || 0) > 7 * 86400000) await this.generate(true);
  },

  async generate(quiet = false) {
    if (this.generating) return;
    this.generating = true;
    UI.refresh();
    const safe = async (p, fb) => {
      try {
        return await p;
      } catch (e) {
        return fb;
      }
    };
    try {
      const day = 86400000, now = Date.now();
      const played = Store.playedIds();
      const onRepeat = Store.topSongs(now - 30 * day, 40).map((x) => x[0]);
      const allTop = Store.topSongs(0, 300).map((x) => x[0]);
      const topArtists = Store.topArtists(now - 90 * day, 8);
      const lbOn = lbConnected();
      const lbTop = lbOn ? await safe(LB.topRecordings('month', 40), []) : [];
      const lbTopSongs = (await Matcher.matchAll(lbTop)).filter(Boolean);
      const lbRefs = lbOn ? await safe(LB.createdFor(), []) : [];

      const result = [];
      const add = (id, title, description, songs, min = 5) => {
        const list = uniqueById(songs);
        if (list.length >= min) result.push({ id, title, description, createdAt: now, coverArt: (list.find((s) => s.coverArt) || {}).coverArt, songs: list });
      };
      const interleave = (...lists) => {
        const out = [];
        const m = Math.max(0, ...lists.map((l) => l.length));
        for (let i = 0; i < m; i++) for (const l of lists) if (i < l.length) out.push(l[i]);
        return out;
      };

      // Weekly Mix
      let similarPool = [];
      for (const a of topArtists.slice(0, 5)) {
        const seed = onRepeat.find((s) => s.artist === a.name) || allTop.find((s) => s.artist === a.name);
        if (seed) similarPool.push(...(await safe(API.similarSongs(seed.id, 15), [])));
      }
      if (similarPool.length < 10) for (const a of topArtists.slice(0, 5)) similarPool.push(...(await safe(API.topSongs(a.name, 6), [])));
      add('weekly', 'Weekly Mix', 'Your favourites mixed with songs like them. Refreshed every week.',
        interleave(shuffled(onRepeat).slice(0, 15), shuffled(lbTopSongs).slice(0, 12), shuffled(similarPool).slice(0, 25)).slice(0, 50));

      // Discover Weekly
      const discover = [];
      const exploration = lbRefs.find((r) => /exploration/i.test(r.title));
      if (exploration) {
        const pl = await safe(LB.playlist(exploration.mbid), null);
        if (pl) discover.push(...(await Matcher.matchAll(pl.tracks.slice(0, 50))).filter(Boolean));
      }
      if (lbOn) {
        const recs = await safe(LB.cfRecommendations(80), []);
        if (recs.length) discover.push(...(await Matcher.matchAll(await LB.recordingMetadata(recs.slice(0, 50)))).filter(Boolean));
      }
      for (const a of topArtists.slice(0, 6)) {
        if (!a.id) continue;
        const info = await safe(API.artistInfo(a.id), null);
        for (const sim of ((info && info.similarArtist) || []).filter((x) => x.id).slice(0, 4)) {
          const artist = await safe(API.artist(sim.id), null);
          const al = artist && artist.album.length ? artist.album[Math.floor(Math.random() * artist.album.length)] : null;
          if (!al) continue;
          const full = await safe(API.album(al.id), null);
          if (full) discover.push(...shuffled(full.song).slice(0, 2));
        }
      }
      for (const seed of onRepeat.slice(0, 5)) discover.push(...(await safe(API.similarSongs(seed.id, 10), [])));
      let unheard = uniqueById(discover).filter((s) => !played.has(s.id));
      if (unheard.length < 25) unheard = unheard.concat((await safe(API.randomSongs(150), [])).filter((s) => !played.has(s.id)).slice(0, 35 - unheard.length));
      add('discover', 'Discover Weekly', "Songs from your library you haven't played yet, picked for you.", shuffled(unheard).slice(0, 40));

      // Artist mixes
      for (const [i, a] of topArtists.slice(0, 3).entries()) {
        const pool = allTop.filter((s) => s.artist === a.name).slice(0, 10);
        pool.push(...(await safe(API.topSongs(a.name, 10), [])));
        if (a.id) pool.push(...(await safe(API.similarSongsForArtist(a.id, 30), [])));
        add(`artist_${i}`, `${a.name} Mix`, `${a.name} and artists like them.`, shuffled(uniqueById(pool)).slice(0, 40), 8);
      }

      add('repeat', 'On Repeat', "The songs you can't stop playing right now.", onRepeat.slice(0, 30));
      add('gems', 'Forgotten Gems', "Old favourites you haven't played in a while.", shuffled(Store.forgotten(now - 60 * day, 3, 30)));

      const fresh = [];
      for (const al of await safe(API.albumList('newest', 12), [])) {
        const full = await safe(API.album(al.id), null);
        if (full) fresh.push(...shuffled(full.song.filter((s) => !played.has(s.id))).slice(0, 3));
      }
      add('fresh', 'Fresh Finds', "New additions to your library you haven't heard yet.", fresh.slice(0, 40));

      for (const ref of lbRefs.slice(0, 4)) {
        const pl = await safe(LB.playlist(ref.mbid), null);
        if (!pl) continue;
        const songs = (await Matcher.matchAll(pl.tracks.slice(0, 60))).filter(Boolean);
        add(`lb_${ref.mbid}`, pl.title.split(' for ')[0].trim() || pl.title, 'From ListenBrainz, matched to your library.', songs);
      }

      Store.saveMixes(result);
      if (Settings.syncMixes) for (const m of result) await safe(API.savePlaylist(`Feynos · ${m.title}`, m.songs), null);
      Settings.lastMixGen = now;
      saveSettings();
      if (!quiet) toast(`Made ${result.length} mixes for you`);
    } catch (e) {
      if (!quiet) toast(`Couldn't make mixes: ${e.message}`);
    } finally {
      this.generating = false;
      UI.refresh();
    }
    if (Settings.autoCovers) Covers.scan(false, true);
  },
};

const Covers = {
  running: false,
  phase: '',
  done: 0,
  total: 0,
  found: 0,
  cancelled: false,
  lastMb: 0,

  async json(url) {
    try {
      const res = await fetch(url, { headers: { Accept: 'application/json' } });
      return res.ok ? await res.json() : null;
    } catch (e) {
      return null;
    }
  },
  q(s) {
    return String(s || '').replace(/"/g, '');
  },
  async deezer(artist, album) {
    const query = artist ? `artist:"${this.q(artist)}" album:"${this.q(album)}"` : `album:"${this.q(album)}"`;
    const r = await this.json(`https://api.deezer.com/search/album?limit=6&q=${encodeURIComponent(query)}`);
    return ((r && r.data) || []).filter((d) => (d.cover_xl || d.cover_big) && !String(d.cover_xl).includes('/images/cover//'))
      .map((d) => ({ url: d.cover_xl || d.cover_big, thumb: d.cover_medium || d.cover_xl, source: 'Deezer', title: d.title || '', artist: (d.artist && d.artist.name) || '' }));
  },
  async itunes(artist, album) {
    const r = await this.json(`https://itunes.apple.com/search?entity=album&limit=6&term=${encodeURIComponent(`${artist} ${album}`.trim())}`);
    return ((r && r.results) || []).filter((d) => d.artworkUrl100).map((d) => ({
      url: d.artworkUrl100.replace('100x100bb', '1000x1000bb'), thumb: d.artworkUrl100.replace('100x100bb', '300x300bb'),
      source: 'iTunes', title: d.collectionName || '', artist: d.artistName || '',
    }));
  },
  async musicBrainz(artist, album) {
    const wait = 1100 - (Date.now() - this.lastMb);
    if (wait > 0) await sleep(wait);
    this.lastMb = Date.now();
    const query = artist ? `releasegroup:"${this.q(album)}" AND artist:"${this.q(artist)}"` : `releasegroup:"${this.q(album)}"`;
    const r = await this.json(`https://musicbrainz.org/ws/2/release-group/?fmt=json&limit=5&query=${encodeURIComponent(query)}`);
    return ((r && r['release-groups']) || []).filter((g) => (g.score || 0) >= 80).map((g) => ({
      url: `https://coverartarchive.org/release-group/${g.id}/front-1200`, thumb: `https://coverartarchive.org/release-group/${g.id}/front-250`,
      source: 'Cover Art Archive', title: g.title || '', artist: (g['artist-credit'] && g['artist-credit'][0] && g['artist-credit'][0].name) || '',
    }));
  },
  async exists(url) {
    try {
      return (await fetch(url, { method: 'HEAD' })).ok;
    } catch (e) {
      return false;
    }
  },
  async candidates(artist, album) {
    return [...(await this.musicBrainz(artist, album)), ...(await this.deezer(artist, album)), ...(await this.itunes(artist, album))];
  },
  // Words that differ between your tags and the stores: "(Explicit)", "Deluxe Edition", "Remastered"...
  NOISE: /\b(deluxe|expanded|explicit|clean|remaster(ed)?|anniversary|special|super|edition|version|bonus|tracks?|reissue|complete)\b/gi,
  RETRY_MS: 86400000, // albums with no match are tried again after a day

  /** "For All The Dogs (Explicit) [Deluxe Edition] - Remastered" -> "For All The Dogs" */
  simplify(album) {
    const a = cleanTitle(album).replace(/\s+[-–:]\s+.*$/, '').replace(this.NOISE, ' ').replace(/\s+/g, ' ').trim();
    return a || album;
  },
  coverNorm(s) {
    return norm(s).replace(this.NOISE, ' ').replace(/\s+/g, ' ').trim();
  },
  sameName(a, b) {
    const x = this.coverNorm(a), y = this.coverNorm(b);
    if (!x || !y) return false;
    return x === y || (x.length >= 3 && y.includes(x)) || (y.length >= 3 && x.includes(y));
  },

  /** Plain keyword search: forgives punctuation and small spelling differences. */
  async deezerLoose(artist, album) {
    const r = await this.json(`https://api.deezer.com/search/album?limit=10&q=${encodeURIComponent(`${artist} ${album}`.trim())}`);
    return ((r && r.data) || []).filter((d) => (d.cover_xl || d.cover_big) && !String(d.cover_xl).includes('/images/cover//'))
      .map((d) => ({ url: d.cover_xl || d.cover_big, thumb: d.cover_medium || d.cover_xl, source: 'Deezer', title: d.title || '', artist: (d.artist && d.artist.name) || '' }));
  },

  async bestMatch(artist, album) {
    const ok = (c) => this.sameName(c.title, album) && (!artist || !c.artist || this.sameName(c.artist, artist));
    const simple = this.simplify(album);
    const names = [...new Set([album, simple])];
    for (const n of names) { const d = (await this.deezer(artist, n)).find(ok); if (d) return d; }
    for (const n of names) { const d = (await this.deezerLoose(artist, n)).find(ok); if (d) return d; }
    for (const n of names) { const d = (await this.itunes(artist, n)).find(ok); if (d) return d; }
    for (const c of (await this.musicBrainz(artist, simple)).filter(ok)) if (await this.exists(c.thumb)) return c;
    // Last try: album name only, but the artist must still agree.
    if (!artist) return null;
    return (await this.deezer('', simple)).find((c) => ok(c) && this.sameName(c.artist, artist)) || null;
  },

  // ---- On-demand lookups: a cover that fails to load is looked up right away. ----
  asked: new Map(),
  queue: [],
  working: false,

  requestLookup(albumId) {
    if (!albumId || !Settings.autoCovers || Store.coverOverride(albumId)) return;
    const last = this.asked.get(albumId);
    if (last && Date.now() - last < this.RETRY_MS) return;
    this.asked.set(albumId, Date.now());
    this.queue.push(albumId);
    if (!this.working) this.work();
  },

  async work() {
    this.working = true;
    while (this.queue.length) {
      const id = this.queue.shift();
      try {
        await this.lookupOne(id);
      } catch (e) { /* offline or server error: try again after the retry window */ }
    }
    this.working = false;
  },

  async lookupOne(id) {
    const now = Date.now();
    const old = Store.covers[id];
    if (old && (old.url || (old.missing && now - (old.checkedAt || 0) < this.RETRY_MS))) return;
    const album = await API.album(id);
    const best = await this.bestMatch(album.artist || '', album.name);
    Store.setCover(id, { name: album.name, artist: album.artist || '', coverArt: album.coverArt, hash: (old && old.hash) || 'none', missing: true, checkedAt: now, url: best ? best.url : null, source: best ? best.source : null });
    if (best) {
      // Swap the new art into any covers of this album already on screen.
      document.querySelectorAll(`img[data-album="${CSS.escape(id)}"]`).forEach((el) => { el.src = best.url; });
      UI.refresh();
    }
  },
  set(album, url, source) {
    Store.setCover(album.id, { name: album.name, artist: album.artist || '', coverArt: album.coverArt, url, source, checkedAt: Date.now() });
    UI.refresh();
  },
  async hashOf(url) {
    if (!url) return null;
    try {
      const res = await fetch(url);
      if (!res.ok) return null;
      const data = await res.arrayBuffer();
      // An image that can't be decoded shows as a blank square, so treat it as missing.
      try {
        (await createImageBitmap(new Blob([data]))).close();
      } catch (e) {
        return null;
      }
      const buf = await crypto.subtle.digest('SHA-1', data);
      return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
    } catch (e) {
      return null;
    }
  },
  stop() {
    this.cancelled = true;
  },

  /** Finds albums showing only the server's placeholder and looks up real covers online. */
  async scan(full, quiet = false) {
    if (this.running) return;
    Object.assign(this, { running: true, cancelled: false, found: 0, done: 0, total: 0, phase: 'Loading albums' });
    UI.refresh();
    try {
      const albums = [];
      for (let off = 0; ; off += 500) {
        const page = await API.albumList('alphabeticalByName', 500, off);
        albums.push(...page);
        if (page.length < 500) break;
      }
      const entries = Store.covers;
      this.phase = 'Checking artwork';
      this.total = albums.length;
      for (const [i, al] of albums.entries()) {
        if (this.cancelled) break;
        this.done = i + 1;
        if (i % 20 === 0) UI.refresh();
        const old = entries[al.id];
        if (!full && old && old.hash && old.coverArt === al.coverArt) continue;
        const h = al.coverArt ? (await this.hashOf(API.coverUrl(al.coverArt, 64))) || 'none' : 'none';
        entries[al.id] = Object.assign(old || {}, { name: al.name, artist: al.artist || '', coverArt: al.coverArt, hash: h });
      }
      const present = new Set(albums.map((a) => a.id));
      const live = Object.entries(entries).filter(([id]) => present.has(id));
      const fake = await this.hashOf(API.coverUrl('al-feynos-missing-cover-check', 64));
      const groups = {};
      for (const [, e] of live) if (e.hash) (groups[e.hash] = groups[e.hash] || []).push(e);
      const placeholders = new Set(['none']);
      if (fake) placeholders.add(fake);
      for (const [h, list] of Object.entries(groups)) if (list.length >= 3 && new Set(list.map((e) => e.artist)).size >= 2) placeholders.add(h);

      for (const [, e] of live) {
        if (!placeholders.has(e.hash) && e.missing) {
          e.missing = false;
          if (e.source !== 'manual') {
            e.url = null;
            e.source = null;
          }
        }
      }
      const missing = live.filter(([, e]) => placeholders.has(e.hash));
      this.phase = 'Finding artwork online';
      this.total = missing.length;
      this.done = 0;
      const now = Date.now();
      for (const [i, [, e]] of missing.entries()) {
        if (this.cancelled) break;
        this.done = i + 1;
        UI.refresh();
        const recentlyFailed = e.missing && !e.url && now - (e.checkedAt || 0) < this.RETRY_MS;
        if (!full && (e.url || recentlyFailed)) continue;
        const best = await this.bestMatch(e.artist, e.name);
        e.missing = true;
        e.checkedAt = now;
        if (best) {
          e.url = best.url;
          e.source = best.source;
          this.found++;
        }
        Store.saveCovers();
      }
      Store.saveCovers();
      if (!quiet) toast(this.found ? `Found cover art for ${this.found} albums` : 'No new cover art found');
    } catch (e) {
      if (!quiet) toast(`Cover scan stopped: ${e.message}`);
    } finally {
      this.running = false;
      this.phase = '';
      UI.refresh();
    }
  },
};
