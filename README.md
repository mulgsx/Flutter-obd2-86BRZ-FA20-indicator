# 86BRZ / FA20 OBD2 Monitor

Real-time OBD2 monitor for Toyota 86 / Subaru BRZ (FA20 engine) via ELM327 BLE adapter.
Toyota 86 / Subaru BRZ（FA20エンジン）向け、ELM327 BLE アダプターを使ったリアルタイム OBD2 モニターアプリ。

---

## Screenshots / スクリーンショット

### Current UI / 現在の画面

![Dashboard](assets/photo/git1.jpg)

### Custom Gauge Examples / カスタムゲージ例

`GaugeWidget` を差し替えることで、自分のデザインのゲージを表示できる。
The gauge widget is replaceable — swap in your own design.

<table>
  <tr>
    <td><img src="assets/photo/git2.jpg" width="400" alt="Arc gauge (dark theme, live data)"></td>
    <td><img src="assets/photo/git3.jpg" width="400" alt="Character gauge (demo mode)"></td>
  </tr>
  <tr>
    <td align="center">Arc gauge — dark theme, live OBD2 data<br>円弧ゲージ（ダークテーマ・実車接続）</td>
    <td align="center">Character gauge — demo mode<br>キャラクターゲージ（デモモード）</td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="assets/photo/git4.jpg" width="500" alt="Running in the car"></td>
  </tr>
  <tr>
    <td colspan="2" align="center">Running on a phone and car display / 実車に搭載した様子</td>
  </tr>
</table>

---

## Tech Stack / 技術スタック

| Technology | Role / 用途 |
|---|---|
| Flutter (Dart) | UI framework / UI フレームワーク |
| GetX | State management & navigation / 状態管理・ナビゲーション |
| flutter_blue_plus | BLE communication / BLE 通信 |

---

## Confirmed Environment / 動作確認環境

| Item / 項目 | Details / 内容 |
|---|---|
| Vehicle / 車両 | Toyota 86 / Subaru BRZ (ZC6) — FA20 engine |
| OBD2 Adapter / アダプター | ELM327 BLE（FFF0 / FFE0 サービス搭載品） |
| Platform / プラットフォーム | Android |
