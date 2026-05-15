# ==================== 通用仓库同步脚本 ====================
#存在不同步的仓库
HAS_DIFF=false
#代码冲突
CODE_CONFLICT=false
# 新增：关系状态（核心状态机）
RELATION=""
# 新增：统一工作目录（关键修复点）
WORK_DIR=""
# ==================== 通用仓库同步脚本 ====================

build_git_url() {
    local url_temp=${1}
    local username=${2}
    local token=${3}

    if [ -n "${token}" ]; then
       local url=$(echo "$url_temp" | sed 's|https\?://||g')
       if [ -n "${username}" ]; then
          echo "https://${username}:${token}@${url}"
       else
          echo "https://x-access-token:${token}@${url}"
       fi
    elif echo "$url_temp" | grep -q "^git@" || echo "$url_temp" | grep -q "^ssh://"; then
       echo "$url_temp"
    else
       local url=$(echo "$url_temp" | sed 's|https\?://||g')
       echo "https://${url}"
    fi
}

extract_repo_name() {
    local url_temp=${1}

    if echo "$url_temp" | grep -q "^git@"; then
       echo "$url_temp" | sed 's|:|/|g' | sed 's|.*/||' | sed 's|\.git$||'
    elif echo "$url_temp" | grep -q "^ssh://"; then
       echo "$url_temp" | sed 's|.*/||' | sed 's|\.git$||'
    else
       local url=$(echo "$url_temp" | sed 's|https\?://||g')
       echo "$url" | sed 's|.*/||' | sed 's|\.git$||'
    fi
}
extract_repo_owner() {
    local url_temp=${1}

    if echo "$url_temp" | grep -q "^git@"; then
        echo "$url_temp" | sed 's|:|/|g' | awk -F'/' '{print $(NF-1)}'
    elif echo "$url_temp" | grep -q "^ssh://"; then
        echo "$url_temp" | awk -F'/' '{print $(NF-1)}'
    else
        local url=$(echo "$url_temp" | sed 's|https\?://||g')
        echo "$url" | awk -F'/' '{print $(NF-1)}'
    fi
}

detect_platform() {
    local url_temp=${1}

    if echo "$url_temp" | grep -q "github.com"; then
        echo "github"
    elif echo "$url_temp" | grep -q "gitee.com"; then
        echo "gitee"
    elif echo "$url_temp" | grep -q "gitlab.com"; then
        echo "gitlab"
    elif echo "$url_temp" | grep -q "gitcode.net"; then
        echo "gitcode"
    elif echo "$url_temp" | grep -q "cnb.cool"; then        # 新增
        echo "cnb"
    else
        echo "unknown"
    fi
}

create_pull_request() {
    local target_url_temp=${1}
    local target_branch=${2}
    local source_branch=${3}
    local token=${4}
    local username=${5}

    local platform=$(detect_platform "$target_url_temp")
    local repo_name=$(extract_repo_name "$target_url_temp")
    local owner=$(extract_repo_owner "$target_url_temp")
    local pr_title="Sync: ${source_branch} → ${target_branch}"
    local pr_body="Auto sync from ${source_branch} to ${target_branch}\n\nCreated by repo-sync-action"

    echo "📝 创建 Pull Request: ${pr_title}"

    case "$platform" in
        github)
            local api_url="https://api.github.com/repos/${owner}/${repo_name}/pulls"
            local response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
                -H "Authorization: token ${token}" \
                -H "Accept: application/vnd.github.v3+json" \
                -H "Content-Type: application/json" \
                -d "{\"title\":\"${pr_title}\",\"body\":\"${pr_body}\",\"head\":\"${source_branch}\",\"base\":\"${target_branch}\"}")

            local http_code=$(echo "$response" | tail -n1)
            local body=$(echo "$response" | sed '$d')

            if [ "$http_code" = "201" ]; then
                local pr_url=$(echo "$body" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
                echo "✅ PR 创建成功: ${pr_url}"
                return 0
            else
                echo "❌ PR 创建失败 (HTTP ${http_code}): ${body}"
                return 1
            fi
            ;;
        gitee)
            local api_url="https://gitee.com/api/v5/repos/${owner}/${repo_name}/pulls"
            local response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
                -d "access_token=${token}&title=${pr_title}&body=${pr_body}&head=${source_branch}&base=${target_branch}")

            local http_code=$(echo "$response" | tail -n1)
            local body=$(echo "$response" | sed '$d')

            if [ "$http_code" = "201" ]; then
                local pr_url=$(echo "$body" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
                echo "✅ PR 创建成功: ${pr_url}"
                return 0
            else
                echo "❌ PR 创建失败 (HTTP ${http_code}): ${body}"
                return 1
            fi
            ;;
        gitlab)
            local api_url="https://gitlab.com/api/v4/projects/${owner}%2F${repo_name}/merge_requests"
            local response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
                -H "PRIVATE-TOKEN: ${token}" \
                -H "Content-Type: application/json" \
                -d "{\"title\":\"${pr_title}\",\"description\":\"${pr_body}\",\"source_branch\":\"${source_branch}\",\"target_branch\":\"${target_branch}\"}")

            local http_code=$(echo "$response" | tail -n1)
            local body=$(echo "$response" | sed '$d')

            if [ "$http_code" = "201" ]; then
                local pr_url=$(echo "$body" | grep -o '"web_url":"[^"]*"' | cut -d'"' -f4)
                echo "✅ MR 创建成功: ${pr_url}"
                return 0
            else
                echo "❌ MR 创建失败 (HTTP ${http_code}): ${body}"
                return 1
            fi
            ;;
        gitcode)
            local api_url="https://gitcode.net/api/v5/repos/${owner}/${repo_name}/pulls"
            local response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
                -d "access_token=${token}&title=${pr_title}&body=${pr_body}&head=${source_branch}&base=${target_branch}")

            local http_code=$(echo "$response" | tail -n1)
            local body=$(echo "$response" | sed '$d')

            if [ "$http_code" = "201" ]; then
                local pr_url=$(echo "$body" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
                echo "✅ PR 创建成功: ${pr_url}"
                return 0
            else
                echo "❌ PR 创建失败 (HTTP ${http_code}): ${body}"
                return 1
            fi
            ;;
        *)
            echo "❌ 不支持的平台: ${target_url_temp}"
            return 1
            ;;
    esac
}

handle_conflict_with_pr() {
    local target_url_temp=${1}
    local target_branch=${2}
    local target_token=${3}
    local target_username=${4}
    local log_push=${5}
    local relation_type=${6}

    echo "🔄 推送分支以创建 PR"
    git remote add target "$TARGET_URL" 2>/dev/null || true

    local temp_branch="action-${relation_type}-sync-$(openssl rand -hex 4)"
    if ! retry_with_log "git push target HEAD:refs/heads/${temp_branch}" "$log_push"; then
        echo "❌ 推送分支失败"
        git remote remove target 2>/dev/null || true
        return 1
    fi

    git remote remove target 2>/dev/null || true

    if create_pull_request "$target_url_temp" "$target_branch" "$temp_branch" "$target_token" "$target_username"; then
        echo "✅ PR 创建流程完成"
        return 0
    else
        echo "⚠️ PR 创建失败，但分支已推送"
        return 1
    fi
}

handle_merge_conflict() {
    local target_url_temp=${1}
    local target_branch=${2}
    local log_push=${3}
    local relation_type=${4}

    echo "[$relation_type]🔄 尝试合并 target 分支"
    git remote add target "$TARGET_URL" 2>/dev/null || true

    if ! retry_with_log "git fetch target '$target_branch' --quiet" "$log_push"; then
        echo "[$relation_type]❌ 获取 target 分支失败"
        git remote remove target 2>/dev/null || true
        return 1
    fi

    MERGE_OPTS="--no-edit -m \"Merge branch '$target_branch' into sync\""
    if ! git merge-base HEAD "target/$target_branch" >/dev/null 2>&1; then
        MERGE_OPTS="--allow-unrelated-histories $MERGE_OPTS"
    fi

    if ! git merge "target/${target_branch}" $MERGE_OPTS; then
        echo "[$relation_type]❌ 合并冲突，无法自动解决"
        git merge --abort 2>/dev/null || true
        git remote remove target 2>/dev/null || true
        return 1
    fi

    git remote remove target 2>/dev/null || true
    echo "[$relation_type]✅ 合并成功，准备推送"
    PUSH_CMD="git push --progress"
}


# ==================== 日志执行（保留 script -q -c） ====================
run_with_log() {
    local cmd="$1"
    local logfile="$2"

    script -q -e -c "$cmd" /dev/null | tee -a "$logfile"
    local exit_code=${PIPESTATUS[0]}

    return $exit_code
}

retry_with_log() {
    local max=3
    local delay=2
    local attempt=1

    local cmd="$1"
    local logfile="$2"

    while true; do
        echo "🔁 尝试 $attempt/$max: $cmd" | tee -a "$logfile"

        if run_with_log "$cmd" "$logfile"; then
            return 0
        fi

        if [ $attempt -ge $max ]; then
            echo "❌ 达到最大重试次数" | tee -a "$logfile"
            return 1
        fi

        attempt=$((attempt+1))
        echo "⚠️ 重试中..." | tee -a "$logfile"
        sleep $delay
    done
}
# ========================================================

check_repo_diff() {
    local PIR=check_repo_diff
    local source=${1}
    local target=${2}

    local source_url_temp=$(echo "$source" | cut -d '|' -f 1)
    local source_branch=$(echo "$source" | cut -d '|' -f 2)
    local source_username=$(echo "$source" | cut -d '|' -f 3)
    local source_token=$(echo "$source" | cut -d '|' -f 4)

    local target_url_temp=$(echo "$target" | cut -d '|' -f 1)
    local target_branch=$(echo "$target" | cut -d '|' -f 2)
    local target_username=$(echo "$target" | cut -d '|' -f 3)
    local target_token=$(echo "$target" | cut -d '|' -f 4)

    local SOURCE_URL=$(build_git_url "$source_url_temp" "$source_username" "$source_token")
    local TARGET_URL=$(build_git_url "$target_url_temp" "$target_username" "$target_token")
    local repo_name=$(extract_repo_name "$source_url_temp")

    echo "🔍 检查差异: ${repo_name} (${source_branch} → ${target_branch})"

    # 改进：统一工作目录（关键）
    if [ -z "$WORK_DIR" ]; then
        WORK_DIR=$(mktemp -d)
    fi
    cd "$WORK_DIR" || return 1

    log_dir="$WORK_DIR/tmp/log"
    mkdir -p "${log_dir}"

    RANDOM_SALT_CLONE=$(openssl rand -hex 8)
    clone_log="${log_dir}/clone_${RANDOM_SALT_CLONE}.log"
    touch "$clone_log"
    if [ ! -d "$repo_name" ]; then
        if ! retry_with_log "git clone '$SOURCE_URL' -b '$source_branch' '$repo_name'" "$clone_log"; then
            echo "[$PIR]❌ 克隆失败"
            return 1
        fi
    fi

    cd "$repo_name" || return 1

    # GitHub Actions：防 shallow clone
    git fetch --unshallow 2>/dev/null || true

    local SOURCE_SHA=$(git rev-parse HEAD)
    local TARGET_SHA=$(git ls-remote "$TARGET_URL" "$target_branch" 2>/dev/null | awk '{print $1}')

    echo "[$PIR]SHA-SOURCE: $SOURCE_SHA"
    echo "[$PIR]SHA-TARGET: ${TARGET_SHA:-无}"

    # 重置状态
    HAS_DIFF=false
    CODE_CONFLICT=false
    RELATION="unknown"

    if [ -z "$TARGET_SHA" ]; then
        echo "[$PIR]ℹ️ Target 分支不存在，首次推送"
        HAS_DIFF=true
        RELATION="init"
    elif [ "$SOURCE_SHA" = "$TARGET_SHA" ]; then
        echo "[$PIR]✅ SHA 一致，无需更新"
        HAS_DIFF=false
        RELATION="identical"
    else
        git remote add target "$TARGET_URL" 2>/dev/null || true

        if ! retry_with_log "git fetch target '$target_branch' --quiet" "$clone_log"; then
            echo "[$PIR]❌ fetch 失败"
            HAS_DIFF=true
            CODE_CONFLICT=true
            RELATION="error"
        else
            TARGET_REF="target/$target_branch"

            if git merge-base --is-ancestor "$TARGET_REF" HEAD; then
                echo "[$PIR]✅ Fast-forward 更新"
                HAS_DIFF=true
                RELATION="ff"

            elif git merge-base --is-ancestor HEAD "$TARGET_REF"; then
                echo "[$PIR]ℹ️ 无需更新（source 落后于 target）"
                HAS_DIFF=false
                RELATION="behind"

            else
                if git merge-base HEAD "$TARGET_REF" >/dev/null 2>&1; then
                    echo "[$PIR]⚠️ 分支已分叉（diverged）"
                    RELATION="diverged"
                else
                    echo "[$PIR]🚨 无共同历史（unrelated）"
                    RELATION="unrelated"
                fi
                HAS_DIFF=true
                CODE_CONFLICT=true
            fi
        fi

        git remote remove target 2>/dev/null || true
    fi

    cd ..
}

push_target_repo() {
    local PIR=push_target_repo
    local source=${1}
    local target=${2}
    local force_push=${3}
    local git_config=${4}
    local merge_config=${5}
    #分支合并操作
    local diverged_merge_strategy=$(echo "$merge_config" | cut -d '|' -f 1)
    #无历史分支合并操作
    local unrelated_merge_strategy=$(echo "$merge_config" | cut -d '|' -f 2)

    diverged_merge_strategy="${diverged_merge_strategy:-MERGE}"
    unrelated_merge_strategy="${unrelated_merge_strategy:-MERGE}"
    # ===== 恢复：git_config 拆分 =====
    local git_post_buffer=$(echo "$git_config" | cut -d '|' -f 1)
    local git_low_speed_limit=$(echo "$git_config" | cut -d '|' -f 2)
    local git_low_speed_time=$(echo "$git_config" | cut -d '|' -f 3)
    local push_timeout=$(echo "$git_config" | cut -d '|' -f 4)

    local source_url_temp=$(echo "$source" | cut -d '|' -f 1)
    local source_branch=$(echo "$source" | cut -d '|' -f 2)

    local target_url_temp=$(echo "$target" | cut -d '|' -f 1)
    local target_branch=$(echo "$target" | cut -d '|' -f 2)
    local target_username=$(echo "$target" | cut -d '|' -f 3)
    local target_token=$(echo "$target" | cut -d '|' -f 4)

    local TARGET_URL=$(build_git_url "$target_url_temp" "$target_username" "$target_token")
    local repo_name=$(extract_repo_name "$source_url_temp")

    echo "[$PIR] 🚀 推送: ${repo_name} (${source_branch} → ${target_branch})"

    cd "$WORK_DIR/$repo_name" || {
        echo "[$PIR] ❌ 仓库目录不存在: $WORK_DIR/$repo_name"
        return 1
    }

    # ===== 恢复：git config =====
    git config http.postBuffer "${git_post_buffer:-524288000}"
    git config http.lowSpeedLimit "${git_low_speed_limit:-1000}"
    git config http.lowSpeedTime "${git_low_speed_time:-60}"

    RANDOM_SALT_PUSH=$(openssl rand -hex 8)
    log_push="$WORK_DIR/tmp/log/push_${RANDOM_SALT_PUSH}.log"
    touch "$log_push"

    case "$RELATION" in
        init|ff)
            PUSH_CMD="git push --progress"
            ;;
        identical|behind)
            echo "[$PIR] ✅ 无需推送"
            return 0
            ;;
        diverged)
            if [ "${force_push}" = "true" ]; then
                echo "[$PIR] ⚠️ 强制推送"
                PUSH_CMD="git push -f --progress"
            else
                #todo:(当前为合并)MERGE-合并,NEW_PR-新建 PR
                conflict_strategy="${diverged_merge_strategy}"
                case "${conflict_strategy}" in
                    MERGE)
                        handle_merge_conflict "$target_url_temp" "$target_branch" \
                                              "$log_push" "$RELATION"
                        ;;
                    NEW_PR)
                        handle_conflict_with_pr  "$target_url_temp" "$target_branch" \
                                                 "$target_token" "$target_username" \
                                                 "$log_push" "$RELATION"
                        ;;
                    NOTHING)
                        echo "✅ 无需推送"
                        return 0
                        ;;
                    *)
                        echo "❌ 未知的冲突策略: ${conflict_strategy}"
                        return 1
                        ;;
                esac
            fi
            ;;
        unrelated)
            if [ "${force_push}" = "true" ]; then
                echo "⚠️ 强制推送（允许无共同历史）"
                PUSH_CMD="git push -f --progress"
            else
                conflict_strategy="${unrelated_merge_strategy}"
                case "${conflict_strategy}" in
                    MERGE)
                        handle_merge_conflict "$target_url_temp" "$target_branch" \
                                              "$log_push" "$RELATION"
                        ;;
                    NEW_PR)
                        handle_conflict_with_pr  "$target_url_temp" "$target_branch" \
                                                 "$target_token" "$target_username" \
                                                 "$log_push" "$RELATION"
                        ;;
                    NOTHING)
                        echo "✅ 无需推送"
                        return 0
                        ;;
                    *)
                        echo "❌ 未知的冲突策略: ${conflict_strategy}"
                        return 1
                        ;;
                esac
            fi
            ;;
        *)
            echo "❌ 状态异常"
            return 1
            ;;
    esac

    if retry_with_log "timeout ${push_timeout:-3540} $PUSH_CMD '$TARGET_URL' HEAD:$target_branch" "$log_push"; then
        echo "✅ 推送成功"
    else
        echo "❌ 推送失败"
        return 1
    fi

    cd ..
}

sync() {
    local source=${1}
    local target=${2}
    local force_push=${3}
    local git_config=${4}
    local merge_config=${5}

    check_repo_diff "${source}" "${target}"

    if [ "${HAS_DIFF}" = "true" ]; then
        push_target_repo "${source}" "${target}" "${force_push}" "${git_config}" "${merge_config}"
    else
        echo "✅ 无差异，跳过"
    fi

    # 清理目录
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

main_sync(){
  local URL_SOURCE=${1}
  local BRANCH_SOURCE=${2}
  local USERNAME_SOURCE=${3}
  local TOKEN_SOURCE=${4}
  local URL_TARGET=${5}
  local BRANCH_TARGET=${6}
  local USERNAME_TARGET=${7}
  local TOKEN_TARGET=${8}

  local FORCE_PUSH=${9}
  local GIT_POST_BUFFER=${10}
  local GIT_LOW_SPEED_LIMIT=${11}
  local GIT_LOW_SPEED_TIME=${12}
  local PUSH_TIMEOUT=${13}

  local DIVERGED_CONFLICT_STRATEGY=${14}
  local UNRELATED_CONFLICT_STRATEGY=${15}

  local TARGET="${URL_TARGET}|${BRANCH_TARGET}|${USERNAME_TARGET}|${TOKEN_TARGET}"
  local SOURCE="${URL_SOURCE}|${BRANCH_SOURCE}|${USERNAME_SOURCE}|${TOKEN_SOURCE}"
  local GIT_CONFIG="${GIT_POST_BUFFER:-524288000}|${GIT_LOW_SPEED_LIMIT:-1000}|${GIT_LOW_SPEED_TIME:-60}|${PUSH_TIMEOUT:-3540}"
  local MERGE_CONFIG="${DIVERGED_CONFLICT_STRATEGY:-MERGE}|${UNRELATED_CONFLICT_STRATEGY:-MERGE}"

  sync "${SOURCE}" "${TARGET}" "${FORCE_PUSH}" "${GIT_CONFIG}" "${MERGE_CONFIG}"
}
# 从源平台获取 Releases 列表（支持分页，返回 JSON 数组）
fetch_releases() {
    local api_base=${1}
    local release_endpoint=${2}
    local token=${3}
    local limit=${4:-50}

    local url="${api_base}/${release_endpoint}?per_page=${limit}&page=1&sort=created&direction=asc"
    curl -s -H "Authorization: token ${token}" "$url"
}

# 检查目标平台是否已存在同名 tag 的 Release
release_tag_exists() {
    local api_base=${1}
    local release_endpoint=${2}
    local token=${3}
    local tag_name=${4}

    local url="${api_base}/${release_endpoint}/tags/${tag_name}"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token ${token}" "$url")
    [ "$http_code" = "200" ] && return 0 || return 1
}

# 创建 Release
create_release_at_target() {
    local api_base=${1}
    local release_endpoint=${2}
    local token=${3}
    local tag_name=${4}
    local name=${5}
    local body=${6}
    local prerelease=${7}

    local url="${api_base}/${release_endpoint}"
    local response=$(curl -s -X POST "$url" \
        -H "Authorization: token ${token}" \
        -H "Content-Type: application/json" \
        -d "{
            \"tag_name\": \"${tag_name}\",
            \"name\": \"${name}\",
            \"body\": \"${body}\",
            \"prerelease\": ${prerelease}
        }")

    local release_id=$(echo "$response" | jq -r '.id // empty')
    if [ -z "$release_id" ]; then
        echo "❌ 创建失败: $(echo "$response" | jq -r '.message // .')"
        return 1
    fi
    echo "$release_id"
}

# 下载 GitHub/Gitee/GitLab 的资产并上传到目标 Release
upload_assets() {
    local api_base=${1}
    local assets_endpoint=${2}
    local token=${3}
    local release_id=${4}
    local assets_json=${5}   # 源 Release 的 assets 数组 JSON

    echo "${assets_json}" | jq -c '.[]' | while read -r asset; do
        local name=$(echo "$asset" | jq -r '.name')
        local download_url=$(echo "$asset" | jq -r '.browser_download_url // .url')
        echo "  📦 上传资产: ${name}"

        # 下载到临时文件
        local tmp_file="/tmp/release_asset_${RANDOM}.bin"
        curl -sL -o "$tmp_file" "$download_url"

        # 上传到目标 Release
        local upload_url="${api_base}/${assets_endpoint//RELEASE_ID/${release_id}}?name=${name}"
        curl -s -X POST "$upload_url" \
            -H "Authorization: token ${token}" \
            -F "file=@${tmp_file}"

        rm -f "$tmp_file"
    done
}
# 返回格式: "api_base_url|release_endpoint|assets_endpoint"
get_release_api_info() {
    local url_temp=${1}
    local platform=$(detect_platform "$url_temp")
    local owner=$(extract_repo_owner "$url_temp")
    local repo=$(extract_repo_name "$url_temp")

    case "$platform" in
        github)
            echo "https://api.github.com|repos/${owner}/${repo}/releases|repos/${owner}/${repo}/releases/RELEASE_ID/assets"
            ;;
        gitee|gitcode)
            echo "https://${platform}.com/api/v5|repos/${owner}/${repo}/releases|repos/${owner}/${repo}/releases/RELEASE_ID/assets"
            ;;
        gitlab)
            echo "https://gitlab.com/api/v4|projects/${owner}%2F${repo}/releases|projects/${owner}%2F${repo}/releases/RELEASE_ID/assets"
            ;;
        cnb)
            # 假设 cnb.cool 兼容 Gitee OpenAPI 风格，如有差异请替换
            local domain=$(echo "$url_temp" | awk -F'/' '{print $1}')
            echo "https://${domain}/api/v5|repos/${owner}/${repo}/releases|repos/${owner}/${repo}/releases/RELEASE_ID/assets"
            ;;
        *)
            echo "||"
            ;;
    esac
}
# 主入口：同步 Releases
sync_releases() {
    local src_url=${1}
    local src_username=${2}
    local src_token=${3}
    local dst_url=${4}
    local dst_username=${5}
    local dst_token=${6}
    local tag_filter=${7}
    local limit=${8}
    local hour_threshold=${9}

    echo "🔄 开始 Release 同步..."

    # 解析平台 API 信息
    local src_info=$(get_release_api_info "$src_url")
    local dst_info=$(get_release_api_info "$dst_url")
    local src_api_base=$(echo "$src_info" | cut -d'|' -f1)
    local src_release_endpoint=$(echo "$src_info" | cut -d'|' -f2)
    local src_assets_endpoint=$(echo "$src_info" | cut -d'|' -f3)
    local dst_api_base=$(echo "$dst_info" | cut -d'|' -f1)
    local dst_release_endpoint=$(echo "$dst_info" | cut -d'|' -f2)
    local dst_assets_endpoint=$(echo "$dst_info" | cut -d'|' -f3)

    if [ -z "$src_api_base" ] || [ -z "$dst_api_base" ]; then
        echo "❌ 无法识别源/目标平台 API"
        return 1
    fi

    # 获取源 Releases（按 created 升序）
    local releases_json=$(fetch_releases "$src_api_base" "$src_release_endpoint" "$src_token" "$limit")
    if [ -z "$releases_json" ] || [ "$releases_json" = "[]" ]; then
        echo "⚠️ 源仓库无 Release 数据"
        return 0
    fi

    # 时间阈值过滤（hour_threshold > 0 时生效）
    if [ "$hour_threshold" -gt 0 ]; then
        local threshold_ts=$(date -d "${hour_threshold} hours ago" +%s)
        releases_json=$(echo "$releases_json" | jq --argjson ts "$threshold_ts" '
            [ .[] | select( (.created_at | fromdate) >= $ts ) ]')
    fi

    # 如果指定了 tag，仅保留该 tag 的 Release
    if [ -n "$tag_filter" ]; then
        releases_json=$(echo "$releases_json" | jq --arg tag "$tag_filter" '
            [ .[] | select(.tag_name == $tag) ]')
    fi

    local total=$(echo "$releases_json" | jq 'length')
    if [ "$total" -eq 0 ]; then
        echo "✅ 没有需要同步的 Release"
        return 0
    fi
    echo "📋 将同步 ${total} 个 Release"

    # 遍历每个源 Release
    echo "$releases_json" | jq -c '.[]' | while read -r release; do
        local tag_name=$(echo "$release" | jq -r '.tag_name')
        local name=$(echo "$release" | jq -r '.name // .tag_name')
        local body=$(echo "$release" | jq -r '.body // ""')
        local prerelease=$(echo "$release" | jq -r '.prerelease // false')
        local assets=$(echo "$release" | jq -r '.assets // empty')

        echo "🏷️ 处理: ${tag_name}"

        # 检查目标是否已存在
        if release_tag_exists "$dst_api_base" "$dst_release_endpoint" "$dst_token" "$tag_name"; then
            echo "  ⏭️ 目标已存在同名 Release，跳过"
            continue
        fi

        # 创建 Release
        local new_id=$(create_release_at_target "$dst_api_base" "$dst_release_endpoint" "$dst_token" \
            "$tag_name" "$name" "$body" "$prerelease")
        if [ -z "$new_id" ]; then
            echo "  ❌ 创建失败，继续下一个"
            continue
        fi
        echo "  ✅ 创建成功，ID: ${new_id}"

        # 上传资产（如果有）
        if [ "$assets" != "null" ] && [ "$assets" != "[]" ]; then
            upload_assets "$dst_api_base" "$dst_assets_endpoint" "$dst_token" "$new_id" "$assets"
        fi
    done

    echo "🎉 Release 同步完成"
}