export function initDisclosure(document) {
  const button = document.getElementById('toggle');
  const panel = document.getElementById('details');
  if (!button || !panel) throw new Error('Disclosure elements are missing');
  const apply = (expanded) => { button.setAttribute('aria-expanded', String(expanded)); panel.hidden = !expanded; };
  apply(false);
  button.addEventListener('click', () => apply(button.getAttribute('aria-expanded') !== 'true'));
}
