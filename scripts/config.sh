# reBot B601-DM（フォロワー）＋ reBot Arm 102（リーダー）の共通設定
# 各スクリプトから source される。値は環境変数で上書きできる（例：FPS=30 ./scripts/teleop.sh）

# --- ポート（抜き差しで番号が変わらない by-id の名前） ---
: "${FOLLOWER_PORT:=/dev/serial/by-id/usb-HDSC_CDC_Device_00000000050C-if00}"  # Damiao シリアルブリッジ
: "${LEADER_PORT:=/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0}"          # CH340

# --- キャリブレーションの id（ファイル名になる。全スクリプトで同じものを使う） ---
: "${FOLLOWER_ID:=follower}"
: "${LEADER_ID:=leader}"

# --- カメラ（RealSense D405） ---
: "${CAMERA_SERIAL:=260422274170}"
: "${CAMERA_NAME:=d405}"
: "${CAMERA_WIDTH:=640}"
: "${CAMERA_HEIGHT:=480}"
: "${USE_DEPTH:=false}"

# --- 制御・記録の周波数 ---
: "${FPS:=60}"

# ---------------------------------------------------------------------------

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ROS2 の .bashrc が入れる PYTHONPATH が混ざると import が壊れるので外す
unset PYTHONPATH

ROBOT_ARGS=(
  --robot.type=rebot_b601_follower
  --robot.port="$FOLLOWER_PORT"
  --robot.id="$FOLLOWER_ID"
  --robot.can_adapter=damiao
)

TELEOP_ARGS=(
  --teleop.type=rebot_102_leader
  --teleop.port="$LEADER_PORT"
  --teleop.id="$LEADER_ID"
)

CAMERAS="{ ${CAMERA_NAME}: {type: intelrealsense, serial_number_or_name: \"${CAMERA_SERIAL}\", width: ${CAMERA_WIDTH}, height: ${CAMERA_HEIGHT}, fps: ${FPS}, use_depth: ${USE_DEPTH}}}"

# lerobot のコマンドを uv の環境で実行する。DRY_RUN=1 なら実行せずに表示だけ
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%q ' uv run --project "$ROOT" "$@"; echo
  else
    uv run --project "$ROOT" "$@"
  fi
}

# ポートが見えているか確認する（USB の抜け・電源の入れ忘れを早めに知らせる）
require_port() {
  local label="$1" port="$2"
  [[ "${DRY_RUN:-0}" == "1" ]] && return 0
  if [[ ! -e "$port" ]]; then
    echo "エラー：${label} のポートが見つかりません：$port" >&2
    echo "  USB が挿さっているか確認してください。今見えているポート：" >&2
    ls -l /dev/serial/by-id/ 2>/dev/null >&2 || echo "  （シリアルポートが1つもありません）" >&2
    exit 1
  fi
}

confirm_zero_pose() {
  [[ "${DRY_RUN:-0}" == "1" ]] && return 0
  echo "接続のたびに今の姿勢がゼロ点になります。"
  echo "アームをゼロ位置（座った姿勢・グリッパーを完全に閉じた状態）に置いてから Enter を押してください。"
  read -r
}
