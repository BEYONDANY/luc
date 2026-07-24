<!-- AI-GEN-BEGIN -->
# 用户登录管理方案 — 对比与优化版（LEC-1）

> 关联：Paperclip **LEC-1 方案设计**  
> 日期：2026-07-24  
> 状态：**优化版 v1（interim 输入；待官方附件复核）**  
> Cursor run（本交接）：https://cursor.com/agents/bc-3c1ef75a-bdca-4ca2-a372-489a8e652484  
> 原文恢复自：https://cursor.com/agents/bc-e342cad6-0785-49e1-bfe0-48b17529c6cc  
> 输入来源：见 `docs/lec-1/sources/README.md`

## 0. 任务理解

需要实现用户登录管理方案；**已有 2 个方案**，要求：

1. 对比整理，产出**优化版**
2. 分析差异与优化点，**逐个说明**
3. 新建 **2 个子任务**，分别用于上传既有方案附件
4. 使用中文会话

本环境无法读取看板原始附件（控制面不可达），故以历史可恢复材料作为 **interim 输入**；官方附件到达后按 diff 修订本文档版本号。

## 1. 输入材料

| 方案 | 来源 | 一句话 |
|------|------|--------|
| **方案 A** | `docs/lec-1/sources/scheme-a-auth-center-mvp.md` | 单体 Express + SQLite + 静态管理台，已能跑通登录与用户管理 MVP |
| **方案 B** | `docs/lec-1/sources/scheme-b-modular-user-center.md`（摘自 `docs/plans/2026-07-24-luc-solution-design.md`） | 模块化单体 User Center（Auth/Profile/Session/Audit/Admin），JWT → OIDC 演进 |

对照项（不作第三套主输入）：完整 IdP（Keycloak/Casdoor）——过重，不进 MVP。

---

## 2. 逐维对比（A → B → 差异 → 优化点）

### 2.1 认证主体与账号模型

- **方案 A**：用户名 + 密码；角色 `admin/user`；状态 `active/disabled`；无独立 identity 表。
- **方案 B**：`users` + `user_identities(email/phone)` + `credentials`；状态机 `pending_verify → active → disabled → deleted`。
- **差异**：A 够快但难扩多标识；B 支持邮箱/手机与验证态，面向多业务复用。
- **优化点**：采用 B 的身份模型；MVP 先落 **邮箱或用户名 + 密码**，`user_identities` 预留 phone；不做社交登录。

### 2.2 凭证与会话

- **方案 A**：bcrypt；单 JWT（约 8h）+ HttpOnly Cookie；无 refresh / 会话族。
- **方案 B**：argon2id；access JWT + 旋转 refresh；会话列表 / 强制下线；reuse detection。
- **差异**：A 实现简单但吊销与多端控制弱；B 会话安全完整但首版成本高。
- **优化点**：**密码用 argon2id**；MVP 发 **短 TTL access + 可旋转 refresh（Cookie）**；reuse detection 与会话列表进 Phase 2，但数据模型 Phase 1 就预留 `sessions/refresh_tokens`。

### 2.3 登录流程

- **方案 A**：`POST /api/auth/login|logout`、`GET /api/auth/me`；失败路径有测试；锁定/限流未体系化。
- **方案 B**：注册 / 登录 / OTP / 刷新 / 注销 / 找回密码完整面；限流与审计为基线。
- **差异**：A 主路径最短；B 覆盖账号生命周期。
- **优化点**：MVP 只做 **登录 / 注销 / me / 刷新**；注册与找回密码 Phase 1.5；**IP+账号限流与失败退避必须随登录一起上**。

### 2.4 多端与单点

- **方案 A**：单管理台 + API；无 SSO / OIDC。
- **方案 B**：先 JWT Resource Access，Phase 3 Authorization Code + PKCE + JWKS。
- **差异**：A 定位单应用；B 明确多业务 `aud`。
- **优化点**：**MVP 单应用 JWT（iss/aud/exp/roles/sid）**；接口与密钥按可演进 OIDC 设计（JWKS/`kid` 预留）；不在首期上完整授权码。

### 2.5 安全控制

- **方案 A**：HttpOnly Cookie + Bearer；开发种子管理员；密钥靠环境变量。
- **方案 B**：HTTPS、CSRF 策略、OTP 限次、审计、密钥轮转、防爆破。
- **差异**：A 缺安全基线清单；B 基线完整但需分期落地。
- **优化点**：固化最小安全清单（见 §3.5）；**禁止明文日志 / 开发默认口令进生产**；MFA 非 MVP。

### 2.6 权限与登录后路由

- **方案 A**：轻量 RBAC（admin 管用户）；管理台与 API 同进程。
- **方案 B**：`user/admin` + Admin API；权限点最小集；信任边界清晰。
- **差异**：目标角色模型接近；B 更强调模块边界。
- **优化点**：保留 A 已验证的管理能力（创建/启停/改角色/重置密码），挂到 B 的 **Admin 模块**；业务 API 只验 JWT，不直连用户表写密码。

### 2.7 运维与可观测性

- **方案 A**：本地 SQLite、单进程、自动化测试覆盖主路径。
- **方案 B**：PostgreSQL + Redis；结构化日志；Docker Compose → 容器编排。
- **差异**：A 利于空仓冷启动；B 利于生产形态。
- **优化点**：**开发可用 SQLite/单进程**（吸收 A），**契约与模块边界按 B**；生产配置切 PostgreSQL + Redis；登录成败与敏感变更必审计。

### 2.8 实现成本与迁移路径

- **方案 A**：已证明可快速交付；拆 SSO/多租户贵。
- **方案 B**：多一层集成，但贴合 `luc`「Login & User Center」定位，升级 IdP 成本可控。
- **差异**：A 是战术捷径，B 是战略落点。
- **优化点**：**战略选 B，战术借 A**：先用清晰 API 边界交付可运行 MVP，再换存储/补会话/上 OIDC，避免一次性上完整 IdP。

---

## 3. 差异总表

| 维度 | 方案 A | 方案 B | 优化版取舍 |
|------|--------|--------|------------|
| 定位 | 实现型 MVP | 架构型 User Center | **B 为目标态，A 为启动加速器** |
| 账号模型 | 用户名 | email/phone identities | **B 模型，MVP 先一种主标识** |
| 密码哈希 | bcrypt | argon2id | **argon2id** |
| 会话 | 单 JWT | access + refresh 族 | **双令牌；高级会话 Phase 2** |
| API 前缀 | `/api/*` | `/v1/*` | **`/v1/*`（版本化）** |
| 管理能力 | 已实现 | 设计中 | **保留 A 能力清单** |
| 存储 | SQLite | PG + Redis | **dev SQLite 可选；prod PG+Redis** |
| SSO | 无 | Phase 3 OIDC | **MVP JWT；预留 JWKS** |
| 完整 IdP | 不考虑 | 对照过重 | **明确不做** |

---

## 4. 优化版方案（输出）

### 4.1 目标与非目标

**目标**

1. 统一账号登录、会话与凭证发放。
2. 基础用户资料与管理员账号生命周期（启停/角色/重置密码）。
3. 以可复用 JWT 服务业务系统，并为 OIDC SSO 留演进路径。
4. 空仓可在一个实现迭代内跑通主路径（登录 → me → 刷新 → 注销 → 管理用户）。

**非目标（MVP）**

- 完整企业 IAM / ABAC / 多 IdP 联邦
- 社交登录全覆盖、MFA
- 计费、营销、重运营后台

### 4.2 推荐架构

```text
┌──────────────┐     ┌────────────────────────────────────────────┐
│ Web / Admin  │────▶│ LUC modular monolith                       │
│ (可先静态页)  │     │  Auth │ Profile │ Session │ Audit │ Admin  │
└──────────────┘     └───────────────┬────────────────────────────┘
                                     │
                     ┌───────────────┼───────────────┐
                     ▼               ▼               ▼
                 PostgreSQL*       Redis*        (optional object store)
              *dev 可用 SQLite/内存替代，接口不变
```

**模块职责**

1. **Auth**：登录、刷新、注销；（可选）注册 / 重置
2. **Profile**：`/v1/users/me`
3. **Session**：refresh 族、后续会话列表
4. **Audit**：登录成败、改密、禁用
5. **Admin**：用户 CRUD 式管理（承接方案 A 已验证能力）

### 4.3 关键设计决策（优化点清单）

1. **战略跟 B、战术借 A**：模块边界与 API 版本化用 B；首版可同进程静态管理台（A）降低冷启动成本。
2. **身份模型一次到位**：`users` + `identities` + `credentials`，避免日后拆表。
3. **会话安全分层**：Phase 1 必须有 refresh 旋转；reuse detection / 踢下线 Phase 2。
4. **安全基线不可砍**：argon2id、HTTPS、HttpOnly Secure Cookie、登录限流、审计、JWT `kid` 轮转能力。
5. **集成先 JWT 后 OIDC**：稳定声明 `sub/iss/aud/sid/roles`；业务侧先本地验签。
6. **不做完整 IdP 进 MVP**：需要联邦时再评估托管 IdP，而不是现在替换 luc。
7. **测试继承 A**：登录成功/失败、禁用用户、重置密码作为回归门禁。

### 4.4 接口与状态机（MVP）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/v1/auth/login` | 密码登录，发 access + refresh |
| POST | `/v1/auth/token/refresh` | 旋转刷新 |
| POST | `/v1/auth/logout` | 注销当前会话 |
| GET  | `/v1/auth/me` 或 `/v1/users/me` | 当前用户 |
| GET/POST/PATCH | `/v1/admin/users` | 管理员用户管理 |
| POST | `/v1/admin/users/{id}/reset-password` | 重置密码 |

用户状态：`pending_verify`（若开放注册）→ `active` → `disabled` → `deleted`（软删）。

JWT 最小声明：

```json
{
  "sub": "user_uuid",
  "iss": "https://luc.example.com",
  "aud": ["luc-api"],
  "sid": "session_id",
  "roles": ["user"]
}
```

### 4.5 安全基线（MVP 必达）

1. 密码 argon2id；禁止明文日志。
2. Refresh 旋转；生产 Cookie：`Secure; HttpOnly; SameSite=Lax/Strict`。
3. IP + 账号限流与失败退避。
4. 登录 / 改密 / 禁用写审计。
5. 生产强制强 JWT 密钥；开发种子口令不可用于生产。

### 4.6 技术选型建议

| 层级 | 推荐 | 说明 |
|------|------|------|
| API | Go + Gin **或** 延续 Node/Express（若要最大化复用方案 A 代码） | 董事会确认；边界不变即可 |
| DB | PostgreSQL（prod）/ SQLite（dev） | 通过仓储接口隔离 |
| Cache | Redis（会话/限流） | Phase 1 可用内存实现同一接口 |
| Admin UI | 同进程静态页起步 → Vue 3 | 与方案 A 一致的冷启动策略 |
| 可观测 | 结构化日志 + 关键指标 | 登录成功率 / 失败原因 / 限流触发 |

### 4.7 分期

| Phase | 内容 |
|-------|------|
| **P0** | 本优化版确认；官方 A/B 附件若到达则复核差异 |
| **P1** | 登录/刷新/注销/me + Admin 用户管理 + 限流/审计 + 测试 |
| **P2** | 会话列表/踢下线、reuse detection、注册/找回密码 |
| **P3** | Authorization Code + PKCE、JWKS、多应用 client |

### 4.8 风险与迁移

| 风险 | 缓解 |
|------|------|
| 官方附件与恢复材料不一致 | 子任务上传附件后做 diff，修订本文档版本号 |
| 过早上 OIDC | 坚持 P1 JWT，P3 再标准化 |
| 从 SQLite 迁 PG | 仓储层隔离；迁移脚本与双跑校验 |
| 控制面不可达导致无法确认 | 仓库 PR 作为耐久交付；解阻后补评论/work product |

### 4.9 验收清单

- [x] 引用方案 A、B 路径与来源（interim）
- [x] 8 个对比维度均有差异与优化点
- [x] 优化版可独立实施（模块 / API / 安全 / 分期齐全）
- [ ] 官方附件复核（依赖 board 上传子任务）
- [ ] 上传最终文档到 Paperclip artifact / work product（依赖控制面）
- [ ] 创建方案 A/B 上传子任务（见 `pending-child-issues.json`）

---

## 5. 相对原方案的优化摘要（给评审）

1. **相对 A**：补齐身份模型、refresh 会话、限流审计、版本化 API、生产存储形态。
2. **相对 B**：明确可用 A 的同进程管理台与测试资产加速 P1，避免空仓直接上完整分离式与 OIDC。
3. **相对完整 IdP**：坚持不进 MVP，只保留远期对照。
4. **一句话**：以模块化 User Center 为骨架，用单体可运行交付换取速度，用 JWT→OIDC 分期换取正确演进。

## 6. 与早期 Laravel 草案的关系

此前误按「绿场任选栈」写过 Laravel + Sanctum 草案（`docs/superpowers/specs/2026-07-24-luc-design.md`）。  
**以本文档为 LEC-1 正式对比结论**；Laravel 草案仅作备选栈参考，不再作为推荐结论。栈最终以董事会确认为准（§4.6）。
<!-- AI-GEN-END -->
