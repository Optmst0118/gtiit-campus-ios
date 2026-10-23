#!/usr/bin/env python3
"""Build an isolated visual-review app from the original product views."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import json
ROOT = Path(__file__).resolve().parent.parent
folder = Path(tempfile.mkdtemp(prefix='gtiit-ui-review-')) / 'UIReview.app'
folder.mkdir()
sdk = subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
sources = sorted(str(p) for p in (ROOT/'GTIIT').rglob('*.swift') if p.name != 'GTIITApp.swift')
subprocess.run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-DDEBUG','-parse-as-library',*sources,str(ROOT/'Tests/UIReviewHarness.swift'),'-o',str(folder/'UIReview')],check=True)
(folder/'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier':'local.gtiit.uireview','CFBundleExecutable':'UIReview','CFBundleName':'UIReview','CFBundlePackageType':'APPL',
    'CFBundleVersion':str(json.loads((ROOT/'Tools/version.json').read_text())['build']),'CFBundleShortVersionString':json.loads((ROOT/'Tools/version.json').read_text())['marketing'],'UIDeviceFamily':[1,2],'LSRequiresIPhoneOS':True,'UILaunchScreen':{},
    'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
    'LSApplicationQueriesSchemes':['atrust'],
    'NSSupportsLiveActivities':True,'NSLocationWhenInUseUsageDescription':'Suggest shuttle directions in the review app.','NSFaceIDUsageDescription':'Visual review of local app-lock UI.',
    'NSAppTransportSecurity':{'NSAllowsArbitraryLoadsInWebContent':True}
}))
shutil.copytree(ROOT/'GTIIT/Resources/WebAppearance', folder/'WebAppearance')
shutil.copytree(ROOT/'GTIIT/Resources/CampusData', folder/'CampusData')
shutil.copyfile(ROOT/'GTIIT/Resources/Assets.xcassets/CampusMark.imageset/CampusMark.png', folder/'CampusMark.png')
Path('/tmp/gtiit-ui-review-path').write_text(str(folder))
print(folder)
