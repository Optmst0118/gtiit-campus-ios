# 版本规则

用户于 2026-11-10 确认，根目录 AGENTS.md 同步保存长期规则。

- 仅修复、性能或视觉优化：只递增 beta.N。
- 新增功能：当前 marketing 第三段加一，如 2.0.4 → 2.0.5。
- 功能和 UI 同时更新：第二段加一、第三段归零，如 2.0.4 → 2.1.0。
- 功能版本变化后从 beta.1 开始；不回退已有版本。
- Build 每次交付加一；同一交付反复构建或重新签名安装不加版本。
- Tools/version.json 为唯一版本源。运行 Tools/bump_version.py 后运行 Tools/gen_project.py、Tools/check_project.py。
- 独立 Beta 始终原位覆盖安装，禁止卸载、重置数据或覆盖原版。
