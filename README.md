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
    #推送配置（可选）
    force_push: 'true' 
    git_post_buffer: '524288000'
    git_low_speed_limit: '1000' 
    git_low_speed_time: '60' 
    push_timeout: '3540'
```
## 参数说明

| 参数 | 必填 | 默认值 | 说明 | 示例 |
|------|------|--------|------|------|
| `user_email` | 否 | `action@github.com` | Git 提交邮箱 | `your@email.com` |
| `user_name` | 否 | `GitHub Action` | Git 提交用户名 | `Your Name` |
| `src` | 是 | - | 源仓库地址（不含协议前缀，支持 HTTPS/SSH） | `github.com/user/repo.git` 或 `git@github.com:user/repo.git` |
| `src_branch` | 是 | `main` | 源仓库分支 | `main` / `master` |
| `src_username` | 是 | - | 源仓库用户名 | `${{ secrets.SRC_USERNAME }}` |
| `src_token` | 否 | - | 源仓库访问令牌（私有仓库需要） | `${{ secrets.SRC_TOKEN }}` |
| `dst` | 是 | - | 目标仓库地址（不含协议前缀，支持 HTTPS/SSH） | `gitee.com/user/repo.git` 或 `git@gitee.com:user/repo.git` |
| `dst_branch` | 是 | `master` | 目标仓库分支 | `master` / `main` |
| `dst_username` | 是 | - | 目标仓库用户名） | `${{ secrets.DST_USERNAME }}` |
| `dst_token` | 是 | - | 目标仓库访问令牌 | `${{ secrets.DST_TOKEN }}` |
| `force_push` | 否 | `'false'` | 是否强制推送 | `'true'` / `'false'` |
| `git_post_buffer` | 否 | `'524288000'` | Git 缓冲区大小（字节） | `'524288000'` (500MB) |
| `git_low_speed_limit` | 否 | `'1000'` | 最低速度限制（字节/秒） | `'1000'` |
| `git_low_speed_time` | 否 | `'60'` | 低速超时时间（秒） | `'60'` |
| `push_timeout` | 否 | `'3540'` | 推送超时时间（秒） | `'3540'` (59分钟) |

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
      # Diff Repo Sync
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
      # Upstream Sync
      # 1.Upstream is public
      - name: Sync Upstream
        uses: Kirito520Asuna/repo-sync-action@main
        with:
          src: github.com/username-Upstream/Upstream.git
          src_branch: main
          src_username: ${{ secrets.SRC_USERNAME }}
          #src_token: ${{ secrets.SRC_TOKEN }}
          dst: github.com/username/Upstream.git
          dst_branch: master
          dst_username: ${{ secrets.DST_USERNAME }}
          dst_token: ${{ secrets.DST_TOKEN }}
          #force_push: 'true'
      # 2.Upstream is private
      - name: Sync Upstream
        uses: Kirito520Asuna/repo-sync-action@main
        with:
          src: github.com/username-Upstream/Upstream.git
          src_branch: main
          src_username: ${{ secrets.SRC_USERNAME }}
          src_token: ${{ secrets.SRC_TOKEN }}
          dst: github.com/username/Upstream.git
          dst_branch: master
          dst_username: ${{ secrets.DST_USERNAME }}
          dst_token: ${{ secrets.DST_TOKEN }}
          #force_push: 'true'

```
## 注意事项

⚠️ **重要提示**：
- 仓库地址不需要包含 `https://` 前缀
- 支持 HTTPS 和 SSH 协议（SSH 格式：`git@github.com:user/repo.git`）
- Token 需要具有读写权限
- 目标仓库需要提前创建好
- 首次同步建议使用 `force_push: 'true'`
- 大仓库可调整 `git_post_buffer` 和 `push_timeout` 参数