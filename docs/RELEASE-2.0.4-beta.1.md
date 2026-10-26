# 2.0.4-beta.1 · build 74

2026-10-27。在 2.0.3-beta.2 上修复 Student 重新加载后的模糊引导与考试页信息层级。

- Student 专用 showcase 导览偏好设为关闭，已出现的导览调用自身 Skip 动作；每日账户提示使用自身 Continue 处理，恢复网页正常交互。
- 轻量观察器持续处理延迟加载及 SPA 导航，不依赖原来仅持续 12 秒的通用清理。
- 临近考试删除独立顶部状态卡片，更新时间放入考试安排 Section footer。保留必要的加载、登录、重试入口。

完整回归 408/408 通过，已覆盖安装并确认启动。专项验证与完整回归见[记录](verification/student-introductions-exams/README.md)。
