# repo-sync-action

GitHub Action 用于同步仓库代码到不同平台（如 GitHub → Gitee）

## 使用示例
```yaml
- name: Sync GitHub to Gitee
  uses: Kirito520Asuna/repo-sync-action@main
  with:
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
```
## 参数说明

| 参数 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `src` | 是 | 源仓库地址 | `github.com/user/repo.git` |
| `src_branch` | 是 | 源仓库分支 | `main` |
| `src_username` | 是 | 源仓库用户名 | `${{ secrets.SRC_USERNAME }}` |
| `src_token` | 是 | 源仓库访问令牌 | `${{ secrets.SRC_TOKEN }}` |
| `dst` | 是 | 目标仓库地址 | `gitee.com/user/repo.git` |
| `dst_branch` | 是 | 目标仓库分支 | `master` |
| `dst_username` | 是 | 目标仓库用户名 | `${{ secrets.DST_USERNAME }}` |
| `dst_token` | 是 | 目标仓库访问令牌 | `${{ secrets.DST_TOKEN }}` |

## 配置 Secrets

在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中添加以下密钥：

- `SRC_USERNAME`: 源仓库用户名
- `SRC_TOKEN`: 源仓库 Personal Access Token
- `DST_USERNAME`: 目标仓库用户名
- `DST_TOKEN`: 目标仓库 Personal Access Token / 私有令牌

