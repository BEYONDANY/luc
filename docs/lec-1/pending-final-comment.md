<!-- AI-GEN-BEGIN -->
## LEC-1 心跳交接（仓库已交付 / 控制面待解阻）

### 已完成
- 对比方案 A（Express+SQLite MVP）与方案 B（模块化 User Center），产出优化版：
  - 主文档：`docs/lec-1/optimized-login-management-design.md`
  - 输入副本：`docs/lec-1/sources/`
- 结论一句话：**以 B 为骨架、借 A 加速 MVP**；JWT→OIDC 分期；完整 IdP 不进 MVP。
- Git 分支 / PR 为耐久交付路径（见关联 PR）。

### 待办（需控制面）
1. 创建 2 个子任务分别上传方案 A/B 官方附件（定义见 `docs/lec-1/pending-child-issues.json`）。
2. 官方附件到位后复核优化版并升版本号。
3. 同步 `plan` document + `request_confirmation`。

### 阻塞
Paperclip API 对 Cursor Cloud 不可用（localhost 拒绝 / 公网 401）。解阻 Owner：Board / adapter 配置；Action：注入公网 Base URL + run JWT。
<!-- AI-GEN-END -->
