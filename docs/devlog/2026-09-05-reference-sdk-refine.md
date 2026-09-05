# 参照資料と beta 6 SDK に基づくスキル・ドキュメント整理

2026-09-05。`docs/references/`、WWDC 書き起こし、Xcode 27 beta 6（27A5252f）の
公開 swiftinterface を照合した。今回は文書の修正であり、アプリのビルド・実機検証は行わなかった。

## 確認した資料

- Xcode の `Contents/version.plist` で build を特定した。
- `docs/references/` の同名 Markdown 20 本は、beta 6 の
  `IDEIntelligenceChat.framework/…/AdditionalDocumentation/` とバイト単位で一致した。
- iOS / macOS / visionOS / watchOS の `AppIntents.swiftinterface` を確認した。
  `AppIntentsTesting` は macOS の公開 interface で `run()` の形を確認した。
- WWDC2026-295 の 17:59–25:07 と関連資料を参照し、型名での実行と Siri 経由の検証を区別した。
- Apple のオンライン文書は本文取得に失敗したため、新しい API 判断の根拠には使用しなかった。

## 修正した不整合

- visionOS の `indexingKey:` 対応が docs には反映され、skills の表と例には反映されていなかった。
  SDK の availability に合わせてガード例まで揃えた。
- `RelevantEntities` の説明が、SDK にある `.nowPlaying` と存在を確認できない `.workout` を混在させていた。
- `IntentSystemContext` の説明に `locale` と `preciseTimestamp` を含め、呼出元識別とは区別した。
- `actions` と `autoShortcuts`、重複 schema と同名型の上書きが診断表で混同されていた。
- UI の説明だけが対話 Intent の AppIntentsTesting 成功を主張していたため、既存のテスト制約と揃えた。
- 「AppIntentsTesting の対象外」を「自動化不可能」と広げていた文を、検証手段の範囲に限定した。
- Spotlight の例が notes / dueDate / 状態を index する一方、更新契機を title 変更だけに限定していた。
  indexed content の変更を基準にし、id だけの digest では既存 entity の編集を検出できないことを明記した。
- Xcode 同梱例の `snippet` / `searchableAttributes` を完成した準拠例として転用しないよう、公開宣言の確認手順をまとめた。

現在の手順: [source-verification](../../skills/app-intents-centric-design/references/source-verification.md)。
SDK 更新時の再検証は既存の #57、呼出面・実機の確認は既存の #30 の範囲とした。

## 文書の検証

- `skill-creator` の `quick_validate.py` で全 9 スキルの検証が通った。
- 変更・追加した 26 文書のローカルファイルリンクを確認し、参照先の欠落はなかった
  （コード内の表記を除外、見出しアンカーは自動検証の対象外）。
- `git diff --check` が通った。アプリコード・プロジェクト設定は変更しなかった。
