// Generates packages/zouriel_ui/lib/src/theme/tokens.g.dart from the Angular library's CSS tokens.
//
// A real browser resolves the cascade (var(), color-mix(), per-theme overrides, derived defaults),
// so the Dart values are exactly what the web components render with, for all 15 themes.
//
//   node tool/gen_tokens.mjs <angular styles dir> <output .dart> <chromium executable>
//
// Needs playwright-core; PLAYWRIGHT points at its index.mjs (defaults to the Angular workspace's copy).
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [stylesDir, outFile, chrome] = process.argv.slice(2);
const pw = process.env.PLAYWRIGHT ?? '/home/zouriel/personal/angularUiLib/ui-workspace/node_modules/playwright-core/index.mjs';
const { chromium } = await import(pw);

const files = ['tokens.css', 'theme-palettes.css', 'theme-dark-orange.css', 'theme-maldives.css'];
// Web fonts are fetched at runtime on the web; the Flutter package bundles its own, so drop the import.
const css = files.map((f) => readFileSync(join(stylesDir, f), 'utf8').replace(/@import url\([^)]*\);/g, '')).join('\n');

// The web data-theme names. A hyphenated web name becomes a camelCase enum value
// (maldives-dark -> UiThemeName.maldivesDark).
const THEMES = ['dark', 'light', 'lightOrange', 'lightPink', 'lightTeal', 'lightPurple', 'lightPurpleGold',
  'darkPink', 'darkTeal', 'darkPurple', 'goldBlack', 'goldRed', 'darkOrange', 'maldives', 'maldives-dark'];
const enumName = (t) => t.replace(/-([a-z])/g, (_, c) => c.toUpperCase());

const names = [...new Set([...css.matchAll(/(--ui-[a-z0-9-]+)\s*:/g)].map((m) => m[1]))]
  .filter((n) => !n.startsWith('--ui-winter-') && !n.startsWith('--ui-z-'))
  // CSS filter lists; UiTokens carries their inputs (glassSheet*/glassClear* floor, ceiling, blur,
  // saturate) and the widgets build them.
  .filter((n) => n !== '--ui-glass-sheet-filter' && n !== '--ui-glass-clear-filter');

function kind(n) {
  // Density scales (0.45.0): plain numbers, checked before the --ui-font- family names.
  if (n === '--ui-font-scale' || n === '--ui-density-scale') return 'number';
  if (n.startsWith('--ui-gradient-')) return 'gradient';
  if (/^--ui-(shadow-\d|glow-|focus-ring)/.test(n)) return 'shadow';
  if (/^--ui-(size|space|font-size|radius)/.test(n) || n === '--ui-glass-blur' || n === '--ui-glass-sheet-blur' || n === '--ui-glass-clear-blur') return 'length';
  if (n.startsWith('--ui-tracking-')) return 'em';
  if (n === '--ui-scale-press' || n === '--ui-grain-opacity' || /^--ui-glass-sheet-(tint|floor|ceiling)$/.test(n) || /^--ui-glass-clear-(tint|floor|ceiling|saturate)$/.test(n)) return 'number';
  if (n.startsWith('--ui-motion-')) return 'duration';
  if (n.startsWith('--ui-ease-')) return 'curve';
  if (n.startsWith('--ui-font-') ) return 'font';
  return 'color';
}

const browser = await chromium.launch({ executablePath: chrome });
const page = await browser.newPage();
await page.setContent(`<html><head><style>${css}</style></head><body></body></html>`);

const data = {};
for (const theme of THEMES) {
  data[theme] = await page.evaluate(({ theme, names, kinds }) => {
    const host = document.createElement('div');
    host.setAttribute('data-theme', theme);
    document.body.appendChild(host);
    const probe = document.createElement('div');
    host.appendChild(probe);
    const out = {};
    for (const n of names) {
      const raw = getComputedStyle(host).getPropertyValue(n).trim();
      if (!raw) { out[n] = null; continue; }
      const k = kinds[n];
      probe.removeAttribute('style');
      if (k === 'color') { probe.style.color = `var(${n})`; out[n] = getComputedStyle(probe).color; }
      else if (k === 'gradient') { probe.style.backgroundImage = `var(${n})`; out[n] = getComputedStyle(probe).backgroundImage; }
      else if (k === 'shadow') { probe.style.boxShadow = `var(${n})`; out[n] = getComputedStyle(probe).boxShadow; }
      else out[n] = raw;
    }
    host.remove();
    return out;
  }, { theme, names, kinds: Object.fromEntries(names.map((n) => [n, kind(n)])) });
}
// Compact density (0.45.0): the tokens tokens.css's [data-density="compact"] block changes. They
// are theme-independent sizes and scales, resolved under the base theme.
const compactNames = [...new Set([...(/\[data-density="compact"\] \{([^}]*)\}/.exec(css)?.[1] ?? '').matchAll(/(--ui-[a-z0-9-]+)\s*:/g)].map((m) => m[1]))];
if (!compactNames.length) throw new Error('no [data-density="compact"] block in tokens.css');
const compactRaw = await page.evaluate((names) => {
  const host = document.createElement('div');
  host.setAttribute('data-theme', 'dark');
  host.setAttribute('data-density', 'compact');
  document.body.appendChild(host);
  const out = Object.fromEntries(names.map((n) => [n, getComputedStyle(host).getPropertyValue(n).trim()]));
  host.remove();
  return out;
}, compactNames);
await browser.close();

// ---------- parsing computed values ----------
function parseColor(s) {
  s = s.trim();
  let m = /^rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)$/.exec(s);
  if (m) return [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
  m = /^color\(srgb ([\d.e-]+) ([\d.e-]+) ([\d.e-]+)(?: \/ ([\d.e-]+))?\)$/.exec(s);
  if (m) return [m[1] * 255, m[2] * 255, m[3] * 255, m[4] === undefined ? 1 : +m[4]];
  throw new Error('colour? ' + s);
}
function dartColor(c) {
  const [r, g, b, a] = c.map((v, i) => (i < 3 ? Math.max(0, Math.min(255, Math.round(v))) : Math.max(0, Math.min(1, v))));
  const hex = [Math.round(a * 255), r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('');
  return `Color(0x${hex})`;
}
// Split on commas that are not inside parentheses.
function splitTop(s) {
  const parts = []; let depth = 0, cur = '';
  for (const ch of s) {
    if (ch === '(') depth++;
    if (ch === ')') depth--;
    if (ch === ',' && depth === 0) { parts.push(cur.trim()); cur = ''; } else cur += ch;
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}
function takeColor(s) {
  const m = /^(rgba?\([^)]*\)|color\([^)]*\))\s*(.*)$/.exec(s.trim());
  return m ? [parseColor(m[1]), m[2]] : null;
}
function dartGradient(s) {
  const m = /^linear-gradient\((.*)\)$/.exec(s.trim());
  if (!m) throw new Error('gradient? ' + s);
  const parts = splitTop(m[1]);
  let angle = 180;
  if (/deg$/.test(parts[0])) angle = parseFloat(parts.shift());
  else if (/^to /.test(parts[0])) { const t = parts.shift(); angle = { 'to right': 90, 'to left': 270, 'to top': 0, 'to bottom': 180 }[t] ?? 180; }
  const colors = [], stops = [];
  for (const p of parts) {
    const [c, rest] = takeColor(p);
    colors.push(dartColor(c));
    stops.push(rest ? parseFloat(rest) / 100 : null);
  }
  stops.forEach((v, i) => { if (v === null) stops[i] = parts.length === 1 ? 0 : i / (parts.length - 1); });
  return `UiGradientSpec(angle: ${angle}, colors: [${colors.join(', ')}], stops: [${stops.map((x) => x.toFixed(3)).join(', ')}])`;
}
function dartShadows(s) {
  if (s === 'none') return 'const <BoxShadow>[]';
  // CSS paints the first shadow on top; Flutter paints a BoxShadow list in order, the last on top.
  // Reverse it, so a ring like the focus ring ("2px page colour, then 4px focus colour") keeps its gap.
  return '[' + splitTop(s).reverse().map((p) => {
    const inset = /\binset\b/.test(p);
    const [c, rest] = takeColor(p.replace(/\binset\b/, ''));
    const [x, y, blur, spread] = rest.trim().split(/\s+/).map((v) => parseFloat(v) || 0);
    if (inset) throw new Error('inset shadows are not supported: ' + s);
    // A spread-only shadow is a ring (the focus ring); UiRingShadow paints it outside the box only, as CSS does.
    if (!x && !y && !blur && spread > 0) return `UiRingShadow(color: ${dartColor(c)}, spread: ${spread})`;
    return `BoxShadow(color: ${dartColor(c)}, offset: Offset(${x}, ${y}), blurRadius: ${blur}, spreadRadius: ${spread ?? 0})`;
  }).join(', ') + ']';
}
const ms = (s) => (s.endsWith('ms') ? parseFloat(s) : parseFloat(s) * 1000);
function dartCurve(s) {
  const m = /cubic-bezier\(([^)]*)\)/.exec(s);
  if (!m) throw new Error('curve? ' + s);
  return `Cubic(${m[1].split(',').map((v) => parseFloat(v)).join(', ')})`;
}
function dartFont(s) {
  const fams = splitTop(s).map((f) => f.replace(/["']/g, '').trim());
  const generic = new Set(['system-ui', '-apple-system', 'sans-serif', 'monospace', 'ui-monospace', 'Segoe UI', 'Roboto', 'SF Mono', 'SFMono-Regular', 'Cascadia Code', 'Menlo']);
  const named = fams.filter((f) => !generic.has(f));
  return named.length ? `'${named[0]}'` : 'null';
}

// A length in px; rem (the ui-text heading sizes) at the browser's 16px.
function lengthPx(n, v) {
  if (/px$/.test(v)) return String(parseFloat(v));
  if (/rem$/.test(v)) return String(Math.round(parseFloat(v) * 16 * 1000) / 1000);
  throw new Error(n + ' ' + v);
}

const camel = (n) => n.replace(/^--ui-(color-)?/, '').replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
const dartName = (n) => {
  let c = camel(n);
  if (/^\d/.test(c)) c = '_' + c;
  return ({ text: 'text', switch: 'switchColor' })[c] ?? c;
};

const fields = names.map((n) => {
  const k = kind(n);
  const present = THEMES.every((t) => data[t][n] !== null);
  const type = { color: 'Color', gradient: 'UiGradientSpec', shadow: 'List<BoxShadow>', length: 'double', em: 'double',
    number: 'double', duration: 'Duration', curve: 'Cubic', font: 'String' }[k];
  const nullable = !present || k === 'font';
  return { n, k, name: dartName(n), type: nullable ? type + '?' : type, nullable };
});

function value(f, theme) {
  const v = data[theme][f.n];
  if (v === null || v === undefined) return 'null';
  switch (f.k) {
    case 'color': return dartColor(parseColor(v));
    case 'gradient': return dartGradient(v);
    case 'shadow': return dartShadows(v);
    case 'length': return lengthPx(f.n, v);
    case 'em': return String(parseFloat(v));
    case 'number': return String(parseFloat(v));
    case 'duration': return `Duration(milliseconds: ${ms(v)})`;
    case 'curve': return dartCurve(v);
    case 'font': return dartFont(v);
  }
}

function lerpExpr(f) {
  const a = f.name, b = `other.${f.name}`;
  switch (f.k) {
    case 'color': return f.nullable ? `Color.lerp(${a}, ${b}, t)` : `Color.lerp(${a}, ${b}, t)!`;
    case 'gradient': return f.nullable ? `UiGradientSpec.lerp(${a}, ${b}, t)` : `UiGradientSpec.lerp(${a}, ${b}, t)!`;
    case 'shadow': return f.nullable ? `UiRingShadow.lerpList(${a}, ${b}, t)` : `UiRingShadow.lerpList(${a}, ${b}, t)!`;
    case 'length': case 'em': case 'number':
      return f.nullable ? `lerpDouble(${a}, ${b}, t)` : `lerpDouble(${a}, ${b}, t)!`;
    default: return `t < 0.5 ? ${a} : ${b}`;
  }
}

const out = [];
out.push(`// GENERATED by tool/gen_tokens.mjs from the @zouriel/ui (Angular) stylesheets. Do not edit by hand.
// Re-run the generator after changing tokens.css, theme-palettes.css, theme-dark-orange.css or theme-maldives.css.
// ignore_for_file: lines_longer_than_80_chars, prefer_const_constructors

part of 'tokens.dart';

/// The ${THEMES.length} built-in themes, in the same order and with the same names as the web library
/// (a hyphenated web name camelCased: maldives-dark is maldivesDark).
enum UiThemeName { ${THEMES.map(enumName).join(', ')} }

/// Every design token of one theme, resolved. Components read these and nothing else.
@immutable
class UiTokens {
  const UiTokens({
${fields.map((f) => `    ${f.nullable ? '' : 'required '}this.${f.name},`).join('\n')}
  });

${fields.map((f) => `  /// \`${f.n}\`\n  final ${f.type} ${f.name};`).join('\n')}

  /// Interpolates every token, so a theme change can animate.
  UiTokens lerp(UiTokens other, double t) => UiTokens(
${fields.map((f) => `        ${f.name}: ${lerpExpr(f)},`).join('\n')}
      );

  /// A copy with some tokens replaced (e.g. a theme island's glass).
  UiTokens copyWith({
${fields.map((f) => `    ${f.type.endsWith('?') ? f.type : f.type + '?'} ${f.name},`).join('\n')}
  }) => UiTokens(
${fields.map((f) => `        ${f.name}: ${f.name} ?? this.${f.name},`).join('\n')}
      );
}

/// Resolved tokens for each built-in theme.
const Map<UiThemeName, UiTokens> uiThemeTokens = {
${THEMES.map((t) => `  UiThemeName.${enumName(t)}: UiTokens(\n${fields.map((f) => `    ${f.name}: ${value(f, t)},`).join('\n')}\n  ),`).join('\n')}
};
`);
const compactFields = compactNames.map((n) => {
  const f = fields.find((x) => x.n === n);
  if (!f || !['length', 'number'].includes(f.k)) throw new Error('compact token must be a length or number token: ' + n);
  return { f, v: f.k === 'length' ? lengthPx(n, compactRaw[n]) : String(parseFloat(compactRaw[n])) };
});
out.push(`
/// What compact density (0.45.0, [UiDensity.compact]) changes: the sizes and scales of tokens.css's
/// \`[data-density="compact"]\` block. Spacing, radii and the touch target are not in it.
const Map<String, double> uiCompactDensityTokens = {
${compactFields.map(({ f, v }) => `  '${f.n}': ${v},`).join('\n')}
};

/// Compact density applied to a theme's tokens.
extension UiCompactDensity on UiTokens {
  UiTokens withCompactDensity() => copyWith(
${compactFields.map(({ f, v }) => `        ${f.name}: ${v},`).join('\n')}
      );
}
`);
writeFileSync(outFile, out.join('\n'));
console.log(`${fields.length} tokens x ${THEMES.length} themes -> ${outFile}`);
