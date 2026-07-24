<!-- AI-GEN-BEGIN -->
# Scheme B — 模块化单体 User Center（摘自 LUC 方案设计）

> Source: docs/plans/2026-07-24-luc-solution-design.md (bc-7af963ae)

### 方案 B：模块化单体 User Center（推荐）

- **做法**：独立 `luc` 服务，内含 Auth / User Profile / Session / Admin API 模块；对外提供：
  - 浏览器登录页 + 授权码流程（OIDC 子集）
  - Resource API（`/v1/users/me` 等）
  - 服务间 client_credentials（后续）
- **优点**：边界清晰，MVP 可控，后续可拆出独立 IdP。
- **缺点**：比方案 A 多一层集成成本。
- **适用**：当前仓库定位（Login & User Center）与多业务复用预期。

**推荐：方案 B。**  
理由：贴合仓库定位，能在 1–2 个实现迭代内交付可用登录与用户中心，同时保留升级到标准 OIDC Provider 的路径。

---

## 方案 B 详细设计（原文第 4–13 节）

## 4. 总体架构

```text
┌──────────────┐     ┌────────────────────────────────────────────┐
│ Web / App    │────▶│ LUC (modular monolith)                     │
│ + Admin UI   │     │  Auth │ Profile │ Session │ Audit │ Admin  │
└──────────────┘     └───────────────┬────────────────────────────┘
                                     │
                     ┌───────────────┼───────────────┐
                     ▼               ▼               ▼
                 PostgreSQL        Redis         Object Storage
                (users/creds)   (session/otp)   (avatar, optional)
```

### 4.1 核心模块

1. **Auth**：注册、登录、验证码、刷新令牌、注销、密码重置。
2. **Profile**：用户资料读写、头像、基础偏好。
3. **Session**：刷新令牌族、设备会话列表、强制下线。
4. **RBAC（轻量）**：`user` / `admin` 角色；权限点先做最小集。
5. **Audit**：登录成败、敏感变更（改密、换绑）审计日志。
6. **Admin API**：用户检索、禁用、重置、会话吊销（可后置）。

### 4.2 信任边界

- 浏览器只持有 HttpOnly Secure Cookie（或短期 access token + 旋转 refresh token）。
- 业务 API 校验 LUC 签发的 JWT（本地 JWKS / 共享公钥）。
- 管理接口独立鉴权，默认仅 admin。

## 5. 身份模型与数据

### 5.1 主要实体

- `users`：id、status、display_name、avatar_url、created_at、updated_at
- `user_identities`：type(`email`/`phone`)、identifier、verified_at
- `credentials`：password_hash（argon2id）、password_updated_at
- `sessions` / `refresh_tokens`：family_id、expires_at、revoked_at、ua/ip
- `otp_challenges`：scene、target、code_hash、expires_at、attempts
- `audit_events`：actor、action、ip、ua、payload、created_at
- `roles` / `user_roles`：最小 RBAC

### 5.2 状态机（用户）

`pending_verify` → `active` → `disabled`（可恢复）→ `deleted`（软删）

## 6. API 与集成面（MVP）

### 6.1 公开/终端用户 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/v1/auth/register` | 邮箱或手机注册 |
| POST | `/v1/auth/login` | 密码登录 |
| POST | `/v1/auth/otp/send` | 发送验证码 |
| POST | `/v1/auth/otp/verify` | 验证码登录/校验 |
| POST | `/v1/auth/token/refresh` | 刷新 access token |
| POST | `/v1/auth/logout` | 注销当前会话 |
| POST | `/v1/auth/password/forgot` | 发起重置 |
| POST | `/v1/auth/password/reset` | 完成重置 |
<!-- AI-GEN-END -->
