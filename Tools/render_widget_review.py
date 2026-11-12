"""Render actual Widget views in a disposable simulator, without preview-only layout."""
from pathlib import Path
import subprocess, tempfile, plistlib, shutil, sys, os, uuid
from widget_project import SHARED_SOURCES
root=Path(__file__).resolve().parent.parent
app=Path(tempfile.mkdtemp(prefix='gtiit-widget-review-'))/'WidgetReview.app';app.mkdir()
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
sources=[str(root/'GTIIT'/rel) for rel in SHARED_SOURCES]
sources += [str(p) for p in (root/'GTIITWidgets').glob('*.swift') if p.name!='GTIITWidgetBundle.swift']
subprocess.run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-parse-as-library',*sources,str(root/'Tests/WidgetReviewHarness.swift'),'-o',str(app/'WidgetReview')],check=True)
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.gtiit.widgetreview','CFBundleExecutable':'WidgetReview','CFBundleName':'WidgetReview','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1','UIDeviceFamily':[1],'UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False}}))
for lang in ['en','zh-Hans']:shutil.copytree(root/f'GTIIT/Resources/{lang}.lproj',app/f'{lang}.lproj')
if '--build-only' in sys.argv:
    print(app)
    raise SystemExit(0)
device=sys.argv[1]
subprocess.run(['xcrun','simctl','install',device,str(app)],check=True)
run_id=str(uuid.uuid4())
launch_env=os.environ.copy();launch_env['SIMCTL_CHILD_WIDGET_REVIEW_RUN_ID']=run_id
subprocess.run(['xcrun','simctl','launch','--terminate-running-process',device,'local.gtiit.widgetreview'],check=True,timeout=60,env=launch_env)
container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,'local.gtiit.widgetreview','data'],text=True).strip())
course_only = os.environ.get('SIMCTL_CHILD_WIDGET_COURSE_REVIEW') == '1'
out=root/'docs/verification'/('courses-2.6' if course_only else 'widgets-beta21');out.mkdir(exist_ok=True)
import time
for attempt in range(100):
    marker=container/'Documents/render-complete.txt'
    if marker.exists() and marker.read_text()==run_id: break
    time.sleep(.1)
else: raise RuntimeError('Missing current-run render completion')
for p in (container/'Documents').glob('course-*.png' if course_only else '*.png'):shutil.copy(p,out/p.name)
print(out)
