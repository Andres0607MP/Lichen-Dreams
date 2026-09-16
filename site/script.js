// ─────────────────────────────────────────────────────────
// Edita este array cada vez que publiques una nueva versión.
// La primera entrada (índice 0) es SIEMPRE la más reciente.
// ─────────────────────────────────────────────────────────
const VERSIONS = [
  {
    version: "1.0.0",
    date: "2026-09-16",
    changelog: [
      "Primera versión pública de Lichen Dreams",
      "Análisis de líquenes con IA y visión artificial",
      "Mapa interactivo de calidad del aire",
      "Módulo educativo Liquenpedia"
    ],
    url: "https://drive.google.com/uc?export=download&id=1uuuKhhblH0lGlRF31RnIHOq1qQjv9Lrz",
    size: ""
  }
  // Ejemplo para la siguiente versión:
  // {
  //   version: "1.1.0",
  //   date: "2026-10-02",
  //   changelog: ["Corrige fallo al subir fotos", "Mejora tiempos de análisis"],
  //   url: "https://...",
  //   size: "24 MB"
  // },
];

function render() {
  const [latest, ...older] = VERSIONS;
  const currentBlock = document.getElementById('current-block');
  const historyList = document.getElementById('history-list');

  if (!latest) {
    currentBlock.innerHTML = '<p class="empty-note">Todavía no hay versiones publicadas.</p>';
    return;
  }

  currentBlock.innerHTML = `
    <div class="current-eyebrow">Última versión</div>
    <p class="current-version">v${latest.version}</p>
    <p class="current-date">${formatDate(latest.date)}</p>
    <ul class="changelog">
      ${latest.changelog.map(item => `<li>${item}</li>`).join('')}
    </ul>
    <a class="btn-download" href="${latest.url}">⬇ Descargar APK</a>
    <div class="meta-row">
      ${latest.size ? `<span>${latest.size}</span><span>·</span>` : ''}
      <span>Android</span>
    </div>
  `;

  if (older.length === 0) {
    historyList.innerHTML = '<p class="empty-note">Esta es la primera versión publicada de Lichen Dreams.</p>';
  } else {
    historyList.innerHTML = older.map(v => `
      <div class="version-row">
        <div class="version-info">
          <div class="v-name">v${v.version}</div>
          <div class="v-date">${formatDate(v.date)}</div>
        </div>
        <a class="link-download" href="${v.url}">Descargar</a>
      </div>
    `).join('');
  }
}

function formatDate(iso) {
  const d = new Date(iso + 'T00:00:00');
  return d.toLocaleDateString('es-CO', { day: 'numeric', month: 'long', year: 'numeric' });
}

render();
