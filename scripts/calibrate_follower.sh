#!/usr/bin/env bash
# フォロワー（B601-DM）のゼロ位置を記録する。24V 電源を入れてから実行する
set -euo pipefail
source "$(dirname "$0")/config.sh"
require_port "フォロワー" "$FOLLOWER_PORT"
run lerobot-calibrate "${ROBOT_ARGS[@]}" "$@"
