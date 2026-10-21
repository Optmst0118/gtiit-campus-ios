#!/usr/bin/env python3
"""生成可被 Xcode 直接打开的 GTIIT.xcodeproj。

只依赖标准库。目录中新增/删除源文件后重新运行即可：
    python3 Tools/gen_project.py
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
APP_NAME = "GTIIT"
SOURCE_DIR = PROJECT_ROOT / APP_NAME
PROJECT = PROJECT_ROOT / f"{APP_NAME}.xcodeproj"
BUNDLE_ID = "io.github.optmst0118.gtiit"
DEPLOYMENT_TARGET = "17.0"


def development_team() -> str:
    """签名团队：优先环境变量 DEVELOPMENT_TEAM，其次 Tools/signing.env 里的同名行。"""
    team = os.environ.get("DEVELOPMENT_TEAM", "").strip()
    if team:
        return team
    env_file = PROJECT_ROOT / "Tools" / "signing.env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, value = line.partition("=")
            if key.strip() == "DEVELOPMENT_TEAM":
                return value.strip().strip('"')
    return ""

SWIFT_DIRS = ["App", "Core", "Models", "Services", "Views", "Components"]
RESOURCE_DIR = "Resources"


def uid(key: str) -> str:
    return hashlib.md5(key.encode("utf-8")).hexdigest()[:24].upper()


def collect_sources() -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for directory in SWIFT_DIRS:
        folder = SOURCE_DIR / directory
        groups[directory] = sorted(p.name for p in folder.glob("*.swift"))
    return groups


def build_project() -> str:
    groups = collect_sources()

    # ---------- PBXBuildFile ----------
    build_files: list[str] = []
    source_build_ids: list[str] = []
    file_refs: list[str] = []

    for directory, names in groups.items():
        for name in names:
            rel = f"{APP_NAME}/{directory}/{name}"
            build_id = uid("build:" + rel)
            ref_id = uid("ref:" + rel)
            source_build_ids.append(build_id)
            build_files.append(
                f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};"
            )
            file_refs.append(
                f"\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
            )

    web_ref = uid("ref:web-appearance")
    web_build = uid("build:web-appearance")
    file_refs.append(f'\t\t{web_ref} /* WebAppearance */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = WebAppearance; sourceTree = "<group>"; }};')
    build_files.append(f'\t\t{web_build} /* WebAppearance in Resources */ = {{isa = PBXBuildFile; fileRef = {web_ref} /* WebAppearance */; }};')
    assets_ref = uid("ref:assets")
    icon_ref = uid("ref:layered-icon")
    has_icon = (SOURCE_DIR / RESOURCE_DIR / "AppIcon.icon").exists()
    if has_icon:
        file_refs.append(
            f'\t\t{icon_ref} /* AppIcon.icon */ = {{isa = PBXFileReference; lastKnownFileType = folder.iconcomposer; path = AppIcon.icon; sourceTree = "<group>"; }};'
        )
    file_refs.append(
        f"\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};"
    )
    plist_ref = uid("ref:infoplist")
    file_refs.append(
        f"\t\t{plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};"
    )
    privacy_ref = uid("ref:privacy")
    file_refs.append(
        f"\t\t{privacy_ref} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};"
    )

    product_ref = uid("ref:product")
    file_refs.append(
        f"\t\t{product_ref} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )

    # ---------- PBXGroup ----------
    main_group = uid("group:main")
    products_group = uid("group:products")
    app_group = uid("group:app")
    resources_group = uid("group:resources")

    child_groups = "".join(f"\t\t\t\t{uid('group:' + d)} /* {d} */,\n" for d in SWIFT_DIRS)
    groups_section = [
        f"\t\t{main_group} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{app_group} /* {APP_NAME} */,\n\t\t\t\t{products_group} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t}};",
        f"\t\t{products_group} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{product_ref} /* {APP_NAME}.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};",
        f"\t\t{app_group} /* {APP_NAME} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_groups}\t\t\t\t{resources_group} /* {RESOURCE_DIR} */,\n\t\t\t\t{plist_ref} /* Info.plist */,\n\t\t\t);\n\t\t\tpath = {APP_NAME};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};",
        f"\t\t{resources_group} /* {RESOURCE_DIR} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{assets_ref} /* Assets.xcassets */,\n\t\t\t\t{privacy_ref} /* PrivacyInfo.xcprivacy */,\n\t\t\t);\n\t\t\tpath = {RESOURCE_DIR};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};",
    ]
    for directory in SWIFT_DIRS:
        members = "".join(
            f"\t\t\t\t{uid('ref:' + APP_NAME + '/' + directory + '/' + name)} /* {name} */,\n"
            for name in groups[directory]
        )
        groups_section.append(
            f"\t\t{uid('group:' + directory)} /* {directory} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{members}\t\t\t);\n\t\t\tpath = {directory};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};"
        )

    groups_section = [s.replace(f'{privacy_ref} /* PrivacyInfo.xcprivacy */,', f'{privacy_ref} /* PrivacyInfo.xcprivacy */,\n\t\t\t\t{web_ref} /* WebAppearance */,') for s in groups_section]
    if has_icon:
        groups_section = [s.replace(f'{assets_ref} /* Assets.xcassets */,', f'{assets_ref} /* Assets.xcassets */,\n\t\t\t\t{icon_ref} /* AppIcon.icon */,') for s in groups_section]

    # ---------- Phases ----------
    sources_phase = uid("phase:sources")
    frameworks_phase = uid("phase:frameworks")
    resources_phase = uid("phase:resources")
    source_files_list = "".join(f"\t\t\t\t{i} /* in Sources */,\n" for i in source_build_ids)
    assets_build = uid("build:assets")
    icon_build = uid("build:layered-icon")
    if has_icon:
        build_files.append(
            f'\t\t{icon_build} /* AppIcon.icon in Resources */ = {{isa = PBXBuildFile; fileRef = {icon_ref} /* AppIcon.icon */; }};'
        )
    build_files.append(
        f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};"
    )
    privacy_build = uid("build:privacy")
    build_files.append(
        f"\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {privacy_ref} /* PrivacyInfo.xcprivacy */; }};"
    )

    # ---------- Target / Project ----------
    target = uid("target:app")
    project = uid("project:root")
    project_config_list = uid("configlist:project")
    target_config_list = uid("configlist:target")

    debug_project = uid("config:project:debug")
    release_project = uid("config:project:release")
    debug_target = uid("config:target:debug")
    release_target = uid("config:target:release")

    common_project_settings = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
""" % DEPLOYMENT_TARGET

    debug_project_settings = (
        common_project_settings
        + """\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""
    )
    release_project_settings = (
        common_project_settings
        + """\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
"""
    )

    team = development_team()
    team_line = f'\t\t\t\tDEVELOPMENT_TEAM = "{team}";\n' if team else ""
    target_settings = team_line + """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 9;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = %s/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.5;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "%s";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
""" % (APP_NAME, DEPLOYMENT_TARGET, BUNDLE_ID)

    contents = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(groups_section)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target} /* {APP_NAME} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {target_config_list} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase} /* Sources */,
\t\t\t\t{frameworks_phase} /* Frameworks */,
\t\t\t\t{resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {APP_NAME};
\t\t\tproductName = {APP_NAME};
\t\t\tproductReference = {product_ref} /* {APP_NAME}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject "{APP_NAME}" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = "zh-Hans";
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t\t"zh-Hans",
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tproductRefGroup = {products_group} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target} /* {APP_NAME} */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,
{f'                {icon_build} /* AppIcon.icon in Resources */,' if has_icon else ''}
\t\t\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */,
                {web_build} /* WebAppearance in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{source_files_list}\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{debug_project} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{debug_project_settings}\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{release_project} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{release_project_settings}\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{debug_target} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{target_settings}\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{release_target} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{target_settings}\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{project_config_list} /* Build configuration list for PBXProject "{APP_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_project} /* Debug */,
\t\t\t\t{release_project} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{target_config_list} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_target} /* Debug */,
\t\t\t\t{release_target} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {project} /* Project object */;
}}
"""
    return contents


def build_scheme() -> str:
    target = uid("target:app")
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "{APP_NAME}.app"
               BlueprintName = "{APP_NAME}"
               ReferencedContainer = "container:{APP_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{APP_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{APP_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


def main() -> None:
    PROJECT.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.pbxproj").write_text(build_project(), encoding="utf-8")
    schemes = PROJECT / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    (schemes / f"{APP_NAME}.xcscheme").write_text(build_scheme(), encoding="utf-8")
    sources = sum(len(v) for v in collect_sources().values())
    print(f"wrote {PROJECT}/project.pbxproj with {sources} Swift sources")
    if development_team():
        print(f"signing team: {development_team()}")
    else:
        print("signing team: (未设置，请在 Xcode 里选 Team 或在 Tools/signing.env 写入 DEVELOPMENT_TEAM)")


if __name__ == "__main__":
    main()
