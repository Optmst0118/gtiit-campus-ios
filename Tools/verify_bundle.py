#!/usr/bin/env python3
"""Validate installed bundle structure and, for device builds, signing/profile coherence."""
import argparse,json,plistlib,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('app',type=Path);p.add_argument('--unsigned',action='store_true');args=p.parse_args()
v=json.loads((Path(__file__).parent/'version.json').read_text())
app=args.app; ext=app/'PlugIns/GTIITWidgets.appex'
assert ext.is_dir(),'Missing embedded Widget extension'
ids=[];teams=[]
for bundle in [app,ext]:
 info=plistlib.loads((bundle/'Info.plist').read_bytes())
 assert info['CFBundleVersion']==str(v['build']) and info['CFBundleShortVersionString']==v['marketing'],'Version mismatch'
 ids.append(info['CFBundleIdentifier'])
 if bundle == app:
  assert info['CFBundleDisplayName']=='GTIIT Beta','Incorrect Beta display name'
  assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes']==['gtiit-beta'],'Original URL scheme would conflict'
 if not args.unsigned:
  subprocess.run(['codesign','--verify','--strict',str(bundle)],check=True)
  data=subprocess.check_output(['codesign','-d','--entitlements',':-',str(bundle)],stderr=subprocess.DEVNULL)
  ent=plistlib.loads(data)
  profile=plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(bundle/'embedded.mobileprovision')]))['Entitlements']
  teams.append(ent.get('com.apple.developer.team-identifier'))
  assert ent.get('application-identifier')==profile.get('application-identifier'),'Application ID/profile mismatch'
  assert set(ent.get('com.apple.security.application-groups',[])) <= set(profile.get('com.apple.security.application-groups',[])),'App Group/profile mismatch'
  print(bundle.name,'App Groups:',bool(ent.get('com.apple.security.application-groups')))
assert ids==['io.github.optmst0118.gtiit.beta','io.github.optmst0118.gtiit.beta.widgets']
if teams: assert len(set(teams))==1,'App/Widget signing teams differ'
print('Bundle/extension versions and '+('structure' if args.unsigned else 'signatures/profiles')+' verified:',v)
