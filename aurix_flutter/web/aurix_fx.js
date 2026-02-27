/* AURIX FX — lightweight JS for cursor glow + particles + pause controls */
(function () {
  const root = document.documentElement;
  const perf = matchMedia('(hover: none), (pointer: coarse)').matches || (navigator.maxTouchPoints || 0) > 0;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  root.dataset.aurixPerf = perf ? '1' : '0';
  root.dataset.aurixReduceMotion = reduce ? '1' : '0';

  // Helpers: pause/resume CSS animations on visibility/blur.
  let paused = false;
  function setPaused(v) {
    if (paused === v) return;
    paused = v;
    root.classList.toggle('fx-paused', paused);
  }
  function updatePausedFromVisibility() {
    setPaused(document.visibilityState !== 'visible');
  }
  document.addEventListener('visibilitychange', updatePausedFromVisibility, { passive: true });
  window.addEventListener('blur', () => setPaused(true), { passive: true });
  window.addEventListener('focus', () => setPaused(false), { passive: true });
  updatePausedFromVisibility();

  // Cursor glow (skip on perf / reduced motion)
  const glow = document.createElement('div');
  glow.id = 'aurixCursorGlow';
  document.body.appendChild(glow);

  if (!perf) {
    let raf = 0;
    let px = 0, py = 0;
    function apply() {
      raf = 0;
      root.style.setProperty('--aurix-mx', px + 'px');
      root.style.setProperty('--aurix-my', py + 'px');
    }
    window.addEventListener('mousemove', (e) => {
      px = e.clientX;
      py = e.clientY;
      if (!raf) raf = requestAnimationFrame(apply);
    }, { passive: true });
  } else {
    glow.style.opacity = '0.35';
  }

  // Particles (skip on perf / reduced motion)
  if (perf || reduce) return;

  const canvas = document.createElement('canvas');
  canvas.id = 'aurixParticles';
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d', { alpha: true });
  if (!ctx) return;

  const dpr = () => Math.min(2, window.devicePixelRatio || 1);
  let w = 0, h = 0, ratio = 1;
  function resize() {
    ratio = dpr();
    w = Math.floor(window.innerWidth);
    h = Math.floor(window.innerHeight);
    canvas.width = Math.floor(w * ratio);
    canvas.height = Math.floor(h * ratio);
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
  }
  window.addEventListener('resize', resize, { passive: true });
  resize();

  const N = 26;
  const parts = [];
  for (let i = 0; i < N; i++) {
    parts.push({
      x: Math.random() * w,
      y: Math.random() * h,
      vx: (Math.random() - 0.5) * 0.16,
      vy: (Math.random() - 0.5) * 0.12,
      r: 0.9 + Math.random() * 1.8,
      a: 0.08 + Math.random() * 0.18,
      t: Math.random() * Math.PI * 2,
    });
  }

  let frame = 0;
  let last = performance.now();
  let running = true;

  function tick(now) {
    if (!running || paused) {
      frame = requestAnimationFrame(tick);
      return;
    }
    const dt = Math.min(32, now - last);
    last = now;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.save();
    ctx.scale(ratio, ratio);

    for (const p of parts) {
      p.t += dt * 0.001;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      // wrap
      if (p.x < -20) p.x = w + 20;
      if (p.x > w + 20) p.x = -20;
      if (p.y < -20) p.y = h + 20;
      if (p.y > h + 20) p.y = -20;

      const pulse = 0.65 + 0.35 * Math.sin(p.t);
      const alpha = p.a * pulse;
      ctx.beginPath();
      ctx.fillStyle = `rgba(255, 107, 53, ${alpha})`;
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fill();

      // tiny glow
      ctx.beginPath();
      ctx.fillStyle = `rgba(255, 143, 0, ${alpha * 0.5})`;
      ctx.arc(p.x + 1.4, p.y - 0.8, p.r * 1.8, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
    frame = requestAnimationFrame(tick);
  }

  function stop() { running = false; }
  function start() { running = true; last = performance.now(); }
  window.addEventListener('blur', stop, { passive: true });
  window.addEventListener('focus', start, { passive: true });
  document.addEventListener('visibilitychange', () => { paused = document.visibilityState !== 'visible'; }, { passive: true });

  frame = requestAnimationFrame(tick);
})();

