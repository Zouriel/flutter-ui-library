"""Builds docs/inventory.md: every public component/directive/service/type of @zouriel/ui (Angular),
with its selector, inputs, models, outputs and doc comment, as the checklist for the Flutter port."""
import re, sys
from pathlib import Path

src = Path(sys.argv[1])  # projects/ui
out = Path(sys.argv[2])

def doc_before(text, idx):
    m = re.search(r'/\*\*((?:(?!\*/).)*)\*/\s*(?:@\w+\([^@]*?\)\s*)?$', text[:idx], re.S)
    if not m: return ''
    lines = [re.sub(r'^\s*\*\s?', '', l) for l in m.group(1).strip().splitlines()]
    return ' '.join(l.strip() for l in lines if l.strip() and not l.strip().startswith('@'))

rows = []
for entry in sorted(p for p in src.iterdir() if (p / 'ng-package.json').exists() or p.name == 'src'):
    files = sorted(f for f in (entry / 'src').rglob('*.ts') if '.spec.' not in f.name) if (entry / 'src').exists() else []
    if entry.name == 'src': files = sorted(f for f in entry.rglob('*.ts') if '.spec.' not in f.name)
    section = [f'## {entry.name}\n']
    for f in files:
        t = f.read_text()
        for m in re.finditer(r'@(Component|Directive|Injectable)\(\{(.*?)\}\)\s*export (?:abstract )?class (\w+)', t, re.S):
            kind, meta, name = m.groups()
            sel = re.search(r"selector:\s*'([^']+)'", meta)
            body_start = m.end()
            nxt = re.search(r'\n}\n', t[body_start:])
            body = t[body_start: body_start + (nxt.start() if nxt else len(t))]
            ins, models, outs, methods = [], [], [], []
            for im in re.finditer(r'^\s+(?:readonly\s+)?(\w+)\s*=\s*(input|model|output)(?:\.required)?(?:<([^;]*?)>)?\(([^;]*?)\);', body, re.M):
                n, fn, ty, args = im.groups()
                alias = re.search(r"alias:\s*'([^']+)'", args or '')
                label = f"`{alias.group(1) if alias else n}`" + (f": {ty.strip()}" if ty else '')
                d = args.split(',')[0].strip() if args and fn != 'output' else ''
                if d and not d.startswith('{'): label += f" = {d[:60]}"
                {'input': ins, 'model': models, 'output': outs}[fn].append(label)
            for mm in re.finditer(r'^  (?!protected|private|constructor|readonly|get |set )(\w+)\(([^)]*)\)\s*:\s*[^{]+\{', body, re.M):
                if mm.group(1) not in ('if', 'for', 'switch', 'ngOnInit', 'ngOnDestroy', 'writeValue', 'registerOnChange', 'registerOnTouched', 'setDisabledState', 'ngAfterViewInit', 'ngOnChanges'):
                    methods.append(f"`{mm.group(1)}({mm.group(2).strip()[:50]})`")
            cva = 'NG_VALUE_ACCESSOR' in t and name in t[t.find('NG_VALUE_ACCESSOR')-400:t.find('NG_VALUE_ACCESSOR')+200]
            section.append(f"### {name} ({kind.lower()}{', `' + sel.group(1) + '`' if sel else ''}){' — form control' if cva else ''}")
            section.append(f"File: `{f.relative_to(src)}`  ")
            d = doc_before(t, m.start())
            if d: section.append(f"{d}  ")
            if ins: section.append('- Inputs: ' + '; '.join(ins))
            if models: section.append('- Two-way: ' + '; '.join(models))
            if outs: section.append('- Outputs: ' + '; '.join(outs))
            if methods: section.append('- Methods: ' + ', '.join(methods))
            section.append('- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase\n')
            rows.append(name)
        for m in re.finditer(r'^export (interface|type|function|const) (\w+)', t, re.M):
            if m.group(2) not in rows:
                section.append(f"- {m.group(1)} `{m.group(2)}` ({f.name})")
    section.append('')
    out_parts = section
    with out.open('a') as fh: fh.write('\n'.join(out_parts) + '\n')
print(len(rows), 'components/directives/services')
