# Design gallery

The visual spec of Nap Time: static HTML pages, one per screen state, in style B "Storybook" from the brief's Look. The rules are in craft's `gallery.md`. `craft:build` builds each screen to match its page.

Current stage: 1

Platforms: ios

- `gallery.css`: the visual identity. Pages link only this file.
- `fonts/baloo2-latin.woff2`: Baloo 2 (SIL Open Font License), the latin subset from Google Fonts.
- `pages/<screen>/<state>.html`: one page per screen state.
- The charts pages `charts/week.html`, `charts/day-sheet.html`, and `charts/what-to-try.html` are views. Their one primary action is opening a sleep day: tap its bar or its timeline row. On the day sheet it is "Add a sleep to this day".
- A page shows the whole screen as v1 ends. A ticket builds only the parts of a page that its plan row names.
- Source of the look: the sketches canvas linked from the brief, row B and row "v1 plan".
