/* AURIX FX — cursor glow only (no particles, no noise, no heavy animations) */
(function () {
  var root = document.documentElement;
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var coarse = matchMedia('(hover: none), (pointer: coarse)').matches;

  var glow = document.createElement('div');
  glow.id = 'aurixCursorGlow';
  document.body.insertBefore(glow, document.body.firstChild);

  if (!coarse && !reduce) {
    var raf = 0, px = 0, py = 0;
    function apply() {
      raf = 0;
      root.style.setProperty('--aurix-mx', px + 'px');
      root.style.setProperty('--aurix-my', py + 'px');
    }
    window.addEventListener('mousemove', function (e) {
      px = e.clientX;
      py = e.clientY;
      if (!raf) raf = requestAnimationFrame(apply);
    }, { passive: true });
  } else {
    glow.style.opacity = '0';
  }
})();
