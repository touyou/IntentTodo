# Interview

Question sets for the four rounds. Pick two or three per turn, in the person's own vocabulary. Never send the whole list.

## Round 1 — find the actions

The goal is *repeated* things, stated as something a person does, not as a feature.

Greenfield:

- What does someone open this app to do — the thing they do again tomorrow?
- Walk me through a typical day of using it. What happens first?
- If they could only do three things in the app, which three?
- Is there anything they do so often it is annoying to open the app for?
- Is anything time- or place-triggered ("every morning", "when I get home")? Those are automation candidates, which means Shortcuts.

Retrofit — lead with the `--gap` output instead of a blank question:

- Here is what the app already exposes: … Does that list match what people actually do most?
- These action methods have no intent reaching them: … Which of these is a real thing a person does, and which is plumbing?
- Which action gets the most support questions or complaints? Frequency is often hiding there.
- Is there a screen people go to *just* to press one button? That button is the action.

When an answer names a screen or a feature, reflect it back as a verb and confirm. Keep going until each sentence has the shape **"*\<who\>* can *\<verb\>* *\<noun\>*"**. Rows with no verb are screens; strike them.

## Round 2 — verbs and nouns

### Does this action need an entity?

- Does the person say "add a todo" or "complete **this** todo"? Referring to an existing thing means an entity.
- If Siri asked "which one?", what would someone say to pick it out — a name, a date, something else?

### The identity question (the expensive one)

`id` has to be stable across relaunch, reinstall and sync, because shortcuts people build keep a reference to it (`app-intents-entities-and-search`).

- Does this thing have an identifier that survives the app being reinstalled and the data syncing to another device?
- Can two of them have the same name? What happens if someone renames one?
- Can it be deleted while a shortcut still refers to it? (There has to be an answer; "crash" is the default one.)

### One action or several?

- Are these two things the same act with a different value ("show work todos" / "show home todos"), or genuinely different acts? Same act = one intent with a parameter.
- Should this ever ask the person something before it runs — confirm, or pick from a few options?
  - If yes: it needs a non-asking twin for buttons and widgets, which cannot present a question (`app-intents-parameters-and-prompts`).
- Is this a flip ("toggle") or a set ("mark as done")? Control Center toggles need the set form.
- Is it undoable? Would someone expect to undo it?

### Bulk and scale

- Would anyone want to do this to several at once? (One intent taking an array beats a second intent.)
- How many of these does a heavy user have — dozens, thousands? Scale changes the query shape (`app-intents-entities-and-search`).

## Round 3 — surfaces

Ask per action, cheapest surface first, and stop at the first no.

- How many times a day does someone do this? (Under "a few times a week" → no surface.)
- Where are they when they do it — in the app, on the home screen, on a watch, in the car?
- Does anything about it need to be *visible* between uses, or only done? Visible = widget/complication; done = control or App Shortcut.
- If it fails — no network, item deleted, permission missing — how should the person find out? What if the place it ran cannot show a message?
- What is the one number or line worth showing at rest?
- Does someone need to see the result immediately, or is silence fine?

If the answer to "how would they know it failed" is a shrug, the honest options are: add a notification, or do not put the action there. Both are fine; leaving it undecided is not.

## Round 4 — names and copy

- What would someone call this out loud, to a person? That is the title, near enough.
- What is the shortest form that still says which app is doing it? (Phrases must contain the app name — `app-intents-localization`.)
- What should Siri say back in one sentence after it works? What if nothing changed because it was already in that state?
- Which single glyph stands for this action? (`systemImageName` for App Shortcuts and controls.)
- Are there two names for the same thing in your domain (list/project, tag/label)? Both belong in the phrase variations; pick one for the code.

Naming conventions and the phrase rules are not decided here — they are in [actions-and-intents](../../app-intents-centric-design/references/actions-and-intents.md) and `app-intents-localization`. This round collects the words; those files say what shape they take.

## Questions not to ask

| Do not ask | Ask instead |
|---|---|
| "Should this be `.foreground` or `.background`?" | "Should the app open when this runs?" |
| "Do you want an `EntityPropertyQuery`?" | "Would someone want to find these by date, or by something other than name?" |
| "Which schema domain fits?" | "If you had to put this app in the same box as Reminders, Notes, Mail or Photos — does any of those actually describe it?" (No is a common and correct answer.) |
| "How should the parameter summary read?" | nothing — this is a consequence, not a decision |
| "Do you want Apple Intelligence support?" | "Is there anything someone would ask for in words, rather than tap?" |
