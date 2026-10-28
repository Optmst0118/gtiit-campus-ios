# 2.0.4-beta.8 · build 81

2026-10-28。第一轮内部结构整理。

- 共用 CampusDetailPage 创建课表、作业、考试、下载、校历详情，使用 AppModel 已有 Store。原有入口与菜单位置不动。
- 共用 nativeDetailSurface 负责原生详情标题和背景，保留各页工具栏、页面布局、返回与弹窗关闭方式。
- 作业文本共用 MoodleWorkText，保留详细／紧凑样式；临近范围、完成过滤与排序由 Store 的同一方法提供，同截止时间的顺序稳定。
- 三种校园摘要缓存统一经 ProtectedCampusCache 进行受保护 JSON 读写。旧路径、文件格式、尺寸限制、数据校验与清理策略保留；编码失败不覆盖有效快照。
- 修复“我的”重选根页时服务中心路由未清除，可能再次打开旧详情的问题。
- [整理结构与行为约束](STRUCTURE-CLEANUP-2.0.4-beta.8.md)。菜单重构方案只归档，不在本轮实施。

完整回归 514 项通过，Release 与签名检查通过，原生返回／下载呈现／英文暗色界面已核对。[验证与交付记录](verification/structure-beta8/README.md)。
