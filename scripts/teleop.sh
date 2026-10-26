#!/usr/bin/env bash
# リーダーでフォロワーを動かす（保存はしない）
#   ./scripts/teleop.sh            カメラあり（Rerun で表示）
#   NO_CAMERA=1 ./scripts/teleop.sh  カメラなし
set -euo pipefail
source "$(dirname "$0")/config.sh"
require_port "フォロワー" "$FOLLOWER_PORT"
require_port "リーダー" "$LEADER_PORT"
confirm_zero_pose

args=("${ROBOT_ARGS[@]}" "${TELEOP_ARGS[@]}" --fps="$FPS")
if [[ "${NO_CAMERA:-0}" != "1" ]]; then
  args+=(--robot.cameras="$CAMERAS" --display_data=true)
fi
run lerobot-teleoperate "${args[@]}" "$@"
