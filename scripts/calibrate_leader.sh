#!/usr/bin/env bash
# リーダー（reBot Arm 102）のゼロ位置を記録する
set -euo pipefail
source "$(dirname "$0")/config.sh"
require_port "リーダー" "$LEADER_PORT"
run lerobot-calibrate "${TELEOP_ARGS[@]}" "$@"
