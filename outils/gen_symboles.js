// Génère les images SVG des symboles retenus et le catalogue Dart.
const fs = require('fs');
const ms = require('milsymbol').default;
const [md, outAssets, outDart] = process.argv.slice(2);
const texte = fs.readFileSync(md, 'utf8');
const familles = {
  'Types d\'unités': 'unite', 'Matériels et menaces': 'materiel',
  'Points de manœuvre': 'point', 'Obstacles et dangers': 'obstacle',
};
let famille = null; const entrees = [];
for (const l of texte.split('\n')) {
  const h = l.match(/^## (.*)/); if (h) { famille = familles[h[1].trim()] || null; continue; }
  if (!famille) continue;
  const m = l.match(/^- (.+?) — `([A-Z0-9-]{15})`/);
  const po = l.match(/^- (Poste d'observation) — dessin appli/);
  if (m) entrees.push({ nom: m[1], sidc: m[2], famille });
  else if (po) entrees.push({ nom: po[1], sidc: 'PO', famille });
}
fs.mkdirSync(outAssets, { recursive: true });
const ancres = {};
function ecrire(sidc) {
  const s = new ms.Symbol(sidc, { size: 40 });
  if (!s.isValid()) throw new Error('invalide ' + sidc);
  const svg = s.asSVG(); const a = s.getAnchor(); const t = s.getSize();
  fs.writeFileSync(`${outAssets}/${sidc.replace(/-/g, '_')}.svg`, svg);
  ancres[sidc] = [t.width, t.height, a.x, a.y];
}
const set = (s, i, c) => s.slice(0, i) + c + s.slice(i + 1);
for (const e of entrees) {
  if (e.sidc === 'PO') continue;
  const affs = ['F', 'H'];
  for (const af of affs) {
    const base = set(e.sidc, 1, af);
    if (e.famille === 'unite') {
      for (const pc of ['-', 'A']) for (const ech of ['-', 'B', 'D', 'E'])
        ecrire(set(set(base, 10, pc), 11, ech));
    } else ecrire(base);
  }
}
// Poste d'observation : dessiné ici (triangle avec un point au centre).
for (const [af, coul] of [['F', '#000000'], ['H', '#FF0000']]) {
  fs.writeFileSync(`${outAssets}/PO_${af}.svg`,
    `<svg xmlns="http://www.w3.org/2000/svg" width="40" height="36" viewBox="0 0 40 36"><path d="M20,3 L37,33 L3,33 Z" fill="none" stroke="${coul}" stroke-width="3"/><circle cx="20" cy="23" r="3.5" fill="${coul}"/></svg>`);
  ancres['PO_' + af] = [40, 36, 20, 23];
}
const esc = s => s.replace(/'/g, "\\'");
let dart = `// Fichier généré par outils/gen_symboles.js à partir de la liste validée
// (symboles-otan-retenus.md). Ne pas modifier à la main.
part of 'symboles.dart';

const catalogue = <SymboleCatalogue>[
${entrees.map(e => `  SymboleCatalogue('${esc(e.nom)}', '${e.sidc}', FamilleSymbole.${e.famille}),`).join('\n')}
];

/// Taille et point d'ancrage de chaque image : (largeur, hauteur, x, y).
const ancres = <String, (double, double, double, double)>{
${Object.entries(ancres).map(([k, v]) => `  '${k}': (${v.map(n => (+n).toFixed(1)).join(', ')}),`).join('\n')}
};
`;
fs.writeFileSync(outDart, dart);
console.log(entrees.length, 'symboles,', Object.keys(ancres).length, 'images');
