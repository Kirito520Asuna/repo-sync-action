# ==================== 通用仓库同步脚本 ====================

HAS_DIFF=false

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

    local source_url=$(echo "$source_url_temp" | sed 's|https\?://||g')
    local target_url=$(echo "$target_url_temp" | sed 's|https\?://||g')

    local SOURCE_URL="https://${source_username}:${source_token}@${source_url}"
    local TARGET_URL="https://${target_username}:${target_token}@${target_url}"

    local repo_name=$(echo "$source_url" | sed 's|.*/||' | sed 's|\.git$||')

    echo "🔍 检查差异: ${repo_name} (${source_branch} → ${target_branch})"

    if [ -d "$repo_name" ]; then
        rm -rf "$repo_name"
    fi

    git clone "$SOURCE_URL" -b "$source_branch" "$repo_name" || {
        echo "❌ 克隆失败"
        return 1
    }

    cd "$repo_name" || return 1

    local SOURCE_SHA=$(git rev-parse HEAD)
    local TARGET_SHA=$(git ls-remote "$TARGET_URL" "$target_branch" 2>/dev/null | awk '{print $1}')

    echo "SOURCE: $SOURCE_SHA"
    echo "TARGET: ${TARGET_SHA:-无}"

    if [ "$SOURCE_SHA" = "$TARGET_SHA" ] && [ -n "$TARGET_SHA" ]; then
        HAS_DIFF=false
    else
        HAS_DIFF=true
    fi

    cd ..
}

push_target_repo() {
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

    local source_url=$(echo "$source_url_temp" | sed 's|https\?://||g')
    local target_url=$(echo "$target_url_temp" | sed 's|https\?://||g')

    local SOURCE_URL="https://${source_username}:${source_token}@${source_url}"
    local TARGET_URL="https://${target_username}:${target_token}@${target_url}"

    local repo_name=$(echo "$source_url" | sed 's|.*/||' | sed 's|\.git$||')

    echo "🚀 推送: ${repo_name} (${source_branch} → ${target_branch})"

    if [ ! -d "$repo_name" ]; then
        git clone "$SOURCE_URL" -b "$source_branch" "$repo_name"
    fi

    cd "$repo_name" || return 1

    git config http.postBuffer 524288000
    git config http.lowSpeedLimit 1000
    git config http.lowSpeedTime 60

    if timeout 1800 git push -f "$TARGET_URL" "HEAD:${target_branch}" 2>&1; then
        echo "✅ 推送成功"
    else
        echo "❌ 推送失败"
        cd ..
        return 1
    fi

    cd ..
    rm -rf "$repo_name"
}

sync() {
    local source=${1}
    local target=${2}

    check_repo_diff "${source}" "${target}"

    if [ "${HAS_DIFF}" = "true" ]; then
        push_target_repo "${source}" "${target}"
    else
        echo "✅ 无差异，跳过"
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

  local TARGET="${URL_TARGET}|${BRANCH_TARGET}|${USERNAME_TARGET}|${TOKEN_TARGET}"
  local SOURCE="${URL_SOURCE}|${BRANCH_SOURCE}|${USERNAME_SOURCE}|${TOKEN_SOURCE}"
  sync "${SOURCE}" "${TARGET}"
}
