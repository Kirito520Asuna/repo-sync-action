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
            echo "❌ 克隆失败"
            return 1
        fi
    fi

    cd "$repo_name" || return 1

    # GitHub Actions：防 shallow clone
    git fetch --unshallow 2>/dev/null || true

    local SOURCE_SHA=$(git rev-parse HEAD)
    local TARGET_SHA=$(git ls-remote "$TARGET_URL" "$target_branch" 2>/dev/null | awk '{print $1}')

    echo "SHA-SOURCE: $SOURCE_SHA"
    echo "SHA-TARGET: ${TARGET_SHA:-无}"

    # 重置状态
    HAS_DIFF=false
    CODE_CONFLICT=false
    RELATION="unknown"

    if [ -z "$TARGET_SHA" ]; then
        echo "ℹ️ Target 分支不存在，首次推送"
        HAS_DIFF=true
        RELATION="init"
    else
        git remote add target "$TARGET_URL" 2>/dev/null || true

        if ! retry_with_log "git fetch target '$target_branch' --quiet" "$clone_log"; then
            echo "❌ fetch 失败"
            HAS_DIFF=true
            CODE_CONFLICT=true
            RELATION="error"
        else
            TARGET_REF="target/$target_branch"

            if git merge-base --is-ancestor "$TARGET_REF" HEAD; then
                echo "✅ Fast-forward 更新"
                HAS_DIFF=true
                RELATION="ff"

            elif git merge-base --is-ancestor HEAD "$TARGET_REF"; then
                echo "ℹ️ 无需更新（source 落后于 target）"
                HAS_DIFF=false
                RELATION="behind"

            else
                if git merge-base HEAD "$TARGET_REF" >/dev/null 2>&1; then
                    echo "⚠️ 分支已分叉（diverged）"
                    RELATION="diverged"
                else
                    echo "🚨 无共同历史（unrelated）"
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
    local source=${1}
    local target=${2}
    local force_push=${3}
    local git_config=${4}

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

    echo "🚀 推送: ${repo_name} (${source_branch} → ${target_branch})"

    cd "$WORK_DIR/$repo_name" || {
        echo "❌ 仓库目录不存在: $WORK_DIR/$repo_name"
        return 1
    }

    # ===== 恢复：git config =====
    git config http.postBuffer "${git_post_buffer:-524288000}"
    git config http.lowSpeedLimit "${git_low_speed_limit:-1000}"
    git config http.lowSpeedTime "${git_low_speed_time:-60}"

    case "$RELATION" in
        init|ff)
            PUSH_CMD="git push --progress"
            ;;
        behind)
            echo "✅ 无需推送"
            return 0
            ;;
        diverged|unrelated)
            if [ "${force_push}" = "true" ]; then
                echo "⚠️ 强制推送"
                PUSH_CMD="git push -f --progress"
            else
                echo "❌ 冲突，拒绝推送"
                return 1
            fi
            ;;
        *)
            echo "❌ 状态异常"
            return 1
            ;;
    esac

    RANDOM_SALT_PUSH=$(openssl rand -hex 8)
    log_push="$WORK_DIR/tmp/log/push_${RANDOM_SALT_PUSH}.log"
    touch "$log_push"
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

    check_repo_diff "${source}" "${target}"

    if [ "${HAS_DIFF}" = "true" ]; then
        push_target_repo "${source}" "${target}" "${force_push}" "${git_config}"
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

  local TARGET="${URL_TARGET}|${BRANCH_TARGET}|${USERNAME_TARGET}|${TOKEN_TARGET}"
  local SOURCE="${URL_SOURCE}|${BRANCH_SOURCE}|${USERNAME_SOURCE}|${TOKEN_SOURCE}"
  local GIT_CONFIG="${GIT_POST_BUFFER:-524288000}|${GIT_LOW_SPEED_LIMIT:-1000}|${GIT_LOW_SPEED_TIME:-60}|${PUSH_TIMEOUT:-3540}"

  sync "${SOURCE}" "${TARGET}" "${FORCE_PUSH}" "${GIT_CONFIG}"
}
