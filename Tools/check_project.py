#!/usr/bin/env python3
"""离线校验 GTIIT.xcodeproj 的结构完整性（不依赖 Xcode）。

检查项：
  1. pbxproj 花括号平衡、可解析出 rootObject；
  2. 所有对象 UUID 唯一、所有引用都能解析；
  3. group 树能还原出每个文件引用的磁盘路径，且文件真实存在；
  4. 磁盘上的每个 .swift 都在 Sources 编译阶段里；
  5. target / product / scheme 三者一致；
  6. 关键 build settings 齐全；
  7. AppIcon 与 Assets 的 Contents.json 合法。

用法：python3 Tools/check_project.py
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "GTIIT.xcodeproj" / "project.pbxproj"
SCHEME = ROOT / "GTIIT.xcodeproj" / "xcshareddata" / "xcschemes" / "GTIIT.xcscheme"
ASSETS = ROOT / "GTIIT" / "Resources" / "Assets.xcassets"

ID_RE = re.compile(r"^([0-9A-F]{24})$")
OBJ_HEADER = re.compile(r"^\t\t([0-9A-F]{24})(?: /\* (.*?) \*/)? = \{(.*)$")

errors: list[str] = []
notes: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def parse_objects(text: str) -> dict[str, dict]:
    start = text.index("objects = {")
    end = text.rindex("\n\t};\n\trootObject")
    body = text[start + len("objects = {") : end]

    objects: dict[str, dict] = {}
    lines = body.splitlines()
    index = 0
    while index < len(lines):
        match = OBJ_HEADER.match(lines[index])
        if not match:
            index += 1
            continue
        object_id, name = match.group(1), match.group(2)
        remainder = match.group(3)
        header_line = lines[index]
        raw = [header_line]
        # 单行对象（如 PBXBuildFile）在同一行内就闭合，需要把 remainder 的花括号也计入。
        depth = 1 + remainder.count("{") - remainder.count("}")
        index += 1
        while index < len(lines) and depth > 0:
            line = lines[index]
            depth += line.count("{") - line.count("}")
            raw.append(line)
            index += 1
        raw_text = "\n".join(raw)
        isa_match = re.search(r"isa = (\w+);", raw_text)
        if not isa_match:
            fail(f"{object_id} 缺少 isa")
            continue
        if object_id in objects:
            fail(f"UUID 重复：{object_id}")
        objects[object_id] = {
            "id": object_id,
            "name": name,
            "isa": isa_match.group(1),
            "raw": raw_text,
        }

    root_match = re.search(r"rootObject = ([0-9A-F]{24})", text)
    if not root_match:
        fail("找不到 rootObject")
    elif root_match.group(1) not in objects:
        fail("rootObject 指向不存在的对象")
    return objects


def field_values(raw: str, key: str) -> list[str]:
    match = re.search(rf"{key} = \((.*?)\n\t\t\t\);", raw, re.S)
    if not match:
        return []
    return re.findall(r"([0-9A-F]{24})", match.group(1))


def field_string(raw: str, key: str) -> str | None:
    match = re.search(rf"\b{key} = ([^;]+);", raw)
    if not match:
        return None
    return match.group(1).strip().strip('"')


def field_id(raw: str, key: str) -> str | None:
    """读取一个指向 UUID 的字段，忽略后面的 /* 注释 */。"""
    value = field_string(raw, key)
    if value is None:
        return None
    match = re.search(r"([0-9A-F]{24})", value)
    return match.group(1) if match else None


def group_paths(objects: dict[str, dict], main_group: str) -> dict[str, str]:
    """从 mainGroup 递归还原 fileRef → 磁盘相对路径。"""
    resolved: dict[str, str] = {}

    def walk(group_id: str, base: Path) -> None:
        group = objects.get(group_id)
        if group is None:
            return
        own = field_string(group["raw"], "path")
        here = base / own if own else base
        for child_id in field_values(group["raw"], "children"):
            child = objects.get(child_id)
            if child is None:
                fail(f"group {group_id} 引用了不存在的 child {child_id}")
                continue
            if child["isa"] == "PBXGroup":
                walk(child_id, here)
            else:
                if field_string(child["raw"], "sourceTree") == "<group>":
                    child_path = field_string(child["raw"], "path") or ""
                    resolved[child_id] = os.path.normpath(str(here / child_path))

    walk(main_group, Path("."))
    return resolved


def main() -> int:
    if not PBXPROJ.exists():
        print("缺少 project.pbxproj，请先运行 python3 Tools/gen_project.py")
        return 1

    text = PBXPROJ.read_text(encoding="utf-8")
    if text.count("{") != text.count("}"):
        fail(f"花括号不平衡：{{={text.count('{')} }}={text.count('}')}")
    if text.count("(") != text.count(")"):
        fail("圆括号不平衡")

    objects = parse_objects(text)
    notes.append(f"对象数：{len(objects)}")

    # 引用完整性
    for object_id, obj in objects.items():
        for key in ("fileRef", "productReference", "mainGroup", "productRefGroup",
                    "buildConfigurationList", "rootObject"):
            value = field_id(obj["raw"], key)
            if value and value not in objects:
                fail(f"{object_id}({obj['isa']}) 的 {key} 指向不存在对象 {value}")
        for key in ("children", "files", "buildPhases", "targets"):
            for ref in field_values(obj["raw"], key):
                if ref not in objects:
                    fail(f"{object_id}({obj['isa']}) 的 {key} 引用了不存在对象 {ref}")

    # 工程结构
    project = next((o for o in objects.values() if o["isa"] == "PBXProject"), None)
    target = next((o for o in objects.values() if o["isa"] == "PBXNativeTarget" and field_string(o["raw"], "name") == "GTIIT"), None)
    if project is None or target is None:
        fail("找不到 PBXProject 或 PBXNativeTarget")
        return report()

    if target["isa"] == "PBXNativeTarget":
        if field_string(target["raw"], "productType") != "com.apple.product-type.application":
            fail(f"target 的 productType 异常：{field_string(target['raw'], 'productType')}")
        if "GTIIT" != field_string(target["raw"], "name"):
            fail(f"target 名字异常：{field_string(target['raw'], 'name')}")

    # 关键 build settings
    required = {
        "PRODUCT_BUNDLE_IDENTIFIER": "io.github.optmst0118.gtiit",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "INFOPLIST_FILE": "GTIIT/Info.plist",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "GENERATE_INFOPLIST_FILE": "NO",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    configs = [o for o in objects.values() if o["isa"] == "XCBuildConfiguration"
               and field_string(o["raw"], "PRODUCT_BUNDLE_IDENTIFIER") == "io.github.optmst0118.gtiit"]
    if len(configs) != 2:
        fail(f"target 应有 2 个 XCBuildConfiguration，实际 {len(configs)}")
    for config in configs:
        for key, expected in required.items():
            value = field_string(config["raw"], key)
            if value is None:
                fail(f"{config['name']} 缺少 {key}")
            elif value != expected:
                fail(f"{config['name']} 的 {key} = {value}，期望 {expected}")

    # Each target owns its own configurations; the extension must stay embedded.
    version = json.loads((ROOT / "Tools/version.json").read_text())
    widgets = [o for o in objects.values() if o["isa"] == "PBXNativeTarget" and field_string(o["raw"], "name") == "GTIITWidgets"]
    if len(widgets) != 1: fail("必须恰有一个 GTIITWidgets target")
    else:
        widget = widgets[0]
        if field_string(widget["raw"], "productType") != "com.apple.product-type.app-extension": fail("Widget productType 错误")
        widget_configs = [o for o in objects.values() if o["isa"] == "XCBuildConfiguration" and field_string(o["raw"], "PRODUCT_BUNDLE_IDENTIFIER") == "io.github.optmst0118.gtiit.widgets"]
        if len(widget_configs) != 2: fail("Widget 缺少 Debug/Release 配置")
        for config in configs + widget_configs:
            if field_string(config["raw"], "CURRENT_PROJECT_VERSION") != str(version["build"]): fail("App/Widget build 与 version.json 不一致")
            if field_string(config["raw"], "MARKETING_VERSION") != version["marketing"]: fail("App/Widget 版本不一致")
        embeds = [objects[i] for i in field_values(target["raw"], "buildPhases") if objects[i]["isa"] == "PBXCopyFilesBuildPhase"]
        product = field_id(widget["raw"], "productReference")
        if not any(field_string(e["raw"], "dstSubfolderSpec") == "13" and any(field_id(objects[b]["raw"], "fileRef") == product for b in field_values(e["raw"], "files")) for e in embeds): fail("App 未嵌入 Widget 扩展")

    # group 树 → 文件存在
    main_group = field_id(project["raw"], "mainGroup")
    paths = group_paths(objects, main_group)
    for ref_id, rel in sorted(paths.items()):
        if rel.startswith("Products"):
            continue
        if not (ROOT / rel).exists():
            fail(f"文件引用不存在：{rel}")

    # Swift 源码都在编译阶段
    sources_phase = next((objects[i] for i in field_values(target["raw"], "buildPhases")
                          if objects[i]["isa"] == "PBXSourcesBuildPhase"), None)
    if sources_phase is None:
        fail("缺少 Sources 编译阶段")
    else:
        build_ids = field_values(sources_phase["raw"], "files")
        compiled = []
        for build_id in build_ids:
            build = objects.get(build_id)
            if build is None:
                fail(f"Sources 阶段引用了不存在的 build file {build_id}")
                continue
            ref = field_id(build["raw"], "fileRef")
            if ref in paths:
                compiled.append(paths[ref])
        disk_swift = sorted(
            str(p.relative_to(ROOT)) for p in (ROOT / "GTIIT").rglob("*.swift")
        )
        missing = [p for p in disk_swift if p not in compiled]
        extra = [p for p in compiled if p not in disk_swift]
        if missing:
            fail(f"未加入编译：{missing}")
        if extra:
            fail(f"编译列表里有磁盘不存在的文件：{extra}")
        notes.append(f"编译 Swift 文件：{len(compiled)} / 磁盘 {len(disk_swift)}")

    if widgets:
        widget = widgets[0]
        compiled_widget = set()
        for phase_id in field_values(widget["raw"], "buildPhases"):
            phase = objects[phase_id]
            if phase["isa"] == "PBXSourcesBuildPhase":
                for b in field_values(phase["raw"], "files"):
                    compiled_widget.add(paths.get(field_id(objects[b]["raw"], "fileRef")))
        required_widget = {str(p.relative_to(ROOT)) for p in (ROOT / "GTIITWidgets").glob("*.swift")} | {"GTIIT/Views/ShuttleActivityPresentation.swift", "GTIIT/Models/ShuttleActivityAttributes.swift", "GTIIT/Models/ShuttleSchedule.swift", "GTIIT/Core/Localization.swift"}
        if compiled_widget != required_widget: fail(f"Widget 编译源码不一致：{compiled_widget ^ required_widget}")
        notes.append(f"Widget 编译 Swift 文件：{len(compiled_widget)}")

    # Resources 阶段
    resources_phase = next((objects[i] for i in field_values(target["raw"], "buildPhases")
                            if objects[i]["isa"] == "PBXResourcesBuildPhase"), None)
    if resources_phase is None:
        fail("缺少 Resources 编译阶段")
    else:
        asset_refs = []
        for build_id in field_values(resources_phase["raw"], "files"):
            build = objects.get(build_id)
            ref = field_id(build["raw"], "fileRef") if build else None
            if ref in paths:
                asset_refs.append(paths[ref])
        if not any(ref.endswith("Assets.xcassets") for ref in asset_refs):
            fail("Assets.xcassets 未加入 Resources")

    # scheme 一致性
    if not SCHEME.exists():
        fail("缺少共享 scheme")
    else:
        scheme_text = SCHEME.read_text(encoding="utf-8")
        blueprint = re.search(r'BlueprintIdentifier = "([0-9A-F]{24})"', scheme_text)
        if not blueprint:
            fail("scheme 缺少 BlueprintIdentifier")
        elif blueprint.group(1) != target["id"]:
            fail("scheme 的 target 与工程 target 不一致")
        if 'BuildableName = "GTIIT.app"' not in scheme_text:
            fail("scheme 的 BuildableName 不是 GTIIT.app")

    # Assets
    for folder in ("", "AppIcon.appiconset", "AccentColor.colorset", "LaunchBackground.colorset"):
        contents = ASSETS / folder / "Contents.json"
        if not contents.exists():
            fail(f"缺少 {contents.relative_to(ROOT)}")
            continue
        try:
            json.loads(contents.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            fail(f"{contents.relative_to(ROOT)} 不是合法 JSON：{error}")
    icon = ASSETS / "AppIcon.appiconset" / "AppIcon.png"
    if not icon.exists():
        fail("缺少 AppIcon.png")
    else:
        import struct
        data = icon.read_bytes()
        width, height = struct.unpack(">II", data[16:24])
        if (width, height) != (1024, 1024):
            fail(f"AppIcon 尺寸为 {width}x{height}，应为 1024x1024")
        color_type = data[25]
        if color_type in (4, 6):
            fail("AppIcon 含 alpha 通道（App Store 要求不透明）")
        else:
            notes.append(f"AppIcon {width}x{height}，无 alpha")

    # Info.plist 必需键
    plist = (ROOT / "GTIIT" / "Info.plist").read_text(encoding="utf-8")
    for key in ("CFBundleDisplayName", "UILaunchScreen", "NSFaceIDUsageDescription",
                "NSAllowsArbitraryLoadsInWebContent", "UIApplicationSceneManifest"):
        if key not in plist:
            fail(f"Info.plist 缺少 {key}")

    return report()


def report() -> int:
    for note in notes:
        print(f"· {note}")
    if errors:
        print(f"\n✗ 发现 {len(errors)} 个问题：")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("\n✓ 工程结构校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())