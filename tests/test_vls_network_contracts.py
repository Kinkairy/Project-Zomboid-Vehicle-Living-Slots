"""Compare every vanilla constructor wrapper against the installed game API."""
import argparse,json,pathlib,re
p=argparse.ArgumentParser();p.add_argument('--mod-root',type=pathlib.Path,required=True);p.add_argument('--game-lua',type=pathlib.Path,required=True);a=p.parse_args()
patterns=[(re.compile(r'function\s+(\w+)([:.])new\s*\((.*?)\)',re.S),False),(re.compile(r'(\w+)\.new\s*=\s*function\s*\((.*?)\)',re.S),True)]
def signatures(path):
 s=path.read_text(errors='replace')
 for regex,assignment in patterns:
  for m in regex.finditer(s):
   args=[v.strip() for v in m.group(2 if assignment else 3).split(',') if v.strip()]
   if assignment and args and args[0]=='self':args=args[1:]
   yield m.group(1),args,s[:m.start()].count('\n')+1
native={cls:args for p in a.game_lua.rglob('*.lua') for cls,args,line in signatures(p)}
rows=[]
for path in (a.mod_root/'workshop/Contents/mods').rglob('*.lua'):
 for cls,args,line in signatures(path):
  if cls in native:rows.append({'class':cls,'path':str(path.relative_to(a.mod_root)),'line':line,'native':native[cls],'wrapper':args,'match':args==native[cls]})
assert len(rows)>=9,'Constructor discovery unexpectedly incomplete'
print(json.dumps(rows,indent=2))
assert all(r['match'] for r in rows),'Vanilla constructor parameter names/order changed'
print('PASS all',len(rows),'vanilla constructor wrappers preserve exact names/order')
