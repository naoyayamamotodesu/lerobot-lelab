#!/usr/bin/env bash
# データセットを記録する。保存先：~/.cache/huggingface/lerobot/<repo_id>
#   ./scripts/record.sh <repo_id> "<タスクの説明（英語）>" [エピソード数] [その他の lerobot-record の引数...]
#   例：./scripts/record.sh rebot/grab_cube "Grab the black cube" 10
#   撮り足す：./scripts/record.sh rebot/grab_cube "Grab the black cube" 5 --resume=true
# 記録中：→ 次へ / ← 撮り直し / ESC 保存して終了（Ctrl+C は保存されない）
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [[ $# -lt 2 ]]; then
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi
repo_id="$1"; task="$2"; episodes="${3:-5}"
shift $(( $# >= 3 ? 3 : 2 ))

require_port "フォロワー" "$FOLLOWER_PORT"
require_port "リーダー" "$LEADER_PORT"
confirm_zero_pose

run lerobot-record \
  "${ROBOT_ARGS[@]}" \
  --robot.cameras="$CAMERAS" \
  "${TELEOP_ARGS[@]}" \
  --display_data=true \
  --dataset.repo_id="$repo_id" \
  --dataset.single_task="$task" \
  --dataset.num_episodes="$episodes" \
  --dataset.fps="$FPS" \
  --dataset.episode_time_s="${EPISODE_TIME_S:-30}" \
  --dataset.reset_time_s="${RESET_TIME_S:-30}" \
  --dataset.push_to_hub=false \
  "$@"
