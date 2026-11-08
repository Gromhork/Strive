"""Merge {key: [en, de]} from a python-literal file into the ARB files.

Usage: python tool/add_l10n.py tool/l10n/<block>.py && flutter gen-l10n
Placeholders {name} keep their order; names in INT become int, all others String.
"""
import json, re, sys, ast, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INT = {'count','level','xp','days','hours','done','target','n','x','y','total','min','sec','km','weeks','reps','pct','bpm','zone','steps','meters','rir','lo','hi','sets','each','age','kg','sessions','laps','lengths','m'}
src = ast.literal_eval(open(sys.argv[1], encoding='utf-8').read())
for idx, lang in enumerate(['en', 'de']):
    p = rf'D:\AI-Master\Strive\lib\l10n\app_{lang}.arb'
    arb = json.load(open(p, encoding='utf-8'))
    for k, v in src.items():
        arb[k] = v[idx]
        ph = list(dict.fromkeys(re.findall(r'\{(\w+)\}', v[0])))
        if lang == 'en':
            if ph:
                arb['@' + k] = {'placeholders': {n: {'type': 'int' if n in INT else 'String'} for n in ph}}
            else:
                arb.pop('@' + k, None)
    json.dump(arb, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('merged', len(src))
