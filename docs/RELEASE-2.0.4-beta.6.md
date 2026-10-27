# 2.0.4-beta.6 · build 79

2026-10-27。物理在线作业完成核对、临近窗口与缓存优先呈现。

## 读取与完成判断

- 逐门读取当前活跃课程的 assign/index.php 和 quiz/index.php，兼容目录中的相对 view.php 链接，并补齐日历中的活动。读取包含折叠章节中的作业，日历 action events 使用 aftereventid 分页；受限、超时或未完成覆盖会标记为部分更新，不宣称读取完整。
- Quiz 使用本人尝试汇总表 State 列：去除 Submitted 日期的 statedetails 后检查 Finished；存在进行中／逾期未提交的新尝试则保留待办；Never submitted／Abandoned 不当作完成。不从成绩、Review 链接或 Re-attempt 按钮推断提交，也不打开作答表单或读取答案。
- 已在 Safari 核对用户指定的物理二 HW 01 Integrals，页面存在 Finished／Submitted 尝试记录；据此应隐藏。公开验证截图与测试只使用虚构内容，不上传实际成绩或账户页面。
- HW 01、Homework (2)、Assignment 3 等编号作业统一成 Homework 1 Assignment 等格式。Quiz 也应用规则；没有 homework／assignment／hw 编号的考试不改名。
- 可识别 Quiz 关闭日期与 labelled machine timestamps；在 App 内查看活动结束页时即时读取同一套状态解析规则。扫描开始之后产生的已确认提交证据优先，避免旧扫描结果把完成项重新显示。

## 临近范围

- 默认 10 天；设置 → 作业提醒 → 临近作业范围，可选 3／7／10／14／30 天，跨启动保存。
- 存在截止日期时按所选窗口筛选，不因最近开放而把远期截止的作业混进来；保留原有 24 小时内过期项，供追踪刚错过的提交。无截止日期的活动保留最近 2 天与明天开放的规则。
- 完成项在所有范围中隐藏。系统提醒提前量和通知中心 24 小时窗口各自独立。

## 缓存

- 在初始化时同步恢复缓存的文本列表；后台刷新不先清空。旧版缓存继续可读，读取规则升级后后台重新核对一次完成状态。
- 临时登录页、未就绪的网页和网络错误不擦除目录；部分结果与旧记录合并；完整结果仍能移除已删除活动。主动退出登录在导航时清除，清理站点数据行为不变。
- 课程目录在获得后即可独立落盘，不必等待所有活动详情完成。手动刷新与范围调整保留旧更新时间与列表，新的结果就绪后替换。
- 保留受保护文件与排除备份设置；不缓存成绩、答案、会话密钥和作业正文。

## 依据与验证

- [Moodle 3.9 Quiz renderer](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/mod/quiz/renderer.php)：quizattemptsummary、attempt_state 与 statedetails。
- [Quiz 开放／关闭规则](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/mod/quiz/accessrule/openclosedate/rule.php)。
- [Calendar API](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/calendar/externallib.php)：aftereventid。
- 完整回归 508 项通过；随后补充相对目录链接的专项回归 60 项通过。
- 无重新注入测试数据的冷启动，缓存课程与作业文本直接恢复；已完成和范围外作业隐藏。核对了设置菜单和英文暗色布局。
- 真机第一次安装后 16 门活跃课程核对完成，指定物理 Quiz 的本地状态为 submitted。相对目录补全后的最终安装结果见[验证记录](verification/moodle-beta6/README.md)。
- [Quiz 目录源码](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/mod/quiz/index.php)明确使用相对链接。
