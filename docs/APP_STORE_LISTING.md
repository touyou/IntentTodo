# App Store Connect 入力項目

1.0 提出時に App Store Connect へ入れるテキスト。**下書き**で、そのまま貼れる形にしてある。

- 文字数は ASC の上限に収めてある（各項目の見出しに上限を書いた）
- **`要入力` と書いてある行は本人しか決められないもの**。埋めないと提出できない
- スクショは `Screenshots/<platform>/<locale>/`（`scripts/capture_screenshots.sh` で再生成）

---

## 1. App 情報（ロケール共通）

| 項目 | 値 |
|---|---|
| バンドル ID | `dev.touyou.IntentTodo` |
| SKU | `要入力`（例: `INTENTO-1`） |
| プライマリカテゴリ | 仕事効率化 / Productivity |
| セカンダリカテゴリ | ユーティリティ / Utilities |
| 権利（Copyright） | `2026 Yosuke Fujii` |
| 年齢制限 | 4+（暴力・成人向け要素いずれも「なし」） |
| 価格 | `要入力`（無料想定） |
| App 内課金 | なし |

> `INFOPLIST_KEY_LSApplicationCategoryType` は `public.app-category.utilities`。
> ASC 側のプライマリカテゴリと**揃える**か、どちらかに寄せる。上表は「仕事効率化を主」に寄せた案。

### 配信プラットフォーム

iOS / iPadOS / macOS / watchOS / visionOS。**1 つの App レコードで 5 面**。
watchOS は iOS アプリに埋め込み、macOS と visionOS はネイティブ。

---

## 2. 日本語（プライマリ）

### App 名（30 文字）

```
Intento
```

### サブタイトル（30 文字）

```
声からも、ウィジェットからも
```

代替案:

```
Siri とショートカットのための ToDo
```

### プロモーションテキスト（170 文字 / 審査なしで差し替え可）

```
話しかけるだけで、やることが増えたり片づいたりします。ウィジェット、コントロールセンター、
ロック画面、Apple Watch、Spotlight — アプリを開かずに済む場所ならどこでも同じ操作ができます。
```

### 説明（4000 文字）

```
Intento は「アプリを開く」を前提にしないやることリストです。

やることの追加も、完了も、あと回しも、Siri に話しかければ終わります。ホーム画面のウィジェット、
コントロールセンター、ロック画面、Apple Watch の文字盤、Spotlight の検索結果 — どこから触っても
同じ操作が同じように動きます。アプリを開くのは、じっくり見直したいときだけで構いません。

■ 声で操作する
「Intento でやることを追加」「Intento で〇〇を完了」のように話しかけるだけ。やることの名前を
そのまま文に混ぜられるので、選び直す手間がありません。

■ 開かずに済ませる
・ウィジェット（小・中・大・特大）に今日のやることを表示。チェックはその場で
・コントロールセンターからワンタップで追加、未完了の数を確認、いちばん急ぎのものを完了
・ロック画面のライブアクティビティで進行中のやることを追いかける
・Apple Watch のコンプリケーションに残り件数と次の期限

■ 探す
Spotlight でやることのタイトルを検索。カメラを向けた先や画面の中身からも探せます。

■ 集中する
集中モードと連動して、いま見るべきやることだけを残します。カテゴリで絞る、急ぎだけにする、
完了したものを隠す — モードごとに切り替わります。

■ ショートカットに組み込む
25 種類のアクションを公開しています。「やることの一覧を取得」「条件に合うものを探す」
「まとめて完了する」など、ほかのアプリと組み合わせた自動化にそのまま使えます。

■ すべての Apple デバイスで
iPhone、iPad、Mac、Apple Watch、Apple Vision Pro。iCloud で同期するので、どこで足しても
どこでも見えます。

データはあなたの iCloud の中だけにあります。アカウント登録はありません。広告もトラッキングも
ありません。
```

### キーワード（100 文字 / カンマ区切り・スペースなし）

```
todo,タスク,やること,リマインダー,siri,ショートカット,ウィジェット,音声,習慣,メモ,予定,効率化
```

### サポート URL

```
要入力
```
（GitHub の issue ページを充てるなら `https://github.com/touyou/IntentTodo/issues`）

### マーケティング URL（任意）

```
要入力
```

### プライバシーポリシー URL

```
要入力
```
**必須。** 収集ゼロでも URL は要る。内容は §5 のドラフトをそのまま置ける。

### このバージョンの新機能（4000 文字）

```
最初のリリースです。
```

---

## 3. English

### App Name（30）

```
Intento
```

### Subtitle（30）

```
Todos by voice and widget
```

### Promotional Text（170）

```
Say it and it's on the list. Add, complete and snooze from Siri, widgets, Control Center,
the Lock Screen, Apple Watch and Spotlight — the app itself is optional.
```

### Description（4000）

```
Intento is a todo list that does not assume you will open it.

Add something, finish it, or push it to later just by asking Siri. The same actions work
from a Home Screen widget, from Control Center, from the Lock Screen, from your Apple Watch
face and from Spotlight results. Opening the app is for when you actually want to sit and
look at the list.

■ Say it
"Add a todo in Intento." "Complete <todo> in Intento." Todo names go straight into the
phrase, so there is no picker to work through afterwards.

■ Skip the app
· Widgets in every size, with a checkbox on each row
· Control Center: add in one tap, see how many are left, finish the most urgent one
· A Live Activity on the Lock Screen for whatever is in progress
· An Apple Watch complication with the count and the next due date

■ Find it
Search your todos from Spotlight — including from what your camera or your screen is
looking at.

■ Focus
Tie a Focus to a category, to urgent items only, or to hiding what is done. The list and
the widgets both follow it.

■ Automate it
25 actions are published to Shortcuts: get the list, find the ones that match, complete a
batch. They compose with everything else on your device.

■ Everywhere
iPhone, iPad, Mac, Apple Watch and Apple Vision Pro, kept in step through iCloud.

Your todos live in your own iCloud. No account, no ads, no tracking.
```

### Keywords（100, comma separated, no spaces）

```
todo,task,reminder,siri,shortcuts,widget,voice,checklist,productivity,list,planner,focus
```

### What's New（4000）

```
First release.
```

---

## 4. App プライバシー（ASC の質問）

| 質問 | 回答 |
|---|---|
| データを収集しますか | **いいえ** |
| トラッキングしますか | **いいえ** |

Todo の中身は端末とユーザー自身の iCloud プライベートデータベースにしか入らず、開発者は
取得しない。Apple の定義では「収集」に当たらない。

`PrivacyInfo.xcprivacy` の申告と揃っている:

- `NSPrivacyTracking = false`
- `NSPrivacyCollectedDataTypes = []`
- `NSPrivacyAccessedAPITypes` = `NSPrivacyAccessedAPICategoryUserDefaults`（`CA92.1` / `1C8F.1`）

---

## 5. プライバシーポリシー（ドラフト）

置き場が決まったら貼る。

```
Intento プライバシーポリシー

Intento は、あなたが入力したやることを、お使いの Apple デバイスと、あなた自身の iCloud
プライベートデータベースにのみ保存します。開発者はその内容を取得も閲覧もしません。

・アカウント登録はありません
・解析ツール、広告、トラッキングは一切組み込んでいません
・第三者へ提供するデータはありません

アプリの設定値（集中モードの絞り込み条件など）は、アプリと Extension だけがアクセスできる
App Group の内部に保存されます。

データを削除したい場合は、アプリからやることを削除するか、デバイスからアプリを削除して
ください。iCloud 上のデータは iOS の「設定 > Apple Account > iCloud」から削除できます。

お問い合わせ: <要入力>
```

---

## 6. 審査メモ（App Review Information）

```
Intento is a todo app built entirely around App Intents: every action is an App Intent, and
the same intent runs from the UI, Siri, Shortcuts, widgets, Control Center, the Lock Screen
and Spotlight.

No account is required. Nothing to sign in to. All data stays on device and in the user's
own iCloud private database.

To see the Siri / Shortcuts side, either:
  - say "Add a todo in Intento", or
  - open Shortcuts.app and look under Intento — 25 actions are published.

The app requests notification permission so widget and Control Center failures can be
reported back to the person; declining it does not restrict any feature.
```

連絡先は `要入力`（氏名 / 電話番号 / メール）。

---

## 7. スクリーンショット

`scripts/capture_screenshots.sh` の出力をそのまま上げる。

| ASC の枠 | ファイル | 画素数 |
|---|---|---|
| iPhone 6.9" | `Screenshots/iphone/<locale>/` | 1320x2868 × 4 |
| iPad 13" | `Screenshots/ipad/<locale>/` | 2064x2752 × 4 |
| Mac | `Screenshots/mac/<locale>/` | 2880x1800 × 3 |
| Apple Vision Pro | `Screenshots/vision/<locale>/` | 3840x2160 × 3 |
| Apple Watch | `Screenshots/watch/<locale>/` | 422x514 × 2 |

ロケールは `en` と `ja` の 2 本。ASC はロケールごとにスクショを差し替えられる。

---

## 8. 提出前の確認

- [ ] `要入力` が全部埋まっている
- [ ] プライバシーポリシーが公開 URL で読める
- [ ] Xcode Cloud の `production` ビルドが ASC に上がっている
- [ ] 輸出コンプライアンスの質問が出ない（`ITSAppUsesNonExemptEncryption = NO` 済み）
- [ ] アップロード後に ITMS の警告メールが来ていない
