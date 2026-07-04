/**
 * reveal.js — settle choreography.
 *
 * Elements marked [data-settle] arrive like objects placed on a table one by
 * one: a short drop, a spring settle into their resting tilt, staggered by
 * the value of the attribute (ms). Triggered the moment they enter the
 * viewport — no "scroll further to see".
 *
 * Reduced-motion users get everything instantly; the choreography is a
 * courtesy, not a gate.
 */
export function initReveal() {
  const items = document.querySelectorAll('[data-settle]');
  if (!items.length) return;

  if (matchMedia('(prefers-reduced-motion: reduce)').matches) {
    items.forEach((el) => el.classList.add('settled'));
    return;
  }

  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        io.unobserve(e.target);
        e.target.style.transitionDelay = `${Number(e.target.dataset.settle) || 0}ms`;
        e.target.classList.add('settled');
        // clear the delay after arrival so hover physics stay immediate
        e.target.addEventListener('transitionend', () => (e.target.style.transitionDelay = '0ms'), { once: true });
      }
    },
    { rootMargin: '0px 0px -6% 0px' }
  );
  items.forEach((el) => io.observe(el));
}
