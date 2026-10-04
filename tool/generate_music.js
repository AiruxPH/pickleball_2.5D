// Generates an ORIGINAL seamless background-music loop for the game:
//   assets/audio/background_loop.wav
//
// Everything (chords, bass line, arpeggio, drums, melody) is composed and
// synthesized here from scratch — no samples or existing recordings.
//
// Run from the project root:  node tool/generate_music.js

const fs = require('fs');
const path = require('path');

const SR = 22050;          // sample rate (keeps the file small)
const BPM = 118;
const BEAT = 60 / BPM;
const BARS = 16;
const TOTAL = Math.round(BARS * 4 * BEAT * SR);
const out = new Float32Array(TOTAL);

// Deterministic RNG so the file is reproducible
let seed = 20260928;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);

const midiHz = (m) => 440 * Math.pow(2, (m - 69) / 12);

// Write a sample with loop wrap-around so note tails continue at the start
function add(i, v) { out[((i % TOTAL) + TOTAL) % TOTAL] += v; }

// ── Instruments ──────────────────────────────────────────────
function tone(startSec, durSec, midi, vol, shape, attack = 0.005, release = 0.08) {
  const f = midiHz(midi);
  const n = Math.round((durSec + release) * SR);
  const s0 = Math.round(startSec * SR);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const env = t < attack ? t / attack
      : t < durSec ? 1
      : Math.max(0, 1 - (t - durSec) / release);
    phase += f / SR;
    const p = phase % 1;
    let w;
    switch (shape) {
      case 'pulse': w = (p < 0.25 ? 1 : -1) * 0.6; break;                  // bright lead
      case 'tri': w = 4 * Math.abs(p - 0.5) - 1; break;                     // soft bass
      case 'saw': w = (2 * p - 1) * 0.5 + Math.sin(2 * Math.PI * p) * 0.3; break;
      default: w = Math.sin(2 * Math.PI * p);
    }
    add(s0 + i, w * env * vol);
  }
}

function kick(startSec) {
  const n = Math.round(0.22 * SR), s0 = Math.round(startSec * SR);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    phase += (48 + 110 * Math.exp(-t * 32)) / SR;
    add(s0 + i, Math.sin(2 * Math.PI * phase) * Math.exp(-t * 14) * 0.55);
  }
}

function snare(startSec) {
  const n = Math.round(0.16 * SR), s0 = Math.round(startSec * SR);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const noise = (rnd() * 2 - 1) * Math.exp(-t * 26);
    const body = Math.sin(2 * Math.PI * 190 * t) * Math.exp(-t * 30);
    add(s0 + i, (noise * 0.28 + body * 0.18));
  }
}

function hat(startSec, vol) {
  const n = Math.round(0.035 * SR), s0 = Math.round(startSec * SR);
  let prev = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const w = rnd() * 2 - 1;
    const hp = w - prev; prev = w;             // crude high-pass → crisp tick
    add(s0 + i, hp * Math.exp(-t * 120) * vol);
  }
}

// ── Composition ──────────────────────────────────────────────
// Chords as MIDI note sets (root position triads around C4)
const CH = {
  C: [60, 64, 67], Am: [57, 60, 64], F: [53, 57, 60], G: [55, 59, 62],
  Em: [52, 55, 59], Dm: [50, 53, 57],
};
const progression = [
  'C', 'G', 'Am', 'F',   'C', 'G', 'F', 'G',
  'Am', 'Em', 'F', 'C',  'Dm', 'F', 'G', 'G',
];

// Hand-written melody motif (scale degrees of C major, per 8th note; null = rest)
// Two 4-bar phrases, each played twice with the second half varied.
const phraseA = [
  7, null, 9, 7, 4, null, 2, 4,     // bar 1
  2, null, 4, 2, 0, null, null, 0,  // bar 2
  4, 5, 7, 9, 7, null, 5, 4,        // bar 3
  2, null, null, null, 4, null, 2, null, // bar 4
];
const phraseB = [
  9, null, 7, 9, 11, null, 9, 7,
  5, null, 4, 5, 7, null, null, 4,
  2, 4, 5, 4, 2, null, 0, 2,
  4, null, null, null, null, null, 7, null,
];
const scale = [0, 2, 4, 5, 7, 9, 11];
const degreeToMidi = (d) => 72 + scale[d % 7] + 12 * Math.floor(d / 7);
const melody = [...phraseA, ...phraseB, ...phraseA.slice(0, 24), 9, null, 7, null, 4, null, null, null, ...phraseB];

for (let bar = 0; bar < BARS; bar++) {
  const barStart = bar * 4 * BEAT;
  const chord = CH[progression[bar]];

  // Drums
  for (let b = 0; b < 4; b++) {
    const t = barStart + b * BEAT;
    if (b === 0 || b === 2) kick(t);
    if (b === 2 && bar % 4 === 3) kick(t + BEAT / 2);
    if (b === 1 || b === 3) snare(t);
    hat(t, 0.10);
    hat(t + BEAT / 2, 0.06);
  }

  // Bass: root on 8ths with an octave hop
  const root = chord[0] - 24;
  for (let e = 0; e < 8; e++) {
    const note = e % 4 === 3 ? root + 12 : root;
    tone(barStart + e * BEAT / 2, BEAT / 2 * 0.8, note, 0.30, 'tri', 0.004, 0.03);
  }

  // Pad-ish arpeggio in 16ths
  const arp = [chord[0], chord[1], chord[2], chord[1] + 12, chord[2], chord[1]];
  for (let s = 0; s < 16; s++) {
    tone(barStart + s * BEAT / 4, BEAT / 4 * 0.7, arp[s % arp.length], 0.055, 'saw', 0.003, 0.05);
  }

  // Lead melody
  for (let e = 0; e < 8; e++) {
    const d = melody[bar * 8 + e];
    if (d === null || d === undefined) continue;
    // hold until next note or rest
    let len = 1;
    while (e + len < 8 && melody[bar * 8 + e + len] === null && len < 3) len++;
    tone(barStart + e * BEAT / 2, len * BEAT / 2 * 0.9, degreeToMidi(d), 0.12, 'pulse', 0.004, 0.06);
  }
}

// ── Master: gentle soft-clip limiter & normalize ─────────────
let peak = 0;
for (let i = 0; i < TOTAL; i++) {
  out[i] = Math.tanh(out[i] * 1.2);
  peak = Math.max(peak, Math.abs(out[i]));
}
const gain = 0.85 / peak;

const data = Buffer.alloc(TOTAL * 2);
for (let i = 0; i < TOTAL; i++) {
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, out[i] * gain)) * 32767), i * 2);
}
const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + data.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20);        // PCM
header.writeUInt16LE(1, 22);        // mono
header.writeUInt32LE(SR, 24);
header.writeUInt32LE(SR * 2, 28);
header.writeUInt16LE(2, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(data.length, 40);

const file = path.join(__dirname, '..', 'assets', 'audio', 'background_loop.wav');
fs.writeFileSync(file, Buffer.concat([header, data]));
console.log(`Wrote ${file} (${(TOTAL / SR).toFixed(1)} s, ${((44 + data.length) / 1e6).toFixed(2)} MB)`);
