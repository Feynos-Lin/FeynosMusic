// Feynos Music for Linux — music visualizer (bars, wave, circle), drawn from the audio itself.
'use strict';

const VIS_STYLES = ['off', 'bars', 'wave', 'circle'];
const VIS_LABEL = { off: 'Off', bars: 'Bars', wave: 'Wave', circle: 'Circle' };
const BANDS = 64;

const Visualizer = {
  canvas: null,
  raf: 0,
  shown: new Float32Array(BANDS),

  next(style) {
    return VIS_STYLES[(VIS_STYLES.indexOf(style) + 1) % VIS_STYLES.length];
  },

  attach(canvas) {
    this.stop();
    this.canvas = canvas;
    const loop = () => {
      this.draw();
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);
  },

  stop() {
    cancelAnimationFrame(this.raf);
    this.raf = 0;
    this.canvas = null;
  },

  bands(an, freq) {
    an.getByteFrequencyData(freq);
    const out = new Float32Array(BANDS);
    const rate = (Player.ctx && Player.ctx.sampleRate) || 44100;
    const n = freq.length;
    const lo = 40, hi = Math.min(16000, rate / 2);
    for (let b = 0; b < BANDS; b++) {
      const f0 = lo * Math.pow(hi / lo, b / BANDS), f1 = lo * Math.pow(hi / lo, (b + 1) / BANDS);
      const i0 = Math.max(1, Math.floor((f0 / (rate / 2)) * n));
      const i1 = Math.max(i0 + 1, Math.floor((f1 / (rate / 2)) * n));
      let peak = 0;
      for (let i = i0; i < i1 && i < n; i++) peak = Math.max(peak, freq[i]);
      out[b] = peak / 255;
    }
    return out;
  },

  draw() {
    const c = this.canvas;
    if (!c || !c.isConnected) return this.stop();
    const dpr = window.devicePixelRatio || 1;
    const w = c.clientWidth * dpr, h = c.clientHeight * dpr;
    if (c.width !== w || c.height !== h) {
      c.width = w;
      c.height = h;
    }
    const g = c.getContext('2d');
    g.clearRect(0, 0, w, h);
    const style = Settings.visualizer;
    const css = getComputedStyle(document.documentElement);
    const accent = css.getPropertyValue('--accent').trim() || '#a970ff';
    const local = !Player.remote && Player.isPlaying();
    const an = local ? Player.analyserNode() : null;
    let target = new Float32Array(BANDS);
    let wave = null;
    if (an) {
      target = this.bands(an, new Uint8Array(an.frequencyBinCount));
      wave = new Float32Array(an.fftSize);
      an.getFloatTimeDomainData(wave);
    }
    for (let i = 0; i < BANDS; i++) {
      const t = target[i], s = this.shown[i];
      this.shown[i] = t > s ? s + (t - s) * 0.6 : s - (s - t) * 0.12;
    }
    const grad = g.createLinearGradient(0, h, 0, 0);
    grad.addColorStop(0, accent);
    grad.addColorStop(1, '#ffffff');
    if (style === 'bars') {
      const gap = (w / BANDS) * 0.25, bw = w / BANDS - gap;
      g.fillStyle = grad;
      for (let i = 0; i < BANDS; i++) {
        const bh = Math.max(3 * dpr, this.shown[i] * h * 0.9);
        const x = i * (bw + gap) + gap / 2;
        g.beginPath();
        g.roundRect(x, h - bh, bw, bh, bw / 2);
        g.fill();
      }
    } else if (style === 'wave') {
      const level = this.shown.reduce((a, b) => a + b, 0) / BANDS;
      g.lineJoin = 'round';
      for (const [lw, alpha] of [[14 * dpr, 0.3], [4 * dpr, 1]]) {
        g.beginPath();
        g.lineWidth = lw;
        g.strokeStyle = accent;
        g.globalAlpha = alpha;
        const pts = 256;
        for (let i = 0; i < pts; i++) {
          const v = wave ? wave[Math.floor((i / pts) * Math.min(wave.length, 1024))] : 0;
          const x = (w * i) / (pts - 1), y = h / 2 - v * h * 0.45 * (0.6 + level);
          if (i) g.lineTo(x, y); else g.moveTo(x, y);
        }
        g.stroke();
      }
      g.globalAlpha = 1;
    } else if (style === 'circle') {
      const cx = w / 2, cy = h / 2, m = Math.min(w, h);
      const r0 = m * 0.23, maxLen = m * 0.25, n = BANDS * 2;
      g.strokeStyle = accent;
      g.lineCap = 'round';
      g.lineWidth = 6 * dpr;
      for (let i = 0; i < n; i++) {
        const v = this.shown[i < BANDS ? i : n - 1 - i];
        const a = (2 * Math.PI * i) / n - Math.PI / 2, len = 4 * dpr + v * maxLen;
        g.beginPath();
        g.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0);
        g.lineTo(cx + Math.cos(a) * (r0 + len), cy + Math.sin(a) * (r0 + len));
        g.stroke();
      }
    }
  },
};
