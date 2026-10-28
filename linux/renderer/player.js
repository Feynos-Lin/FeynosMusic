// Feynos Music for Linux — audio player, queue, scrobbling and system media controls (MPRIS).
'use strict';

const Player = {
  audio: new Audio(),
  queue: [],
  index: 0,
  shuffle: false,
  repeat: 'off', // off | all | one
  unshuffled: null,
  listeners: new Set(),

  // Jam guest mode: what's playing on the host, shown instead of our own player.
  remote: null, // { song, playing, pos, dur, shuffle, repeat, next:[{i,s}], at }

  // scrobbling
  played: 0,
  startedAt: 0,
  submitted: false,
  nowPlayingSent: false,
  lastTick: 0,

  init() {
    const a = this.audio;
    a.preload = 'auto';
    a.volume = Settings.volume ?? 0.9;
    a.addEventListener('ended', () => this.ended());
    a.addEventListener('error', () => {
      if (!this.current()) return;
      toast("Couldn't play that song, skipping");
      setTimeout(() => this.next(), 600);
    });
    ['play', 'pause', 'loadedmetadata', 'durationchange'].forEach((ev) => a.addEventListener(ev, () => this.changed()));
    a.addEventListener('timeupdate', () => this.tick());
    this.setupMediaSession();
    setInterval(() => {
      if (this.remote && this.remote.playing) this.emit();
    }, 500);
  },

  on(fn) {
    this.listeners.add(fn);
  },
  emit() {
    for (const fn of this.listeners) {
      try {
        fn();
      } catch (e) {
        console.error(e);
      }
    }
  },
  changed() {
    this.updateMediaSession();
    this.emit();
  },

  // ---------- state, local or from the jam host ----------

  current() {
    if (this.remote) return this.remote.song || null;
    return this.queue[this.index] || null;
  },
  isPlaying() {
    if (this.remote) return !!this.remote.playing;
    return !this.audio.paused && !!this.current();
  },
  position() {
    if (this.remote) {
      const p = this.remote.pos + (this.remote.playing ? Date.now() - this.remote.at : 0);
      return Math.min(p, this.remote.dur || p) / 1000;
    }
    return this.audio.currentTime || 0;
  },
  duration() {
    if (this.remote) return (this.remote.dur || 0) / 1000;
    const d = this.audio.duration;
    return isFinite(d) && d > 0 ? d : (this.current()?.duration || 0);
  },
  upNext() {
    if (this.remote) return this.remote.next.map((n) => ({ i: n.i, song: n.s }));
    return this.queue.map((song, i) => ({ i, song })).slice(this.index + 1);
  },
  shuffleOn() {
    return this.remote ? this.remote.shuffle : this.shuffle;
  },
  repeatMode() {
    return this.remote ? this.remote.repeat : this.repeat;
  },

  // ---------- commands ----------

  play(songs, start = 0, shuffle = false) {
    if (!songs || !songs.length) return;
    if (Jam.isGuest() || (Jam.isHost() && this.queue.length)) {
      const picked = shuffle ? shuffled(songs) : songs.slice(Math.max(0, Math.min(start, songs.length - 1)));
      if (Jam.isGuest()) return Jam.command('play', { songs: picked });
      Jam.noteLocal(picked);
      this.insert(picked, null, true);
      return;
    }
    if (shuffle) {
      this.unshuffled = songs.slice();
      this.queue = shuffled(songs);
      this.index = 0;
    } else {
      this.unshuffled = null;
      this.queue = songs.slice();
      this.index = Math.max(0, Math.min(start, songs.length - 1));
    }
    this.shuffle = shuffle;
    this.load(true);
  },

  insert(songs, at, jump) {
    if (!songs.length) return this.index + 1;
    if (!this.queue.length) {
      this.queue = songs.slice();
      this.index = 0;
      this.unshuffled = null;
      this.load(true);
      return songs.length;
    }
    const pos = Math.max(0, Math.min(at == null ? this.index + 1 : at, this.queue.length));
    this.queue.splice(pos, 0, ...songs);
    if (this.unshuffled) this.unshuffled.push(...songs);
    if (pos <= this.index && !jump) this.index += songs.length;
    if (jump) {
      this.index = pos;
      this.load(true);
    } else {
      this.emit();
    }
    return pos + songs.length;
  },

  playNext(songs) {
    if (Jam.isGuest()) return Jam.command('playNext', { songs });
    Jam.noteLocal(songs);
    this.insert(songs, null, false);
  },

  addToQueue(songs) {
    if (Jam.isGuest()) return Jam.command('add', { songs });
    Jam.noteLocal(songs);
    this.insert(songs, Number.MAX_SAFE_INTEGER, false);
  },

  toggle() {
    if (Jam.isGuest()) {
      if (this.remote) {
        this.remote.pos = this.position() * 1000;
        this.remote.at = Date.now();
        this.remote.playing = !this.remote.playing;
        this.emit();
      }
      return Jam.command('toggle');
    }
    if (!this.current()) return;
    if (this.audio.paused) {
      if (!this.audio.src) this.load(true);
      else this.audio.play().catch(() => {});
    } else {
      this.audio.pause();
    }
  },

  next() {
    if (Jam.isGuest()) return Jam.command('next');
    if (!this.queue.length) return;
    if (this.index + 1 < this.queue.length) this.index++;
    else if (this.repeat === 'all') this.index = 0;
    else return;
    this.load(true);
  },

  previous() {
    if (Jam.isGuest()) return Jam.command('previous');
    if (!this.queue.length) return;
    if (this.audio.currentTime > 4 || this.index === 0) this.seek(0);
    else {
      this.index--;
      this.load(true);
    }
  },

  seek(sec) {
    if (Jam.isGuest()) {
      if (this.remote) {
        this.remote.pos = sec * 1000;
        this.remote.at = Date.now();
        this.emit();
      }
      return Jam.command('seek', { ms: Math.round(sec * 1000) });
    }
    if (isFinite(sec)) this.audio.currentTime = Math.max(0, sec);
    this.changed();
  },

  skipTo(i) {
    if (Jam.isGuest()) return Jam.command('skipTo', { a: i });
    if (i < 0 || i >= this.queue.length) return;
    this.index = i;
    this.load(true);
  },

  removeAt(i) {
    if (Jam.isGuest()) return Jam.command('remove', { a: i });
    if (i < 0 || i >= this.queue.length || i === this.index) return;
    this.queue.splice(i, 1);
    if (i < this.index) this.index--;
    this.emit();
  },

  move(from, to) {
    if (Jam.isGuest()) return Jam.command('move', { a: from, b: to });
    if ([from, to].some((x) => x < 0 || x >= this.queue.length) || from === this.index || to === this.index) return;
    const [s] = this.queue.splice(from, 1);
    this.queue.splice(to, 0, s);
    this.emit();
  },

  clearUpNext() {
    if (Jam.isGuest()) return Jam.command('clear');
    const cur = this.current();
    if (!cur) return;
    this.queue = [cur];
    this.index = 0;
    this.unshuffled = null;
    this.emit();
  },

  toggleShuffle() {
    if (Jam.isGuest()) return Jam.command('shuffle');
    const cur = this.current();
    if (this.shuffle) {
      if (this.unshuffled && cur) {
        this.queue = this.unshuffled;
        this.index = Math.max(0, this.queue.findIndex((s) => s.id === cur.id));
      }
      this.unshuffled = null;
      this.shuffle = false;
    } else {
      this.unshuffled = this.queue.slice();
      if (cur) {
        const rest = shuffled(this.queue.filter((_, i) => i !== this.index));
        this.queue = [cur, ...rest];
        this.index = 0;
      }
      this.shuffle = true;
    }
    this.emit();
  },

  cycleRepeat() {
    if (Jam.isGuest()) return Jam.command('repeat');
    this.repeat = this.repeat === 'off' ? 'all' : this.repeat === 'all' ? 'one' : 'off';
    this.emit();
  },

  setVolume(v) {
    this.audio.volume = Math.max(0, Math.min(1, v));
    Settings.volume = this.audio.volume;
    saveSettings();
    this.emit();
  },

  stop() {
    this.audio.pause();
    this.audio.removeAttribute('src');
    this.audio.load();
    this.queue = [];
    this.index = 0;
    this.emit();
  },

  // ---------- jam guest ----------

  setRemote(state) {
    if (!this.remote) this.audio.pause();
    this.remote = state;
    this.updateMediaSession();
    this.emit();
  },
  clearRemote() {
    this.remote = null;
    this.updateMediaSession();
    this.emit();
  },

  // ---------- internals ----------

  load(autoplay) {
    const song = this.current();
    if (!song) return;
    this.audio.src = API.streamUrl(song.id);
    this.played = 0;
    this.startedAt = Date.now();
    this.submitted = false;
    this.nowPlayingSent = false;
    this.lastTick = 0;
    if (autoplay) this.audio.play().catch(() => {});
    this.changed();
  },

  ended() {
    if (this.repeat === 'one') {
      this.audio.currentTime = 0;
      this.played = 0;
      this.startedAt = Date.now();
      this.submitted = false;
      this.audio.play().catch(() => {});
      return;
    }
    if (this.index + 1 < this.queue.length) {
      this.index++;
      this.load(true);
    } else if (this.repeat === 'all' && this.queue.length) {
      this.index = 0;
      this.load(true);
    } else {
      this.changed();
    }
  },

  tick() {
    const now = Date.now();
    if (!this.audio.paused) {
      if (this.lastTick) this.played += Math.min(2, (now - this.lastTick) / 1000);
      const song = this.current();
      if (song && !this.nowPlayingSent) this.sendNowPlaying(song);
      if (song && !this.submitted) {
        const total = this.duration();
        const threshold = total > 0 ? Math.min(total / 2, 240) : 240;
        if (this.played >= threshold && this.played >= 10) {
          this.submitted = true;
          const guest = Jam.creditFor(song.id);
          if (guest) Jam.sendListen(guest, song, this.startedAt);
          else recordListen(song, this.startedAt);
        }
      }
    }
    this.lastTick = this.audio.paused ? 0 : now;
    this.emit();
  },

  sendNowPlaying(song) {
    this.nowPlayingSent = true;
    const guest = Jam.creditFor(song.id);
    if (guest) return Jam.sendNowPlaying(guest, song);
    sendNowPlaying(song);
  },

  setupMediaSession() {
    if (!('mediaSession' in navigator)) return;
    const ms = navigator.mediaSession;
    const set = (a, fn) => {
      try {
        ms.setActionHandler(a, fn);
      } catch (e) { /* unsupported */ }
    };
    set('play', () => { if (!this.isPlaying()) this.toggle(); });
    set('pause', () => { if (this.isPlaying()) this.toggle(); });
    set('nexttrack', () => this.next());
    set('previoustrack', () => this.previous());
    set('seekto', (d) => this.seek(d.seekTime));
    set('seekbackward', () => this.seek(this.position() - 10));
    set('seekforward', () => this.seek(this.position() + 10));
  },

  updateMediaSession() {
    if (!('mediaSession' in navigator)) return;
    const s = this.current();
    if (!s) {
      navigator.mediaSession.metadata = null;
      return;
    }
    const art = artUrl(s.coverArt, s.albumId, 512);
    navigator.mediaSession.metadata = new MediaMetadata({
      title: s.title || '', artist: s.artist || '', album: s.album || '',
      artwork: art ? [{ src: art, sizes: '512x512' }] : [],
    });
    navigator.mediaSession.playbackState = this.isPlaying() ? 'playing' : 'paused';
  },
};

/** Navidrome + ListenBrainz "now playing". */
function sendNowPlaying(song) {
  if (Settings.scrobbleNavidrome) API.scrobble(song.id, Date.now(), false).catch(() => {});
  if (Settings.scrobbleLb && Settings.lbToken) LB.submit(LB.listenBody('playing_now', song, null));
}

/** A finished listen: local history, Navidrome play count, ListenBrainz (queued if offline). */
async function recordListen(song, at) {
  Store.addPlay(song, at);
  if (Settings.scrobbleNavidrome) API.scrobble(song.id, at, true).catch(() => {});
  if (Settings.scrobbleLb && Settings.lbToken) {
    const body = LB.listenBody('single', song, at);
    if (await LB.submit(body)) Store.flushListens();
    else Store.queueListen(body);
  }
}
