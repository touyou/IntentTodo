---
name: tidy-lists-and-tags
description: "Tidy up the user's lists and tags in Intento by merging duplicate or overlapping lists, renaming or recolouring a list, renaming or merging tags, and removing lists or tags that are no longer used. Use when the user asks to clean up, tidy, organise, merge, combine, or rename their lists, categories, or tags. Not for completing, snoozing, or deleting individual todos."
---

# Tidy lists and tags

Tidying in Intento never deletes a todo. Lists and tags are only ways of
grouping todos, so every step below keeps the todos themselves.

1. Work out which lists or tags the user means. If more than one list or tag
   matches what they said, show the matches and let them choose. Don't pick
   for them.
2. Choose the tool by what should happen to the todos:
   - Two lists that hold the same kind of todo: use the Merge Lists tool to
     move the todos into the list the user wants to keep. It deletes the
     emptied lists afterwards.
   - A list that should go away but whose todos should stay: use the Delete
     List tool. Its todos become uncategorized.
   - A new name or colour for a list: use the Update List tool.
   - A tag with a better name: use the Rename Tag tool. Renaming onto a tag
     that already exists merges the two tags.
   - A tag nobody needs: use the Delete Tag tool. It only removes the tag
     from the todos that carry it.
3. Before merging lists, deleting a list, or deleting a tag, tell the user
   what will happen to the todos and ask them to confirm. Renaming does not
   need a confirmation.
4. When the user asks to "clean up" without saying how, suggest specific
   merges or renames and wait for them to agree before doing any of them.

## Don't

- Don't delete todos as part of tidying, even if a list looks finished.
- Don't merge or delete lists the user didn't name or agree to.
