# ==================== 通用仓库同步脚本 ====================

HAS_DIFF=false
build_git_url() {
    local url_temp=${1}
    local username=${2}
    local token=${3}

    if echo "$url_temp" | grep -q "^git@" || echo "$url_temp" | grep -q "^ssh://"; then
       echo "$url_temp"
    else
       local url=$(echo "$url_temp" | sed 's|https\?://||g')
       if [ -n "${token}" ]; then
          echo "https://${username}:${token}@${url}"
       else
          echo "https://${url}"
       fi
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

    echo "SHA-SOURCE: $SOURCE_SHA"
    echo "SHA-TARGET: ${TARGET_SHA:-无}"

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
    local force_push=${3}
    local git_config=${4}

    local git_post_buffer=$(echo "$git_config" | cut -d '|' -f 1)
    local git_low_speed_limit=$(echo "$git_config" | cut -d '|' -f 2)
    local git_low_speed_time=$(echo "$git_config" | cut -d '|' -f 3)
    local push_timeout=$(echo "$git_config" | cut -d '|' -f 4)

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

    echo "🚀 推送: ${repo_name} (${source_branch} → ${target_branch})"

    if [ ! -d "$repo_name" ]; then
        git clone "$SOURCE_URL" -b "$source_branch" "$repo_name"
    fi

    cd "$repo_name" || return 1

    git config http.postBuffer "${git_post_buffer:-524288000}"
    git config http.lowSpeedLimit "${git_low_speed_limit:-1000}"
    git config http.lowSpeedTime "${git_low_speed_time:-60}"
    
    PUSH_CMD="git push --progress"
    if [ "${force_push}" = "true" ]; then
       PUSH_CMD="git push -f --progress"
    fi
    local RANDOM_SALT=$(openssl rand -hex 16)
    log_dir="/tmp/${RANDOM_SALT}"
    log=${log_dir}/push_output.log

#    mkdir "${log_dir}"
#    touch "${log}"
    if timeout "${push_timeout:-3540}" script -q -c "$PUSH_CMD $TARGET_URL HEAD:${target_branch}" $log 2>&1; then
       echo "✅ 推送成功"
    else
       echo "❌ 推送失败"
       echo "错误详情:"
       cat $log
       cd ..
       return 1
    fi

    cd ..
    rm -rf "$repo_name"
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
