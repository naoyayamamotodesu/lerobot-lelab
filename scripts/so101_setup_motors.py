"""SO-101 のモーター ID を1台ずつ登録する（途中で止まらず、途中から再開できる版）

公式の `lerobot-setup-motors` との違い：
  - モーターが見つからない・書き込みに失敗しても止まらず、Enter で再試行できる
  - 書き込む前に、そのモーターの今の ID を表示する
  - 別の関節の ID を持つモーターが見えたら（取り違えの可能性）、確認してから上書きする
  - --start で、モーター ID（1〜6）か名前を指定して途中から再開できる
  - --only で、指定したモーターだけ登録し直せる

使い方（モーター同士のケーブルは外し、基板からのケーブル1本だけを使う）：
  uv run python scripts/so101_setup_motors.py --role leader --port /dev/serial/by-id/<基板の名前>
  uv run python scripts/so101_setup_motors.py --role leader --port ... --start 2           # ID 2（shoulder_lift）から再開
  uv run python scripts/so101_setup_motors.py --role leader --port ... --start wrist_flex  # 名前で指定してもよい
  uv run python scripts/so101_setup_motors.py --role follower --port ... --only 6          # gripper だけやり直す

基板の名前は `ls -l /dev/serial/by-id/` で確認する。
"""

import argparse
import sys

# 登録する順番（公式と同じく手先から根元へ）と ID
ORDER = ["gripper", "wrist_roll", "wrist_flex", "elbow_flex", "shoulder_lift", "shoulder_pan"]
IDS = {"shoulder_pan": 1, "shoulder_lift": 2, "elbow_flex": 3, "wrist_flex": 4, "wrist_roll": 5, "gripper": 6}
WHERE = {
    "gripper": "グリッパー（リーダーはハンドルのトリガー部分）",
    "wrist_roll": "手首の回転",
    "wrist_flex": "手首の曲げ",
    "elbow_flex": "肘",
    "shoulder_lift": "肩（アーム全体を前後に倒す関節）",
    "shoulder_pan": "台座の中の根元の回転",
}


def resolve(value: str) -> str:
    """'2' や 'shoulder_lift' をモーター名に変換する"""
    value = value.strip()
    if value.isdigit():
        by_id = {i: m for m, i in IDS.items()}
        if int(value) not in by_id:
            raise ValueError(f"ID は 1〜6 で指定してください：{value}")
        return by_id[int(value)]
    if value not in IDS:
        raise ValueError(f"モーター名が違います：{value}（使える名前：{', '.join(ORDER)}）")
    return value


def targets(start: str | None, only: list[str] | None) -> list[str]:
    if only:
        names = [resolve(v) for v in only]
        return [m for m in ORDER if m in names]
    return ORDER[ORDER.index(resolve(start)):] if start else list(ORDER)


def make_bus(role: str, port: str):
    if role == "leader":
        from lerobot.teleoperators.so_leader import SO101Leader, SO101LeaderConfig

        return SO101Leader(SO101LeaderConfig(port=port, id="setup_motors_tmp")).bus
    from lerobot.robots.so_follower import SO101Follower, SO101FollowerConfig

    return SO101Follower(SO101FollowerConfig(port=port, id="setup_motors_tmp")).bus


def setup_one(bus, scan, name: str, ask=input) -> None:
    """1台登録できるまで繰り返す"""
    while True:
        ask(f"\n▶ 【{name}（ID {IDS[name]}）：{WHERE[name]}】のモーター1台だけに挿して Enter: ")
        hits = [(baud, i) for baud, ids in scan().items() for i in ids]
        print("  今の ID:", [i for _, i in hits] if hits else "見つからない")
        if not hits:
            print("  ✗ 返事がありません。電源の線・ケーブルの奥まで・挿した場所を確認して、もう一度 Enter。")
            continue
        if len(hits) > 1:
            print("  ✗ 2台以上つながっています。モーター同士のケーブルを外して、1台だけにしてください。")
            continue
        baud, cur = hits[0]
        if cur != IDS[name] and cur in IDS.values():
            owner = next(m for m, i in IDS.items() if i == cur)
            answer = ask(f"  ⚠ ID {cur} は {owner} の番号です。挿す場所を間違えていませんか？ 上書きするなら y: ")
            if answer.strip().lower() != "y":
                continue
        try:
            # スキャンで見つかった通信速度と ID をそのまま使う（再探索で取りこぼすのを防ぐ）
            bus.setup_motor(name, initial_baudrate=baud, initial_id=cur)
        except Exception as e:  # noqa: BLE001 — 通信が不安定なときは何が起きても再試行に戻す
            print(f"  ✗ 書き込みに失敗しました（{e}）。ケーブルと電源を確認して、もう一度 Enter。")
            continue
        print(f"  ✓ {name} → ID {IDS[name]} に登録しました。ラベル {IDS[name]} を貼ってください。")
        return


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--role", choices=["leader", "follower"], required=True, help="リーダーかフォロワーか")
    p.add_argument("--port", required=True, help="基板のポート（/dev/serial/by-id/... を推奨）")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--start", help="ここから再開する（ID 1〜6 か名前）。省略すると gripper から")
    g.add_argument("--only", nargs="+", help="このモーターだけ登録する（ID か名前、複数可）")
    args = p.parse_args()

    try:
        names = targets(args.start, args.only)
    except ValueError as e:
        sys.exit(f"エラー：{e}")

    from lerobot.motors.feetech import FeetechMotorsBus

    bus = make_bus(args.role, args.port)
    print(f"{args.role} / {args.port}")
    print("登録する順番:", " → ".join(f"{m}({IDS[m]})" for m in names))
    try:
        for name in names:
            setup_one(bus, lambda: FeetechMotorsBus.scan_port(args.port), name)
    except KeyboardInterrupt:
        print("\n中断しました。登録済みのモーターの ID は残っています。--start で続きから再開できます。")
        sys.exit(1)
    finally:
        try:
            bus.port_handler.closePort()
        except Exception:  # noqa: BLE001
            pass
    print("\n全部終わりました。電源を抜いてから、モーター同士を数珠つなぎにしてください。")


if __name__ == "__main__":
    main()
