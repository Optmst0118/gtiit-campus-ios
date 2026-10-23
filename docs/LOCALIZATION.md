# 原生本地化验证（alpha.27）

范围：GTIIT 原生 SwiftUI/UIKit、App Intents、通知、Info.plist 隐私说明。WKWebView 网页内容不在此范围。

## 结果

- L10n.tr 直接键与 L10n.format 格式键全部命中 native-en.json；
- 中文源与英文值占位符一致，没有空值或中文残留；
- en / zh-Hans Localizable.strings 各 748 键，键集合一致；
- InfoPlist.strings 覆盖 Face ID 与定位两条 usage description；
- AppShortcuts / 通知元数据在中英资源中均可解析；
- 构建产物包含 en、zh-Hans 两套 lproj。

## 自动检查

```bash
python3 Tools/check_localization.py
```

CI 的 Validate native localization completeness 步骤会在每次 push / PR 执行；缺失键、格式占位符不一致、英文值中文残留、Info.plist 缺失都会失败。

## 本轮修复

- 房间名中的中文括号描述拆成“房间号 + 本地化描述”；
- 统一日期/时长显示使用 App 语言 locale；
- 对齐两条 .strings 与 JSON 的英文差异；
- 增加 Widget 配置文案；
- 增加 Face ID 隐私说明英文；
- 新增本地化检查脚本并接入 CI。

## 未改变

- 默认语言仍是中文，用户可在设置切换；
- Widget / Live Activity 使用系统语言或既有双语文案，不影响 App 内语言；
- 网页套壳内容不在检查范围。
