"""Deterministic Widget target and localized resources; Python standard library only."""
import json, os
from pathlib import Path


def release_label(version):
    prerelease = str(version.get("prerelease", "")).strip()
    return version["marketing"] + (f"-{prerelease}" if prerelease else "")
def extend(text, root, uid, team):
    version=json.loads((root/'Tools/version.json').read_text())
    text=text.replace('__GTIIT_BUILD__',str(version['build']))
    text=text.replace('__GTIIT_MARKETING__',version['marketing'])
    objects=[]
    def obj(key,body):
        ident=uid(key);objects.append(f'\t\t{ident} = {{\n{body}\n\t\t}};');return ident
    def arr(values):return '(\n'+''.join('\t\t\t\t'+v+',\n' for v in values)+'\t\t\t)'
    def phase(key,kind,files,extra=''):
        return obj(key,f'\t\t\tisa = {kind};\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = {arr(files)};\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'+extra)
    widget_sources=sorted((root/'GTIITWidgets').glob('*.swift'))
    refs=[];builds=[]
    for p in widget_sources:
        ref=obj('widget:ref:'+p.name,f'\t\t\tisa = PBXFileReference;\n\t\t\tlastKnownFileType = sourcecode.swift;\n\t\t\tpath = {p.name};\n\t\t\tsourceTree = "<group>";');refs.append(ref)
        builds.append(obj('widget:build:'+p.name,f'\t\t\tisa = PBXBuildFile;\n\t\t\tfileRef = {ref};'))
    shared=['Models/ShuttleTimelinePolicy.swift','Core/AppGroup.swift','Models/ShuttleActivityAttributes.swift','Models/ShuttleSchedule.swift','Core/Localization.swift','Views/ShuttleActivityPresentation.swift','Services/CampusLocationRecommendation.swift']
    for rel in shared:
        builds.append(obj('widget:build:'+rel,f'\t\t\tisa = PBXBuildFile;\n\t\t\tfileRef = {uid("ref:GTIIT/"+rel)};'))
    group=obj('group:widget',f'\t\t\tisa = PBXGroup;\n\t\t\tchildren = {arr(refs)};\n\t\t\tpath = GTIITWidgets;\n\t\t\tsourceTree = "<group>";')
    text=text.replace(f'{uid("group:app")} /* GTIIT */,',f'{uid("group:app")} /* GTIIT */,\n\t\t\t\t{group},',1)
    # .lproj folders are deliberately limited to public system UI strings.
    resources=[]
    for lang in ['en','zh-Hans']:
        ref=obj('localization:'+lang,f'\t\t\tisa = PBXFileReference;\n\t\t\tlastKnownFileType = folder;\n\t\t\tpath = "GTIIT/Resources/{lang}.lproj";\n\t\t\tsourceTree = SOURCE_ROOT;')
        text=text.replace(f'{group},',f'{group},\n\t\t\t\t{ref},',1)
        for target in ['app','widget']:
            build=obj('localization:build:'+target+lang,f'\t\t\tisa = PBXBuildFile;\n\t\t\tfileRef = {ref};')
            if target=='widget': resources.append(build)
            else: text=text.replace(f'{uid("build:campus-data")} /* CampusData in Resources */,',f'{uid("build:campus-data")} /* CampusData in Resources */,\n\t\t\t\t{build},',1)
    product=obj('widget:product','\t\t\tisa = PBXFileReference;\n\t\t\texplicitFileType = "wrapper.app-extension";\n\t\t\tpath = GTIITWidgets.appex;\n\t\t\tsourceTree = BUILT_PRODUCTS_DIR;')
    text=text.replace(f'{uid("ref:product")} /* GTIIT.app */,',f'{uid("ref:product")} /* GTIIT.app */,\n\t\t\t\t{product},',1)
    source=phase('widget:sources','PBXSourcesBuildPhase',builds)
    resource=phase('widget:resources','PBXResourcesBuildPhase',resources)
    framework=phase('widget:frameworks','PBXFrameworksBuildPhase',[])
    configs=[]
    for name in ['Debug','Release']:
        settings={'PRODUCT_BUNDLE_IDENTIFIER':'io.github.optmst0118.gtiit.widgets','PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'GTIITWidgets/Info.plist','GENERATE_INFOPLIST_FILE':'NO','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1,2','CURRENT_PROJECT_VERSION':str(version['build']),'MARKETING_VERSION':version['marketing'],'GTIIT_RELEASE_LABEL':release_label(version),'CODE_SIGN_STYLE':'Automatic','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'}
        if team:settings['DEVELOPMENT_TEAM']=team
        if os.environ.get('GTIIT_APP_GROUPS')=='1': settings['CODE_SIGN_ENTITLEMENTS']='GTIITWidgets/GTIITWidgets.entitlements'
        body='\n'.join(f'\t\t\t\t{k} = "{v}";' for k,v in settings.items())
        configs.append(obj('widget:config:'+name,f'\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{body}\n\t\t\t}};\n\t\t\tname = {name};'))
    config=obj('widget:configlist',f'\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = {arr(configs)};\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;')
    target=obj('target:widget',f'\t\t\tisa = PBXNativeTarget;\n\t\t\tname = GTIITWidgets;\n\t\t\tproductName = GTIITWidgets;\n\t\t\tproductType = "com.apple.product-type.app-extension";\n\t\t\tproductReference = {product};\n\t\t\tbuildConfigurationList = {config};\n\t\t\tbuildPhases = {arr([source,framework,resource])};\n\t\t\tdependencies = ();')
    proxy=obj('widget:proxy',f'\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {uid("project:root")};\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = {target};\n\t\t\tremoteInfo = GTIITWidgets;')
    dep=obj('widget:dependency',f'\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = {target};\n\t\t\ttargetProxy = {proxy};')
    embedfile=obj('widget:embedfile',f'\t\t\tisa = PBXBuildFile;\n\t\t\tfileRef = {product};\n\t\t\tsettings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }};')
    embed=phase('widget:embed','PBXCopyFilesBuildPhase',[embedfile],'\t\t\tdstSubfolderSpec = 13;\n\t\t\tdstPath = "";\n\t\t\tname = "Embed App Extensions";')
    text=text.replace(f'{uid("phase:resources")} /* Resources */,',f'{uid("phase:resources")} /* Resources */,\n\t\t\t\t{embed},',1)
    text=text.replace('\t\t\tdependencies = (\n\t\t\t);',f'\t\t\tdependencies = {arr([dep])};',1)
    text=text.replace(f'{uid("target:app")} /* GTIIT */,',f'{uid("target:app")} /* GTIIT */,\n\t\t\t\t{target},',1)
    label=release_label(version)
    text=text.replace('MARKETING_VERSION = '+version['marketing']+';',f'MARKETING_VERSION = {version["marketing"]};\n\t\t\t\tGTIIT_RELEASE_LABEL = "{label}";')
    if os.environ.get('GTIIT_APP_GROUPS')=='1':text=text.replace('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;','ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = GTIIT/GTIIT.entitlements;')
    return text.replace('\n\t};\n\trootObject','\n'+'\n'.join(objects)+'\n\t};\n\trootObject')
