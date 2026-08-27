# 開発ログ: SwiftData と Concurrency

`docs/insights/02-swiftdata-concurrency.md` の現在のルールが、どういう経緯で今の形になったかを記録する。

## 2026-04-15: CloudKit 制約表を iOS 26 ドキュメントで再検証

Apple 公式 [Syncing model data across a person's devices / Define a CloudKit compatible schema](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices#Define-a-CloudKit-compatible-schema) に記載の CloudKit 制約表（`@Attribute(.unique)` が enforce されない、リレーションシップが全て optional 必須）が、2026-04-15 時点の iOS 26 ドキュメントでも変わらず維持されていることを確認した。

`@Attribute(.unique)` については実機でも一意制約が破られるケースを経験しており、公式記述と実際の挙動が一致することを確かめた。`#Unique<T>` マクロの CloudKit 互換性について Apple 公式 API リファレンスに直接の記述は無いが、同じ一意性メカニズムに依拠するため同じ制約が及ぶと判断した。

DeleteRule の `.deny` が CloudKit で未サポートである点も、同じ制約表（同じく 2026-04-15 時点のドキュメント）で確認済み。
