# repo-sync-action

GitHub Action 用于同步仓库代码到不同平台（如 GitHub → Gitee）

## 使用示例
```yaml
- name: Sync GitHub to Gitee
  uses: Kirito520Asuna/repo-sync-action@main
  with:
    #Git 用户配置（可选）
    user_email: action@github.com 
    user_name: GitHub Action
    #源仓库配置
    src: github.com/user/repo.git
    src_branch: main
    src_username: ${{ secrets.SRC_USERNAME }}
    src_token: ${{ secrets.SRC_TOKEN }}
    #目标仓库配置
    dst: gitee.com/user/repo.git
    dst_branch: master
    dst_username: ${{ secrets.DST_USERNAME }}
    dst_token: ${{ secrets.DST_TOKEN }}
    #是否强制推送（可选）
    force_push: 'true'
```
## 参数说明

| 参数 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `user_email` | 否 |Git 提交邮箱 | `action@github.com` | 
| `user_name` | 否 | Git 提交用户名 |`GitHub Action` |  
| `src` | 是 | 源仓库地址 | `github.com/user/repo.git` |
| `src_branch` | 是 | 源仓库分支 | `main` |
| `src_username` | 是 | 源仓库用户名 | `${{ secrets.SRC_USERNAME }}` |
| `src_token` | 否 | 源仓库访问令牌 | `${{ secrets.SRC_TOKEN }}` |
| `dst` | 是 | 目标仓库地址 | `gitee.com/user/repo.git` |
| `dst_branch` | 是 | 目标仓库分支 | `master` |
| `dst_username` | 是 | 目标仓库用户名 | `${{ secrets.DST_USERNAME }}` |
| `dst_token` | 是 | 目标仓库访问令牌 | `${{ secrets.DST_TOKEN }}` |
| `force_push` | 否 | 是否强制推送 | `'true'` / `'false'` |
## 配置 Secrets

在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中添加以下密钥：

- `SRC_USERNAME`: 源仓库用户名
- `SRC_TOKEN`: 源仓库 Personal Access Token
- `DST_USERNAME`: 目标仓库用户名
- `DST_TOKEN`: 目标仓库 Personal Access Token / 私有令牌

### 获取 Token

**GitHub Token**:
1. 访问 https://github.com/settings/tokens
2. 生成新 token，勾选 `repo` 权限

**Gitee Token**:
1. 访问 https://gitee.com/profile/personal_access_tokens
2. 生成新令牌，勾选 `projects` 权限

## 完整 Workflow 示例
```yaml
name: Sync to Gitee
on: 
  push: 
    branches: [main] 
  schedule: 
    - cron: '0 */6 * * *' # 每6小时同步一次
jobs: 
  sync: 
    runs-on: ubuntu-latest 
    steps: 
      - name: Sync GitHub to Gitee 
        uses: Kirito520Asuna/repo-sync-action@main 
        with: 
          src: github.com/username/repo.git 
          src_branch: main 
          src_username: ${{ secrets.SRC_USERNAME }} 
          src_token: ${{ secrets.SRC_TOKEN }}
          dst: gitee.com/username/repo.git
          dst_branch: master
          dst_username: ${{ secrets.DST_USERNAME }}
          dst_token: ${{ secrets.DST_TOKEN }}
          force_push: 'true'
```
## 注意事项

⚠️ **重要提示**：
- 仓库地址不需要包含 `https://` 前缀
- Token 需要具有读写权限
- 目标仓库需要提前创建好
- 首次同步建议使用 `force_push: 'true'`