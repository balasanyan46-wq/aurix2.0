/**
 * AURIX Studio Engine — pure JS audio engine.
 *
 * Manages: tracks, clips, playback (Web Audio API), recording (MediaRecorder),
 * waveform peak extraction, transport (play/pause/stop/seek).
 *
 * Flutter calls these functions via dart:js_interop.
 * No frameworks, no dependencies — just Web Audio API.
 */

(function() {
  'use strict';

  // ─── State ───
  let ctx = null;          // AudioContext
  let masterGain = null;   // GainNode
  let reverbIR = null;     // shared ConvolverNode impulse response
  let tracks = [];         // [{id, name, color, volume, pan, mute, solo, ...fxNodes, clips, fx:{reverb,delay}}]
  let playing = false;
  let recording = false;
  let playStartTime = 0;   // ctx.currentTime when play started
  let playOffset = 0;      // seconds offset from timeline start
  let activeSources = [];  // active AudioBufferSourceNodes
  let bpm = 120;

  // Recording
  let micStream = null;
  let recorder = null;
  let recChunks = [];
  let recTrackId = null;
  let recStartPos = 0;
  // Live monitoring: AnalyserNode на mic-источнике для метров и волны
  let micSourceNode = null;
  let micAnalyser = null;
  let micPeakBuf = null;       // Float32Array для getFloatTimeDomainData
  let recordedSamples = [];    // накопленный пиковый огибающий клип (для рисования live-волны)
  let recordedSamplesAt = 0;

  // Metronome
  let metronomeOn = false;
  let metronomeSources = [];

  // Loop region (Ableton-style brace)
  let loopOn = false;
  let loopStart = 0;
  let loopEnd = 4;

  // Selected clip (for keyboard shortcuts)
  let selectedClipId = '';

  // ─── Init ───
  // Калибровочный сдвиг для компенсации задержки входа микрофона.
  // Применяется к recStartPos: вокал стартует чуть РАНЬШЕ, чем MediaRecorder
  // успел отдать первые данные. По умолчанию ~120мс — хорошо подходит для
  // встроенных микрофонов на ноутбуках через Bluetooth/USB-аудио.
  let inputLatencyMs = 120;
  function setInputLatency(ms) { inputLatencyMs = Math.max(-500, Math.min(500, +ms || 0)); }
  function getInputLatency() { return inputLatencyMs; }

  function init() {
    if (ctx) return true; // idempotent
    // latencyHint: 'interactive' — самый низкий буфер для отзывчивой записи.
    ctx = new AudioContext({ latencyHint: 'interactive' });
    masterGain = ctx.createGain();
    masterGain.gain.value = 1.0;
    masterGain.connect(ctx.destination);
    // 1.6с tail + быстрый decay — реверб не размазывает разборчивость голоса.
    reverbIR = buildReverbIR(1.6, 2.6);
    console.log('[Engine] Init, sr=' + ctx.sampleRate +
                ', baseLatency=' + (ctx.baseLatency || 0).toFixed(4) +
                ', outputLatency=' + (ctx.outputLatency || 0).toFixed(4));
    return true;
  }

  // Synthetic reverb impulse response (plate/room character)
  function buildReverbIR(seconds, decay) {
    const sr = ctx.sampleRate;
    const len = Math.floor(sr * seconds);
    const buf = ctx.createBuffer(2, len, sr);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      for (let i = 0; i < len; i++) {
        const t = i / len;
        d[i] = (Math.random() * 2 - 1) * Math.pow(1 - t, decay);
      }
    }
    return buf;
  }

  // ─── Resume (required after user gesture) ───
  async function resume() {
    if (ctx && ctx.state === 'suspended') {
      await ctx.resume();
      console.log('[Engine] Resumed');
    }
  }

  // ─── Track management ───
  const COLORS = ['#FF6A1A', '#4DB88C', '#7B5CFF', '#D2A45A', '#C97171', '#5CA8FF', '#FF5CAA', '#8AFF5C'];

  function addTrack(id, name, isBeat) {
    // Дедуп: повторный addTrack с тем же id — no-op (защита от ретраев init).
    if (tracks.some(t => t.id === id)) {
      console.log('[Engine] addTrack: id "' + id + '" already exists, skipping');
      return id;
    }
    // Per-track FX chain:
    // source → gainNode (volume) → compressor → fxSplit
    //                                         → dry → mix
    //                                         → reverbSend → convolver → mix
    //                                         → delaySend → delay(→feedback) → mix
    // mix → panNode → masterGain
    const gainNode = ctx.createGain();
    const compressor = ctx.createDynamicsCompressor();
    // Gentle vocal-friendly settings; beat gets softer action
    compressor.threshold.value = isBeat ? -14 : -22;
    compressor.knee.value = 12;
    compressor.ratio.value = isBeat ? 2 : 3;
    compressor.attack.value = 0.005;
    compressor.release.value = 0.12;

    const fxSplit = ctx.createGain();
    const dry = ctx.createGain(); dry.gain.value = 1.0;
    const reverbSend = ctx.createGain(); reverbSend.gain.value = 0;
    const convolver = ctx.createConvolver(); convolver.buffer = reverbIR;
    const delaySend = ctx.createGain(); delaySend.gain.value = 0;
    const delay = ctx.createDelay(1.0); delay.delayTime.value = 0.28;
    const delayFeedback = ctx.createGain(); delayFeedback.gain.value = 0.32;
    const mix = ctx.createGain(); mix.gain.value = 1.0;
    const panNode = ctx.createStereoPanner();

    // Wire it up
    gainNode.connect(compressor);
    compressor.connect(fxSplit);

    fxSplit.connect(dry);
    dry.connect(mix);

    fxSplit.connect(reverbSend);
    reverbSend.connect(convolver);
    convolver.connect(mix);

    fxSplit.connect(delaySend);
    delaySend.connect(delay);
    delay.connect(delayFeedback);
    delayFeedback.connect(delay); // self-feedback
    delay.connect(mix);

    mix.connect(panNode);
    panNode.connect(masterGain);

    const track = {
      id: id,
      name: name || ('Track ' + (tracks.length + 1)),
      color: COLORS[tracks.length % COLORS.length],
      volume: isBeat ? 0.85 : 1.0,
      pan: 0,
      mute: false,
      solo: false,
      isBeat: !!isBeat,
      gainNode, compressor, fxSplit, dry, reverbSend, convolver,
      delaySend, delay, delayFeedback, mix, panNode,
      fx: { reverb: 0, delay: 0 },
      clips: [],
    };
    gainNode.gain.value = track.volume;
    tracks.push(track);
    console.log('[Engine] Track added: ' + id);
    return track.id;
  }

  function removeTrack(id) {
    const idx = tracks.findIndex(t => t.id === id);
    if (idx < 0 || tracks[idx].isBeat) return;
    const t = tracks[idx];
    try {
      t.gainNode.disconnect(); t.compressor.disconnect();
      t.fxSplit.disconnect(); t.dry.disconnect();
      t.reverbSend.disconnect(); t.convolver.disconnect();
      t.delaySend.disconnect(); t.delay.disconnect(); t.delayFeedback.disconnect();
      t.mix.disconnect(); t.panNode.disconnect();
    } catch(e) {}
    tracks.splice(idx, 1);
  }

  // ─── Per-track FX ───
  function setTrackFX(id, reverb, delay) {
    const t = tracks.find(t => t.id === id);
    if (!t) return;
    t.fx.reverb = Math.max(0, Math.min(1, reverb));
    t.fx.delay = Math.max(0, Math.min(1, delay));
    // Blend: at reverb=1 → dry=0.5, reverbSend=0.9 (wet dominant but still intelligible)
    t.dry.gain.value = 1 - t.fx.reverb * 0.35 - t.fx.delay * 0.2;
    t.reverbSend.gain.value = t.fx.reverb * 0.9;
    t.delaySend.gain.value = t.fx.delay * 0.55;
  }

  function setTrackFXJSON(json) {
    const o = JSON.parse(json);
    setTrackFX(o.id, o.reverb, o.delay);
  }

  function setTrackVolume(id, vol) {
    const t = tracks.find(t => t.id === id);
    if (!t) return;
    t.volume = Math.max(0, Math.min(1.5, vol));
    applyGains();
  }

  function setTrackPan(id, pan) {
    const t = tracks.find(t => t.id === id);
    if (!t) return;
    t.pan = Math.max(-1, Math.min(1, pan));
    t.panNode.pan.value = t.pan;
  }

  function toggleMute(id) {
    const t = tracks.find(t => t.id === id);
    if (t) { t.mute = !t.mute; applyGains(); }
    return t ? t.mute : false;
  }

  function toggleSolo(id) {
    const t = tracks.find(t => t.id === id);
    if (t) { t.solo = !t.solo; applyGains(); }
    return t ? t.solo : false;
  }

  function applyGains() {
    const hasSolo = tracks.some(t => t.solo);
    for (const t of tracks) {
      let v = t.volume;
      if (t.mute) v = 0;
      if (hasSolo && !t.solo) v = 0;
      t.gainNode.gain.value = v;
    }
  }

  // ─── Load audio ───
  async function loadAudio(trackId, arrayBuffer) {
    await resume();
    let buffer = await ctx.decodeAudioData(arrayBuffer);
    buffer = ensureStereo(buffer);
    const t = tracks.find(t => t.id === trackId);
    if (!t) return null;

    const clipId = trackId + '_clip_' + t.clips.length + '_' + Date.now();
    const peaks = extractPeaks(buffer, 500);

    t.clips.push({
      id: clipId,
      buffer: buffer,
      originalBuffer: buffer,
      startTime: 0,
      offset: 0,
      duration: buffer.duration,
      peaks: peaks,
    });

    console.log('[Engine] Audio loaded: ' + clipId + ' (' + buffer.duration.toFixed(1) + 's, ' + buffer.numberOfChannels + 'ch)');

    // Auto BPM detection for beat track
    if (t.isBeat) {
      const detected = detectBPM(buffer);
      if (detected > 0) { bpm = detected; console.log('[Engine] BPM: ' + detected); }
    }

    return clipId;
  }

  function extractPeaks(buffer, numPeaks) {
    const data = buffer.getChannelData(0);
    const step = Math.floor(data.length / numPeaks);
    if (step === 0) return new Float32Array(0);
    const peaks = new Float32Array(numPeaks);
    for (let i = 0; i < numPeaks; i++) {
      let max = 0;
      const start = i * step;
      const end = Math.min(start + step, data.length);
      for (let j = start; j < end; j++) {
        const v = Math.abs(data[j]);
        if (v > max) max = v;
      }
      peaks[i] = max;
    }
    return peaks;
  }

  function detectBPM(buffer) {
    try {
      const sr = buffer.sampleRate;
      const data = buffer.getChannelData(0);
      if (data.length < sr * 2) return 0;
      const ws = Math.floor(sr * 0.02);
      const hop = Math.floor(ws / 2);
      const nw = Math.floor((data.length - ws) / hop);
      const energy = new Float32Array(nw);
      for (let i = 0; i < nw; i++) {
        let s = 0;
        for (let j = 0; j < ws; j++) { const v = data[i * hop + j]; s += v * v; }
        energy[i] = s / ws;
      }
      const onset = new Float32Array(nw);
      for (let i = 1; i < nw; i++) {
        const d = energy[i] - energy[i - 1];
        onset[i] = d > 0 ? d : 0;
      }
      const minL = Math.round(60 / 200 * sr / hop);
      const maxL = Math.round(60 / 60 * sr / hop);
      let best = 0, bestL = 0;
      for (let l = minL; l < Math.min(maxL, Math.floor(nw / 2)); l++) {
        let c = 0;
        for (let i = 0; i < nw - l; i++) c += onset[i] * onset[i + l];
        if (c > best) { best = c; bestL = l; }
      }
      if (bestL === 0) return 0;
      return Math.round(60 / (bestL * hop / sr) * 2) / 2;
    } catch (e) { return 0; }
  }

  // ─── Playback ───
  function play() {
    if (playing) return;
    resume().then(() => doPlay());
  }

  function doPlay() {
    stopSources();
    stopMetronome();
    playStartTime = ctx.currentTime;
    playing = true;
    let count = 0;

    for (const t of tracks) {
      for (const clip of t.clips) {
        if (!clip.buffer || clip.startTime + clip.duration <= playOffset) continue;
        const src = ctx.createBufferSource();
        src.buffer = clip.buffer;

        // Tiny fade-in to avoid clicks
        const fadeGain = ctx.createGain();
        fadeGain.gain.setValueAtTime(0, ctx.currentTime);
        fadeGain.gain.linearRampToValueAtTime(1, ctx.currentTime + 0.003);
        src.connect(fadeGain);
        fadeGain.connect(t.gainNode);

        const into = playOffset - clip.startTime;
        if (into >= 0 && into < clip.duration) {
          src.start(0, clip.offset + into, clip.duration - into);
        } else if (into < 0) {
          src.start(ctx.currentTime + (-into), clip.offset, clip.duration);
        }
        activeSources.push(src);
        count++;
      }
    }
    startMetronome();
    scheduleLoopCheck();
    console.log('[Engine] Play: ' + count + ' sources from ' + playOffset.toFixed(2) + 's');
  }

  function pause() {
    if (!playing) return;
    playOffset = getPlayhead();
    stopSources();
    stopMetronome();
    playing = false;
  }

  function stop() {
    stopSources();
    stopMetronome();
    playing = false;
    playOffset = 0;
  }

  function seekTo(time) {
    const was = playing;
    if (playing) { stopSources(); stopMetronome(); playing = false; }
    playOffset = Math.max(0, time);
    if (was) play();
  }

  // ─── Metronome ───
  function toggleMetronome() {
    metronomeOn = !metronomeOn;
    if (playing) { stopMetronome(); startMetronome(); }
    return metronomeOn;
  }
  function isMetronomeOn() { return metronomeOn; }

  function startMetronome() {
    stopMetronome();
    if (!metronomeOn || !playing) return;
    const spb = 60 / bpm;
    const dur = getTotalDuration();
    const firstBeatIdx = Math.max(0, Math.ceil(playOffset / spb));
    const lastBeatIdx = Math.ceil(dur / spb) + 2;
    for (let b = firstBeatIdx; b < lastBeatIdx; b++) {
      const beatTime = b * spb;
      const ctxTime = playStartTime + (beatTime - playOffset);
      if (ctxTime < ctx.currentTime) continue;
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      const strong = (b % 4 === 0);
      osc.type = 'square';
      osc.frequency.value = strong ? 1800 : 1200;
      g.gain.setValueAtTime(0, ctxTime);
      g.gain.linearRampToValueAtTime(strong ? 0.28 : 0.14, ctxTime + 0.002);
      g.gain.exponentialRampToValueAtTime(0.001, ctxTime + 0.06);
      osc.connect(g); g.connect(masterGain);
      osc.start(ctxTime);
      osc.stop(ctxTime + 0.07);
      metronomeSources.push(osc);
    }
  }
  function stopMetronome() {
    for (const o of metronomeSources) { try { o.stop(0); } catch(e) {} }
    metronomeSources = [];
  }

  // ─── Loop region ───
  function setLoopRegion(start, end, on) {
    loopStart = Math.max(0, start);
    loopEnd = Math.max(loopStart + 0.1, end);
    loopOn = !!on;
    console.log('[Engine] Loop: ' + loopOn + ' ' + loopStart.toFixed(1) + '→' + loopEnd.toFixed(1));
  }
  function setLoopRegionJSON(json) {
    const o = JSON.parse(json);
    setLoopRegion(o.start, o.end, o.on);
  }
  function isLoopOn() { return loopOn; }
  function getLoopStart() { return loopStart; }
  function getLoopEnd() { return loopEnd; }

  // Polls playhead — when crossing loopEnd (while in loop region), seek back to loopStart.
  let loopTimer = null;
  function scheduleLoopCheck() {
    if (loopTimer) { clearInterval(loopTimer); loopTimer = null; }
    if (!loopOn) return;
    loopTimer = setInterval(() => {
      if (!playing) { clearInterval(loopTimer); loopTimer = null; return; }
      const p = getPlayhead();
      if (p >= loopEnd) {
        // Seek back to loopStart
        stopSources(); stopMetronome();
        playOffset = loopStart;
        playStartTime = ctx.currentTime;
        playing = true;
        // Restart sources from loopStart
        for (const t of tracks) {
          for (const clip of t.clips) {
            if (!clip.buffer || clip.startTime + clip.duration <= playOffset) continue;
            const src = ctx.createBufferSource();
            src.buffer = clip.buffer;
            const fadeGain = ctx.createGain();
            fadeGain.gain.setValueAtTime(0, ctx.currentTime);
            fadeGain.gain.linearRampToValueAtTime(1, ctx.currentTime + 0.003);
            src.connect(fadeGain);
            fadeGain.connect(t.gainNode);
            const into = playOffset - clip.startTime;
            if (into >= 0 && into < clip.duration) src.start(0, clip.offset + into, clip.duration - into);
            else if (into < 0) src.start(ctx.currentTime + (-into), clip.offset, clip.duration);
            activeSources.push(src);
          }
        }
        startMetronome();
      }
    }, 30);
  }

  function getPlayhead() {
    if (!playing) return playOffset;
    return ctx.currentTime - playStartTime + playOffset;
  }

  function isPlaying() { return playing; }
  function isRecording() { return recording; }
  function getBPM() { return bpm; }
  function setBPM(v) { bpm = Math.max(40, Math.min(300, v)); }

  function getTotalDuration() {
    let d = 0;
    for (const t of tracks) {
      for (const c of t.clips) {
        const end = c.startTime + c.duration;
        if (end > d) d = end;
      }
    }
    return Math.max(d, 2);
  }

  function stopSources() {
    for (const s of activeSources) {
      try { s.stop(0); } catch(e) {}
    }
    activeSources = [];
  }

  // ─── Ensure stereo (mono → duplicate to both channels) ───
  // Используется для ЗАГРУЖАЕМОГО аудио (бит — должен быть стерео).
  function ensureStereo(buffer) {
    if (buffer.numberOfChannels >= 2) return buffer;
    const sr = buffer.sampleRate;
    const len = buffer.length;
    const mono = buffer.getChannelData(0);
    const stereo = ctx.createBuffer(2, len, sr);
    const L = stereo.getChannelData(0);
    const R = stereo.getChannelData(1);
    for (let i = 0; i < len; i++) { L[i] = mono[i]; R[i] = mono[i]; }
    console.log('[Engine] Mono → Stereo: ' + len + ' samples duplicated');
    return stereo;
  }

  // ─── Force mono (для записанного вокала — гарантирует «по центру») ───
  // Bug: opus-декодер часто возвращает 2-канальный буфер с пустым правым каналом
  //  (микрофон mono, но контейнер стерео) → при воспроизведении звук уходит в левое ухо.
  //  Решение: сводим в 1-канальный буфер. Web Audio при подключении к стерео-цепи
  //  автоматически дублирует моно-сигнал в оба канала (центр).
  function ensureMono(buffer) {
    if (buffer.numberOfChannels === 1) return buffer;
    const sr = buffer.sampleRate;
    const len = buffer.length;
    const out = ctx.createBuffer(1, len, sr);
    const dst = out.getChannelData(0);
    const ch0 = buffer.getChannelData(0);
    const ch1 = buffer.numberOfChannels > 1 ? buffer.getChannelData(1) : ch0;

    // Определяем: настоящее стерео или mono-в-одном-канале.
    // Считаем энергию обоих каналов на первых ~100мс.
    const probe = Math.min(len, Math.floor(sr * 0.1));
    let sumL = 0, sumR = 0;
    for (let i = 0; i < probe; i++) { sumL += Math.abs(ch0[i]); sumR += Math.abs(ch1[i]); }
    const ratio = sumL > 0 ? sumR / sumL : 0;

    if (ratio < 0.05) {
      // R почти тишина → копируем только L (избегаем ослабления при усреднении)
      for (let i = 0; i < len; i++) dst[i] = ch0[i];
      console.log('[Engine] Stereo→Mono (L only, R was silent)');
    } else if (sumR > 0 && sumL < 0.05 * sumR) {
      // L почти тишина → копируем R
      for (let i = 0; i < len; i++) dst[i] = ch1[i];
      console.log('[Engine] Stereo→Mono (R only, L was silent)');
    } else {
      // Реальное стерео → усредняем
      for (let i = 0; i < len; i++) dst[i] = (ch0[i] + ch1[i]) * 0.5;
      console.log('[Engine] Stereo→Mono (averaged)');
    }
    return out;
  }

  // ─── Recording ───
  async function startRecording(trackId) {
    if (recording || !trackId) return false;
    await resume();

    // 1. ОТКРЫВАЕМ МИКРОФОН ПЕРВЫМ (это самая медленная операция: 100–300мс).
    //    Делаем это ДО запуска бита, иначе бит начнётся раньше, чем юзер
    //    успеет «вступить», и слова поедут.
    try {
      // channelCount: 1 — пишем строго моно; никакой обработки браузера.
      const audioConstraints = {
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
        channelCount: { ideal: 1 },
        sampleRate: { ideal: 48000 },
        sampleSize: { ideal: 24 },
        latency: { ideal: 0.01 }, // 10мс — минимум, что разрешает браузер
      };
      if (selectedInputDeviceId) {
        audioConstraints.deviceId = { exact: selectedInputDeviceId };
      }
      micStream = await navigator.mediaDevices.getUserMedia({ audio: audioConstraints });
      const settings = micStream.getAudioTracks()[0].getSettings();
      console.log('[Engine] Mic opened: ' + settings.sampleRate + 'Hz, ' +
                  settings.channelCount + 'ch, latency=' + (settings.latency || 'n/a'));
    } catch (e) {
      console.error('[Engine] Mic failed:', e);
      return false;
    }

    // Не подключаем mic к speakers (защита от фидбэка), но создаём
    // analyser-цепочку для live-метра и накопления огибающей.
    micSourceNode = ctx.createMediaStreamSource(micStream);
    micAnalyser = ctx.createAnalyser();
    micAnalyser.fftSize = 1024;
    micAnalyser.smoothingTimeConstant = 0.2;
    micPeakBuf = new Float32Array(micAnalyser.fftSize);
    micSourceNode.connect(micAnalyser);
    recordedSamples = [];
    recordedSamplesAt = ctx.currentTime;

    recChunks = [];
    recTrackId = trackId;

    // Prefer high-bitrate codec
    const mimes = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4'];
    let mime = '';
    for (const m of mimes) { if (MediaRecorder.isTypeSupported(m)) { mime = m; break; } }

    const recOpts = {};
    if (mime) recOpts.mimeType = mime;
    recOpts.audioBitsPerSecond = 256000;
    recorder = new MediaRecorder(micStream, recOpts);
    recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) recChunks.push(e.data);
    };

    // 2. СИНХРОННЫЙ СТАРТ: запускаем бит и MediaRecorder в один тик.
    //    recStartPos фиксируем ровно в момент запуска recorder,
    //    чтобы вокал был привязан к точной позиции бита.
    if (!playing) play();
    recStartPos = getPlayhead();
    recorder.start(50); // 50мс чанки — быстрее реагирует на stop
    recording = true;

    console.log('[Engine] Recording started on ' + trackId + ' @ ' + recStartPos.toFixed(3) + 's');
    return true;
  }

  // Возвращает текущий уровень микрофона как RMS (0..1) и пик (0..1).
  // Также добавляет точку в накопленный массив peaks (огибающая).
  function getRecordingLevel() {
    if (!recording || !micAnalyser) return '0,0';
    micAnalyser.getFloatTimeDomainData(micPeakBuf);
    let sum = 0, peak = 0;
    for (let i = 0; i < micPeakBuf.length; i++) {
      const v = Math.abs(micPeakBuf[i]);
      sum += v * v;
      if (v > peak) peak = v;
    }
    const rms = Math.sqrt(sum / micPeakBuf.length);
    // Накапливаем точку огибающей не чаще, чем 100 раз в секунду
    const now = ctx.currentTime;
    if (now - recordedSamplesAt > 0.01) {
      recordedSamples.push(peak);
      recordedSamplesAt = now;
      if (recordedSamples.length > 12000) recordedSamples.shift(); // ~120 сек кап
    }
    return rms.toFixed(4) + ',' + peak.toFixed(4);
  }

  // Снимок огибающей записи (последние N точек)
  function getRecordingSamples(maxN) {
    const arr = recordedSamples;
    if (!arr.length) return new Float32Array(0);
    const n = Math.min(maxN || 500, arr.length);
    const start = arr.length - n;
    return new Float32Array(arr.slice(start));
  }

  async function stopRecording() {
    if (!recording) return null;
    recording = false;
    pause();

    return new Promise((resolve) => {
      recorder.onstop = async () => {
        // Kill mic
        if (micStream) {
          micStream.getTracks().forEach(t => t.stop());
          micStream = null;
        }
        // Cleanup analyser
        try { micSourceNode?.disconnect(); } catch(_) {}
        try { micAnalyser?.disconnect(); } catch(_) {}
        micSourceNode = null;
        micAnalyser = null;
        micPeakBuf = null;
        if (recChunks.length === 0) { resolve(null); return; }

        const blob = new Blob(recChunks);
        console.log('[Engine] Recorded: ' + blob.size + ' bytes');
        const ab = await blob.arrayBuffer();
        try {
          let buffer = await ctx.decodeAudioData(ab);

          // ВОКАЛ → строго моно (Web Audio сам распределит в L+R центром).
          // Раньше делали ensureStereo, и opus отдавал стерео-буфер с пустым R
          // → звук уходил только в левое ухо. Фикс: принудительный downmix.
          buffer = ensureMono(buffer);

          const track = tracks.find(t => t.id === recTrackId);
          if (!track) { resolve(null); return; }

          // Компенсируем задержку входа: смещаем клип на `inputLatencyMs`
          // ВЛЕВО, чтобы вокал ровно лёг на бит.
          const compensatedStart = Math.max(0, recStartPos - inputLatencyMs / 1000);

          const clipId = recTrackId + '_rec_' + Date.now();
          const peaks = extractPeaks(buffer, 500);
          track.clips.push({
            id: clipId,
            buffer: buffer,
            originalBuffer: buffer,
            startTime: compensatedStart,
            offset: 0,
            duration: buffer.duration,
            peaks: peaks,
          });
          console.log('[Engine] Vocal decoded: ' + buffer.duration.toFixed(2) + 's, ' +
                      buffer.numberOfChannels + 'ch, start=' + compensatedStart.toFixed(3) +
                      's (raw=' + recStartPos.toFixed(3) + 's, comp=-' + inputLatencyMs + 'ms) → ' + clipId);
          resolve(clipId);
        } catch (e) {
          console.error('[Engine] Decode failed:', e);
          resolve(null);
        }
      };
      recorder.stop();
    });
  }

  // ─── Clip operations ───
  function moveClip(clipId, newStart) {
    for (const t of tracks) {
      for (const c of t.clips) {
        if (c.id === clipId) { c.startTime = Math.max(0, newStart); return; }
      }
    }
  }

  function deleteClip(clipId) {
    for (const t of tracks) {
      t.clips = t.clips.filter(c => c.id !== clipId);
    }
    if (selectedClipId === clipId) selectedClipId = '';
  }

  function duplicateClip(clipId) {
    for (const t of tracks) {
      for (const c of t.clips) {
        if (c.id !== clipId || !c.buffer) continue;
        const newId = clipId + '_dup_' + Date.now();
        t.clips.push({
          id: newId, buffer: c.buffer,
          startTime: c.startTime + c.duration,
          offset: c.offset, duration: c.duration,
          peaks: c.peaks,
        });
        return newId;
      }
    }
    return null;
  }

  // Split a clip at absolute timeline time — produces two clips that sound
  // continuous when played back.
  function splitClipAt(clipId, atTime) {
    for (const t of tracks) {
      for (const c of t.clips) {
        if (c.id !== clipId || !c.buffer) continue;
        const end = c.startTime + c.duration;
        if (atTime <= c.startTime + 0.02 || atTime >= end - 0.02) return null;
        const cut = atTime - c.startTime;       // seconds from clip start
        const leftDur = cut;
        const rightDur = c.duration - cut;

        // Recompute peaks proportionally (cheap — avoids re-scanning buffer)
        const n = c.peaks.length;
        const splitIdx = Math.max(1, Math.floor(n * (leftDur / c.duration)));
        const leftPeaks = c.peaks.slice(0, splitIdx);
        const rightPeaks = c.peaks.slice(splitIdx);

        // Update current clip → becomes LEFT
        c.duration = leftDur;
        c.peaks = leftPeaks;

        // Create RIGHT
        const rightId = clipId + '_r_' + Date.now();
        t.clips.push({
          id: rightId,
          buffer: c.buffer,
          originalBuffer: c.originalBuffer || c.buffer,
          startTime: atTime,
          offset: c.offset + cut,
          duration: rightDur,
          peaks: rightPeaks,
        });
        console.log('[Engine] Split ' + clipId + ' @ ' + atTime.toFixed(2) + 's');
        return rightId;
      }
    }
    return null;
  }

  // Trim left/right edges of a clip (in seconds from current start/end)
  function trimClip(clipId, leftDelta, rightDelta) {
    for (const t of tracks) {
      for (const c of t.clips) {
        if (c.id !== clipId || !c.buffer) continue;
        const newStart = Math.max(0, c.startTime + leftDelta);
        const newDur = Math.max(0.1, c.duration - leftDelta - rightDelta);
        const newOffset = Math.max(0, c.offset + leftDelta);
        c.startTime = newStart;
        c.offset = newOffset;
        c.duration = newDur;
        return true;
      }
    }
    return false;
  }

  function selectClip(clipId) { selectedClipId = clipId || ''; }
  function getSelectedClipId() { return selectedClipId; }

  // ─── Track reorder (drag up/down) ───
  function moveTrackTo(trackId, newIndex) {
    const idx = tracks.findIndex(t => t.id === trackId);
    if (idx < 0 || newIndex < 0 || newIndex >= tracks.length || idx === newIndex) return false;
    const [moved] = tracks.splice(idx, 1);
    tracks.splice(newIndex, 0, moved);
    console.log('[Engine] Track ' + trackId + ' moved to index ' + newIndex);
    return true;
  }
  function moveTrackToJSON(json) {
    const o = JSON.parse(json);
    return moveTrackTo(o.id, o.index);
  }

  // ─── Audio device enumeration ───
  async function getAudioDevices() {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      const inputs = devices.filter(d => d.kind === 'audioinput').map(d => ({
        id: d.deviceId, label: d.label || ('Микрофон ' + d.deviceId.slice(0, 4)),
      }));
      const outputs = devices.filter(d => d.kind === 'audiooutput').map(d => ({
        id: d.deviceId, label: d.label || ('Выход ' + d.deviceId.slice(0, 4)),
      }));
      return JSON.stringify({ inputs, outputs });
    } catch (e) {
      console.warn('[Engine] enumerateDevices failed:', e);
      return JSON.stringify({ inputs: [], outputs: [] });
    }
  }

  let selectedInputDeviceId = '';
  let selectedOutputDeviceId = '';

  function setInputDevice(deviceId) {
    selectedInputDeviceId = deviceId || '';
    console.log('[Engine] Input device: ' + selectedInputDeviceId);
  }

  async function setOutputDevice(deviceId) {
    selectedOutputDeviceId = deviceId || '';
    try {
      if (ctx && ctx.setSinkId) await ctx.setSinkId(deviceId);
      console.log('[Engine] Output device: ' + deviceId);
    } catch (e) { console.warn('[Engine] setSinkId failed:', e); }
  }

  // ─── Data getters for Flutter ───
  function getTracksJSON() {
    return JSON.stringify(tracks.map(t => ({
      id: t.id,
      name: t.name,
      color: t.color,
      volume: t.volume,
      pan: t.pan,
      mute: t.mute,
      solo: t.solo,
      isBeat: t.isBeat,
      reverb: t.fx?.reverb ?? 0,
      delay: t.fx?.delay ?? 0,
      clips: t.clips.map(c => ({
        id: c.id,
        startTime: c.startTime,
        offset: c.offset,
        duration: c.duration,
        peaks: Array.from(c.peaks),
      })),
    })));
  }

  function getClipPeaks(clipId) {
    for (const t of tracks) {
      for (const c of t.clips) {
        if (c.id === clipId) return c.peaks;
      }
    }
    return null;
  }

  // ─── Export to WAV ───
  function exportWAV() {
    const dur = getTotalDuration();
    const sr = Math.floor(ctx.sampleRate);
    const len = Math.floor(sr * dur);
    const L = new Float32Array(len);
    const R = new Float32Array(len);
    const hasSolo = tracks.some(t => t.solo);

    for (const t of tracks) {
      let v = t.volume;
      if (t.mute) v = 0;
      if (hasSolo && !t.solo) v = 0;
      if (v === 0) continue;

      for (const c of t.clips) {
        if (!c.buffer) continue;
        const nCh = c.buffer.numberOfChannels;
        const dL = c.buffer.getChannelData(0);
        const dR = nCh > 1 ? c.buffer.getChannelData(1) : dL;
        const dstS = Math.floor(c.startTime * sr);
        const srcS = Math.floor(c.offset * sr);
        const n = Math.floor(c.duration * sr);
        for (let i = 0; i < n; i++) {
          const d = dstS + i, s = srcS + i;
          if (d < 0 || d >= len || s < 0 || s >= dL.length) continue;
          L[d] += dL[s] * v;
          R[d] += dR[s] * v;
        }
      }
    }

    // Encode WAV
    const numSamples = len;
    const dataSize = numSamples * 4; // 2ch * 16bit
    const buf = new ArrayBuffer(44 + dataSize);
    const view = new DataView(buf);
    const w = (o, s) => { for (let i = 0; i < s.length; i++) view.setUint8(o + i, s.charCodeAt(i)); };
    w(0, 'RIFF'); view.setUint32(4, 36 + dataSize, true); w(8, 'WAVE');
    w(12, 'fmt '); view.setUint32(16, 16, true); view.setUint16(20, 1, true);
    view.setUint16(22, 2, true); view.setUint32(24, sr, true);
    view.setUint32(28, sr * 4, true); view.setUint16(32, 4, true); view.setUint16(34, 16, true);
    w(36, 'data'); view.setUint32(40, dataSize, true);
    let off = 44;
    for (let i = 0; i < numSamples; i++) {
      view.setInt16(off, Math.max(-32768, Math.min(32767, Math.round(L[i] * 32767))), true); off += 2;
      view.setInt16(off, Math.max(-32768, Math.min(32767, Math.round(R[i] * 32767))), true); off += 2;
    }
    const blob = new Blob([buf], { type: 'audio/wav' });
    return URL.createObjectURL(blob);
  }

  // ─── Clip → WAV (for server-side correction) ───
  function encodeBufferToWAV(buffer) {
    const sr = Math.floor(buffer.sampleRate);
    const len = buffer.length;
    const dL = buffer.getChannelData(0);
    const dR = buffer.numberOfChannels > 1 ? buffer.getChannelData(1) : dL;
    const dataSize = len * 4; // 2ch × 16bit
    const buf = new ArrayBuffer(44 + dataSize);
    const view = new DataView(buf);
    const w = (o, s) => { for (let i = 0; i < s.length; i++) view.setUint8(o + i, s.charCodeAt(i)); };
    w(0, 'RIFF'); view.setUint32(4, 36 + dataSize, true); w(8, 'WAVE');
    w(12, 'fmt '); view.setUint32(16, 16, true); view.setUint16(20, 1, true);
    view.setUint16(22, 2, true); view.setUint32(24, sr, true);
    view.setUint32(28, sr * 4, true); view.setUint16(32, 4, true); view.setUint16(34, 16, true);
    w(36, 'data'); view.setUint32(40, dataSize, true);
    let off = 44;
    for (let i = 0; i < len; i++) {
      view.setInt16(off, Math.max(-32768, Math.min(32767, Math.round(dL[i] * 32767))), true); off += 2;
      view.setInt16(off, Math.max(-32768, Math.min(32767, Math.round(dR[i] * 32767))), true); off += 2;
    }
    return buf;
  }

  // Return a single clip as Uint8Array (16-bit stereo WAV)
  function exportClipWAVBytes(clipId) {
    for (const t of tracks) {
      for (const c of t.clips) {
        if (c.id === clipId && c.buffer) {
          return new Uint8Array(encodeBufferToWAV(c.buffer));
        }
      }
    }
    return new Uint8Array(0);
  }

  // Return the ORIGINAL (unprocessed) clip buffer — always re-process from clean signal
  function exportOriginalClipWAVBytes(clipId) {
    for (const t of tracks) {
      for (const c of t.clips) {
        if (c.id === clipId) {
          const buf = c.originalBuffer || c.buffer;
          if (buf) return new Uint8Array(encodeBufferToWAV(buf));
        }
      }
    }
    return new Uint8Array(0);
  }

  // Replace an existing clip's buffer with newly-decoded audio (from server).
  // Preserves startTime so the clip stays at the same timeline position.
  async function replaceClipAudio(clipId, arrayBuffer) {
    await resume();
    try {
      let buffer = await ctx.decodeAudioData(arrayBuffer.slice(0));
      buffer = ensureStereo(buffer);
      for (const t of tracks) {
        for (const c of t.clips) {
          if (c.id === clipId) {
            c.buffer = buffer;
            c.offset = 0;
            c.duration = buffer.duration;
            c.peaks = extractPeaks(buffer, 500);
            console.log('[Engine] Clip replaced: ' + clipId + ' → ' + buffer.duration.toFixed(1) + 's');
            return true;
          }
        }
      }
      console.warn('[Engine] replaceClipAudio: clipId not found ' + clipId);
      return false;
    } catch (e) {
      console.error('[Engine] replaceClipAudio failed:', e);
      return false;
    }
  }

  // Find the most-recent clip id on a given track (helper for correction UI)
  function getLastClipId(trackId) {
    const t = tracks.find(t => t.id === trackId);
    if (!t || t.clips.length === 0) return '';
    return t.clips[t.clips.length - 1].id;
  }

  // ─── Expose to global scope (Flutter reads these) ───
  // Single-arg wrappers for Dart callMethod (only supports 1 arg)
  function addTrackJSON(json) {
    const o = JSON.parse(json);
    return addTrack(o.id, o.name, o.isBeat);
  }
  function loadAudioForTrack(json) {
    // expects {trackId, arrayBuffer} but arrayBuffer passed separately
    return loadAudio(json, arguments[1]);
  }
  function setVolumeJSON(json) {
    const o = JSON.parse(json);
    setTrackVolume(o.id, o.vol);
  }
  function setPanJSON(json) {
    const o = JSON.parse(json);
    setTrackPan(o.id, o.pan);
  }

  window.studioEngine = {
    init, resume,
    addTrack, addTrackJSON, removeTrack,
    setTrackVolume, setVolumeJSON, setTrackPan, setPanJSON,
    setTrackFX, setTrackFXJSON,
    toggleMute, toggleSolo,
    loadAudio,
    play, pause, stop, seekTo, getPlayhead, isPlaying, isRecording,
    getBPM, setBPM, getTotalDuration,
    startRecording, stopRecording,
    moveClip, deleteClip, duplicateClip,
    splitClipAt, trimClip, selectClip, getSelectedClipId,
    moveTrackTo, moveTrackToJSON,
    getAudioDevices, setInputDevice, setOutputDevice,
    setInputLatency, getInputLatency,
    getRecordingLevel, getRecordingSamples,
    toggleMetronome, isMetronomeOn,
    setLoopRegion, setLoopRegionJSON, isLoopOn, getLoopStart, getLoopEnd,
    getTracksJSON, getClipPeaks,
    exportWAV,
    exportClipWAVBytes, exportOriginalClipWAVBytes, replaceClipAudio, getLastClipId,
  };

  console.log('[Engine] studio_engine.js loaded');
})();
