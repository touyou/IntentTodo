# App Store Connect 入力項目

1.0 提出時に App Store Connect へ入れるテキスト。**下書き**で、そのまま貼れる形にしてある。

- 文字数は ASC の上限に収めてある（各項目の見出しに上限を書いた）
- **`要入力` と書いてある行は本人しか決められないもの**。埋めないと提出できない
- スクショは `Screenshots/<platform>/<locale>/`（`scripts/capture_screenshots.sh` で再生成）

---

## 1. App 情報（ロケール共通）

| 項目 | 値 |
|---|---|
| App ID | `6788623037` |
| バンドル ID | `dev.touyou.IntentTodo` |
| SKU | `dev.touyou.IntentTodo`（設定済み） |
| プライマリカテゴリ | 仕事効率化 / Productivity |
| セカンダリカテゴリ | ユーティリティ / Utilities |
| 権利（Copyright） | `2026 touyou`（3 バージョンとも設定済み） |
| 年齢制限 | 4+（暴力・成人向け要素いずれも「なし」） |
| 価格 | 無料（free price point / 全 175 テリトリー / 新規テリトリーも自動で有効） |
| App 内課金 | なし |
| リリース方法 | `AFTER_APPROVAL`（審査通過後に自動公開）。段階的リリースは未設定 |

> `INFOPLIST_KEY_LSApplicationCategoryType` は `public.app-category.utilities`。
> ASC 側のプライマリカテゴリと**揃える**か、どちらかに寄せる。上表は「仕事効率化を主」に寄せた案。

### 配信プラットフォーム

iOS / iPadOS / macOS / watchOS / visionOS。**1 つの App レコードで 5 面**。
watchOS は iOS アプリに埋め込み、macOS と visionOS はネイティブ。

---

## 2. 文言（ja / en）

**`metadata/` が正**。App 名 / サブタイトル / 説明 / キーワード / プロモーションテキスト /
各種 URL は `asc` で ASC と同期する。ここに同じ文章を二重に置かない。

```
metadata/
  ios/       app-info/{en-US,ja}.json  version/1.1.0/{en-US,ja}.json
  macos/     同じ
  visionos/  同じ
```

**バージョンレコードは iOS / macOS / visionOS で別々**なので、3 つとも入れる必要がある。
`version/<version>/` は出しているバージョンごとに 1 つ。`whatsNew` はここに置く（1.0.0 には無い
— 初回リリースなので不要だった）。
`app-info/`（名前・サブタイトル・プライバシーポリシー URL）はアプリ単位なので中身は 3 つとも同じ。

### 反映のしかた

```bash
# 1. 今 ASC に入っているものを取り込む（手で編集した分を拾う）
asc metadata pull --app 6788623037 --version 1.1.0 --platform IOS --dir metadata/ios

# 2. 差分を見る（書き込みなし）
asc metadata plan --app 6788623037 --version 1.1.0 --platform IOS --dir metadata/ios

# 3. 承認して反映
asc metadata approve --review-dir .asc/metadata/review --all
asc metadata apply --app 6788623037 --version 1.1.0 --platform IOS --dir metadata/ios \
  --review-dir .asc/metadata/review --confirm
```

`--platform` を `MAC_OS` / `VISION_OS` に変え、`--dir` も合わせて 3 回まわす。

> **`plan` を飛ばさない。** ローカルが正なので、ASC 側で手直しした内容は `pull` しない限り
> 上書きされる。`deletes` は既定で無効（`allowDeletes: false`）。

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

## 5. プライバシーポリシー

[PRIVACY.md](../PRIVACY.md)（ja / en 併記）。ASC の `privacyPolicyUrl` はこの raw URL を指す:

```
https://github.com/touyou/IntentTodo/blob/main/PRIVACY.md
```

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

連絡先（氏名 / 電話番号 / メール）と上の審査メモは 3 バージョンとも ASC に入力済み。

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

ロケールは `en` と `ja` の 2 本。**3 つのバージョンレコードすべてにアップロード済み**
（iOS に iPhone / iPad / Apple Watch、macOS に Desktop、visionOS に Vision Pro）。

差し替えるときは `asc screenshots upload --version-id <ID> --path ... --device-type ...`。

---

## 8. 提出

**公開されたのは 1.1.0 から**。1.0.0 は 3 プラットフォームとも提出まで行ったが
（build 33 / Xcode Cloud run #33）、公開前に App Schema 適合（#138 / #139）を入れたかったので
**1.1.0 に差し替えた**。1.0.0 時点の state は iOS / visionOS が `PENDING_APPLE_RELEASE`
（承認済み・OS 公開待ち）、macOS が `WAITING_FOR_REVIEW`。
経緯: [docs/devlog/2026-09-12-release-1.1.0.md](devlog/2026-09-12-release-1.1.0.md)

提出時に**公開 API から触れず Web UI でしか答えられない項目が 2 つ**あるのは 1.0.0 と同じで、
どちらも「答えるまで提出が通らない」形で出る:

| 項目 | 出方 |
|---|---|
| App プライバシー（データ使用）の**公開** | `You must have published answers to your app's data usages` |
| visionOS の `hasHighMotionLabel`（モーション申告） | `You must provide a value for the attribute 'hasHighMotionLabel'` |

提出の状態は `asc review submissions list --app 6788623037` / `asc status --app 6788623037` で読める。
経緯: [docs/devlog/2026-09-11-app-store-submission.md](devlog/2026-09-11-app-store-submission.md)
