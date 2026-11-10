#!/usr/bin/env python3
"""Apply repository version policy; source of truth: Tools/version.json."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('kind',choices=['optimization','feature','feature-ui']);a=p.parse_args()
f=Path(__file__).with_name('version.json');v=json.loads(f.read_text());major,minor,patch=map(int,v['marketing'].split('.'))
if a.kind=='feature': patch+=1
elif a.kind=='feature-ui': minor+=1;patch=0
previous=v.get('prerelease','');n=(int(previous.split('.')[-1])+1 if previous.startswith('beta.') else 1) if a.kind=='optimization' else 1
v.update(marketing=f'{major}.{minor}.{patch}',prerelease=f'beta.{n}',build=v['build']+1)
f.write_text(json.dumps(v,separators=(',',':'))+'\n');print(v)
