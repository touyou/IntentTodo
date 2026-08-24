# キーワードウォール（スラッシュ区切り）

App Intents 関連で **今（iOS 27 / Xcode 27 時点）使える**キーワードをスラッシュ区切りで並べたテキスト。
スライドに敷き詰める用。**テキストの書き出しのみ**（スライド化・レイアウトは未着手）。

- 出典: [../WWDC_APP_INTENTS_SESSIONS.md](../WWDC_APP_INTENTS_SESSIONS.md)（2022–2026 の API 一覧）/ [01-app-intents-history.md](01-app-intents-history.md) / [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)
- 非推奨・リネーム済みは §14 に隔離（「使えるやつ」の壁に混ぜない）
- ⚠️ 付きは一次ソース未確認。壁に出すなら発表前に SDK で確認する

---

## 1. 骨格（動詞・名詞・フレーズ）

```
AppIntent / AppEntity / AppEnum / EntityQuery / AppShortcutsProvider / AppShortcut / AppIntentsPackage / perform() / @Parameter / @Property / @Dependency / AppDependencyManager / IntentResult / .result() / .result(value:) / .result(dialog:) / .result(view:) / IntentDialog / IntentDialog(full:supporting:) / DisplayRepresentation / TypeDisplayRepresentation / DisplayRepresentation.Components / synonyms / IntentDescription / resultValueName / findIntentDescription / assistantOnly / isDiscoverable / ParameterSummary / Summary / When / Switch / Case / Default / caseDisplayRepresentations / Metadata.appintents / AppShortcuts.xcstrings / updateAppShortcutParameters() / \(.applicationName) / CustomLocalizedStringResourceConvertible / LocalizedStringResource
```

## 2. Query（探す・列挙する）

```
EntityQuery / EntityStringQuery / EntityPropertyQuery / EnumerableEntityQuery / IndexedEntityQuery / IntentValueQuery / DynamicOptionsProvider / defaultQuery / entities(for:) / entities(matching:) / suggestedEntities() / allEntities() / values(for:) / QueryProperties / SortingOptions / SortableBy(keyPath:) / EqualToComparator / ContainsComparator / LessThanComparator / GreaterThanComparator / Predicate<T> / Sort<T> / ComparatorMode / IntentParameterDependency / IntentProjection / Magic Variables / Find & Filter
```

## 3. 戻り値のかたち

```
ReturnsValue<T> / ProvidesDialog / ShowsSnippetView / OpensIntent / EntityCollection<T> / @UnionValue / TransientAppEntity / IntentFile
```

## 4. Entity を厚くする

```
IndexedEntity / SyncableEntity / SyncableEntityIdentifier<Local, Stable> / TransientAppEntity / @Property(indexingKey:) / @ComputedProperty / @DeferredProperty / OwnershipProvidingEntity / EntityOwnership / .shared / .public / .unknown / EntityIdentifier / EntityIdentifier(for:) / EntityIdentifier(for:identifier:) / URLRepresentableEntity / FileEntity / FileEntityIdentifier / AppEntity.ValueRepresentation / IntentValueRepresentation(exporting:) / IntentValueRepresentation(exporting:importing:) / IntentPerson / PlaceDescriptor / Transferable / ProxyRepresentation / DataRepresentation / FileRepresentation / Duration / PersonNameComponents / Calendar.RecurrenceRule / AudioSearch / StringSearchCriteria / searchScopes
```

## 5. 対話（聞き返す・確認する・選ばせる）

```
requestValue(_:) / needsValueError / requestDisambiguation(among:dialog:) / requestConfirmation(for:dialog:) / requestConfirmation(actionName:snippetIntent:) / requestConfirmation(_:confirmLabel:cancelLabel:) / requestChoice(between:dialog:) / requestChoice(between:dialog:view:) / IntentChoiceOption / .default / .destructive / .cancel / continueInForeground(alwaysConfirm:)
```

## 6. 実行制御（どこで・どれだけ走るか）

```
supportedModes / IntentModes / .background / .foreground(.immediate) / .foreground(.dynamic) / .foreground(.deferred) / allowedExecutionTargets / IntentExecutionTargets / .main / .appIntentsExtension / .widgetKitExtension / LongRunningIntent / performBackgroundTask / CancellableIntent / IntentCancellationReason / Task.checkCancellation() / ProgressReportingIntent / progress.totalUnitCount / progress.completedUnitCount / UndoableIntent / undoManager.registerUndo(withTarget:handler:) / systemContext.currentMode / systemContext.canContinueInForeground / isVoiceOnly
```

## 7. 役割つき Intent（プロトコル・スキーマ）

```
OpenIntent / DeleteIntent / SystemIntent / SetValueIntent / SnippetIntent / SnippetIntent.reload() / TargetContentProvidingIntent / LiveActivityIntent / AudioPlaybackIntent / WidgetConfigurationIntent / ControlConfigurationIntent / SetFocusFilterIntent / OpenURLIntent / URLRepresentableIntent / ShowInAppSearchResultsIntent / UISceneAppIntent / AppIntentSceneDelegate / PredictableIntent / RelevantIntent / CustomIntentMigratedAppIntent
```

## 8. App Schemas（共有語彙）

```
@AppIntent(schema:) / @AppEntity(schema:) / @AppEnum(schema:) / AppSchema / AppSchemaDomain / .system.open / .system.searchInApp / .reminders.list / .reminders.reminder / .reminders.listType / .calendar.attendee / .visualIntelligence.semanticContentSearch / Xcode Fix-It でスキーマ不足を補完
```

⚠️ ドメイン名を「12 個」まとめて壁に出すなら SDK で綴りを確認する（iOS 18 期の資料に出る Photos / Mail / Books / Camera / Spreadsheets 等は名称が SDK 上のシンボルと一致しない可能性がある）。

## 9. Spotlight / donation

```
CSSearchableIndex / 名前付き CSSearchableIndex / CSSearchableItem / CSSearchableItemAttributeSet / attributeSet / indexAppEntities(_:) / associateAppEntity(_:) / relatedAppEntityIdentifier / セマンティック検索 / Semantic Similarity Index / Spotlight Top Hits / IntentDonationManager / donate(_:) / deleteDonations(matching:) / IntentDonationMatchingPredicate
```

## 10. Onscreen / 文脈（いま何を見ているか）

```
NSUserActivity.appEntityIdentifier / NSUserActivity.appEntityIdentifiers / .appEntityIdentifier(_:) / .appEntityIdentifier(forSelectionType:) / .appEntityUIElements / AppEntityAnnotatable / UICollectionViewAppIntentsDataSource / appEntityUIElementProvider / UNMutableNotificationContent.appEntityIdentifiers / MusicContent.appEntityIdentifiers / AlarmConfiguration.appEntityIdentifier / RelevantEntities.shared.updateEntities(_:for:) / removeEntities(_:from:) / removeAllEntities(for:) / removeAllEntities() / AppEntityContext / RelevantIntentManager / RelevantContext / IntentValueQuery + SemanticContentDescriptor / SemanticContentDescriptor.labels / pixelBuffer / VisualIntelligence
```

## 11. 出口（Intent を置ける場所）

```
Siri / Siri AI / Shortcuts / Spotlight / ウィジェット / コントロールセンター / ライブアクティビティ / Dynamic Island / Action Button / Apple Pencil Pro スクイーズ / Visual Intelligence / Apple Intelligence / CarPlay / Apple Watch コンプリケーション / オートメーション / Button(intent:) / Toggle(isOn:intent:) / Link / widgetURL(_:) / ShortcutsLink / SiriTipView / onAppIntentExecution(_:perform:) / ControlWidget / ControlWidgetButton / ControlWidgetToggle / StaticControlConfiguration / AppIntentControlConfiguration / ControlValueProvider / AppIntentControlValueProvider / .controlWidgetActionHint(_:) / .controlWidgetStatus(_:) / AppIntentConfiguration / WidgetCenter.shared.reloadAllTimelines() / ControlCenter.shared.reloadAllControls() / ControlCenter.shared.reloadControls(ofKind:) / invalidatableContent() / ContainerRelativeShape
```

## 12. テスト・検証

```
AppIntentsTesting / IntentDefinitions(bundleIdentifier:) / definitions.intents["..."] / makeIntent(...).run() / definitions.entities["..."] / spotlightQuery(_:) / viewAnnotations() / ViewAnnotation / definitions.valueQueries["..."] / 連鎖テスト / UI テストバンドル必須 / App Shortcuts Preview / Xcode Fix-It
```

## 13. 設計ボキャブラリ（日本語・概念系）

```
App Intents 中心設計 / App Intent Driven Development / Action-Centered Design / モデルベース UI デザイン / Entity = 名詞 / Intent = 動詞 / 語彙の共有 / 唯一の実行経路 / ロジックを二重に書かない / 1 アクション 1 Intent / 最小のスクリーンから設計する / 出口は後から増える / 型に嵌める見返り / システムオーケストレーター / 檻ではなく辞書 / Liquid Glass 時代はコンテンツとアクションが残る
```

## 14. ⛔ もう使わない（対比で見せる用・「使えるキーワード」の壁には混ぜない）

```
INIntent / INExtension / Intents.framework / IntentsUI.framework / .intentdefinition / resolve → confirm → handle / IntentsSupported / IntentConfiguration / IntentTimelineProvider / NSUserActivity donation（SiriKit 期の意味） / openAppWhenRun / confirmBeforeRunning / ForegroundContinuableIntent / needsToContinueInForegroundError() / requestToContinueInForeground() / @AssistantIntent / @AssistantEntity / @AssistantEnum / .system.search
```

---

## 全部つなげた 1 本（壁スライド用・現行 API のみ）

```
AppIntent / AppEntity / AppEnum / EntityQuery / AppShortcutsProvider / AppShortcut / AppIntentsPackage / perform() / @Parameter / @Property / @Dependency / AppDependencyManager / IntentResult / .result() / .result(value:) / .result(dialog:) / .result(view:) / IntentDialog / IntentDialog(full:supporting:) / DisplayRepresentation / TypeDisplayRepresentation / DisplayRepresentation.Components / synonyms / IntentDescription / resultValueName / findIntentDescription / assistantOnly / isDiscoverable / ParameterSummary / Summary / When / Switch / Case / Default / caseDisplayRepresentations / Metadata.appintents / AppShortcuts.xcstrings / updateAppShortcutParameters() / EntityStringQuery / EntityPropertyQuery / EnumerableEntityQuery / IndexedEntityQuery / IntentValueQuery / DynamicOptionsProvider / defaultQuery / entities(for:) / entities(matching:) / suggestedEntities() / allEntities() / values(for:) / QueryProperties / SortingOptions / SortableBy(keyPath:) / EqualToComparator / ContainsComparator / LessThanComparator / GreaterThanComparator / Predicate / Sort / ComparatorMode / IntentParameterDependency / IntentProjection / Magic Variables / Find & Filter / ReturnsValue / ProvidesDialog / ShowsSnippetView / OpensIntent / EntityCollection / @UnionValue / TransientAppEntity / IntentFile / IndexedEntity / SyncableEntity / SyncableEntityIdentifier / @Property(indexingKey:) / @ComputedProperty / @DeferredProperty / OwnershipProvidingEntity / EntityOwnership / EntityIdentifier / EntityIdentifier(for:) / URLRepresentableEntity / FileEntity / FileEntityIdentifier / AppEntity.ValueRepresentation / IntentValueRepresentation(exporting:) / IntentValueRepresentation(exporting:importing:) / IntentPerson / PlaceDescriptor / Transferable / ProxyRepresentation / DataRepresentation / FileRepresentation / Duration / PersonNameComponents / Calendar.RecurrenceRule / AudioSearch / StringSearchCriteria / searchScopes / requestValue(_:) / needsValueError / requestDisambiguation(among:dialog:) / requestConfirmation(for:dialog:) / requestConfirmation(actionName:snippetIntent:) / requestConfirmation(_:confirmLabel:cancelLabel:) / requestChoice(between:dialog:) / requestChoice(between:dialog:view:) / IntentChoiceOption / continueInForeground(alwaysConfirm:) / supportedModes / IntentModes / .background / .foreground(.immediate) / .foreground(.dynamic) / .foreground(.deferred) / allowedExecutionTargets / IntentExecutionTargets / .main / .appIntentsExtension / .widgetKitExtension / LongRunningIntent / performBackgroundTask / CancellableIntent / IntentCancellationReason / ProgressReportingIntent / UndoableIntent / undoManager.registerUndo(withTarget:handler:) / systemContext.currentMode / systemContext.canContinueInForeground / isVoiceOnly / OpenIntent / DeleteIntent / SystemIntent / SetValueIntent / SnippetIntent / SnippetIntent.reload() / TargetContentProvidingIntent / LiveActivityIntent / AudioPlaybackIntent / WidgetConfigurationIntent / ControlConfigurationIntent / SetFocusFilterIntent / OpenURLIntent / URLRepresentableIntent / ShowInAppSearchResultsIntent / UISceneAppIntent / AppIntentSceneDelegate / PredictableIntent / RelevantIntent / CustomIntentMigratedAppIntent / @AppIntent(schema:) / @AppEntity(schema:) / @AppEnum(schema:) / AppSchema / AppSchemaDomain / .system.open / .system.searchInApp / .reminders.list / .reminders.reminder / .reminders.listType / .calendar.attendee / .visualIntelligence.semanticContentSearch / CSSearchableIndex / CSSearchableItem / CSSearchableItemAttributeSet / attributeSet / indexAppEntities(_:) / associateAppEntity(_:) / relatedAppEntityIdentifier / Semantic Similarity Index / IntentDonationManager / donate(_:) / deleteDonations(matching:) / IntentDonationMatchingPredicate / NSUserActivity.appEntityIdentifier / NSUserActivity.appEntityIdentifiers / .appEntityIdentifier(_:) / .appEntityIdentifier(forSelectionType:) / .appEntityUIElements / AppEntityAnnotatable / UICollectionViewAppIntentsDataSource / appEntityUIElementProvider / UNMutableNotificationContent.appEntityIdentifiers / MusicContent.appEntityIdentifiers / AlarmConfiguration.appEntityIdentifier / RelevantEntities.shared.updateEntities(_:for:) / removeEntities(_:from:) / removeAllEntities(for:) / AppEntityContext / RelevantIntentManager / RelevantContext / SemanticContentDescriptor / labels / pixelBuffer / VisualIntelligence / Button(intent:) / Toggle(isOn:intent:) / Link / widgetURL(_:) / ShortcutsLink / SiriTipView / onAppIntentExecution(_:perform:) / ControlWidget / ControlWidgetButton / ControlWidgetToggle / StaticControlConfiguration / AppIntentControlConfiguration / ControlValueProvider / AppIntentControlValueProvider / .controlWidgetActionHint(_:) / .controlWidgetStatus(_:) / AppIntentConfiguration / WidgetCenter.shared.reloadAllTimelines() / ControlCenter.shared.reloadAllControls() / ControlCenter.shared.reloadControls(ofKind:) / invalidatableContent() / ContainerRelativeShape / AppIntentsTesting / IntentDefinitions(bundleIdentifier:) / makeIntent(...).run() / spotlightQuery(_:) / viewAnnotations() / ViewAnnotation / App Shortcuts Preview / Xcode Fix-It
```

## 短縮版（読ませる用・40 語）

「壁」は圧が目的だが、実際に読ませたいならこの程度に絞る。

```
AppIntent / AppEntity / AppEnum / EntityQuery / AppShortcutsProvider / @Parameter / @Property / @Dependency / perform() / IntentDialog / DisplayRepresentation / supportedModes / allowedExecutionTargets / requestConfirmation / requestChoice / UndoableIntent / LongRunningIntent / CancellableIntent / SnippetIntent / OpenIntent / DeleteIntent / SetValueIntent / LiveActivityIntent / TargetContentProvidingIntent / WidgetConfigurationIntent / IndexedEntity / SyncableEntity / EntityCollection / TransientAppEntity / @UnionValue / @ComputedProperty / @DeferredProperty / @AppIntent(schema:) / @AppEntity(schema:) / IntentValueQuery / SemanticContentDescriptor / appEntityIdentifier / Button(intent:) / ControlWidget / AppIntentsTesting
```
