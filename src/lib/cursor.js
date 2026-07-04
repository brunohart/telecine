/**
 * cursor.js — cursor as presence.
 *
 * A 12px dot in difference blend that trails the pointer with lerp — weighted,
 * like dragging a fingertip through wet ink. It expands when approaching
 * anything interactive: the interface inferring intent before the click.
 *
 * Touch devices never see it; reduced-motion users never see it. The native
 * cursor stays available — the dot is presence, not replacement, except over
 * the set itself where a broadcast wants the room dark.
 */
export function initCursor() {
  if (matchMedia('(pointer: coarse)').matches) return;
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const dot = document.createElement('div');
  dot.className = 'cursor-dot';
  dot.setAttribute('aria-hidden', 'true');
  document.body.appendChild(dot);
  document.documentElement.classList.add('has-cursor');

  let tx = -100, ty = -100, x = -100, y = -100;
  let hot = false;

  addEventListener('mousemove', (e) => { tx = e.clientX; ty = e.clientY; }, { passive: true });

  const HOT = 'a, button, [role="button"], input, summary, [data-hot]';
  addEventListener('mouseover', (e) => {
    const next = !!e.target.closest?.(HOT);
    if (next !== hot) {
      hot = next;
      dot.classList.toggle('hot', hot);
    }
  }, { passive: true });

  document.addEventListener('mouseleave', () => { tx = -100; ty = -100; });

  (function loop() {
    // lerp 0.16 — enough drag to feel the mass, never enough to feel lost
    x += (tx - x) * 0.16;
    y += (ty - y) * 0.16;
    dot.style.transform = `translate3d(${x}px, ${y}px, 0) translate(-50%, -50%)`;
    requestAnimationFrame(loop);
  })();
}
