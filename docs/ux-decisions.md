# UX Decisions

Resolves the three open questions left by the V0 UI mockup. Stack decisions live in
[tech-stack.md](./tech-stack.md).

## 1. Show confidence scores to the user — yes

Per-field OCR confidence is surfaced as the mockup shows it: a chip pairing plain
language with the number (`read · 0.98`, `check this · 0.61`, `not found`).

**Why:** the number costs nothing to render — OCR returns it anyway — and pairing it
with words means status is never conveyed by color alone, which is an accessibility
requirement in the brief. It also makes the "never fabricate a field" guarantee legible:
a user can see the difference between *confidently read* and *we guessed*.

**Not free, though:** Tesseract reports confidence per word, not per field. A field-level
score has to be aggregated from the words composing it — use the **minimum** word
confidence in the field, since one garbled character is what makes a field wrong. That
aggregation is also what drives the flagging threshold, so it is needed regardless of
whether the number is displayed.

**Threshold:** `< 0.80` renders as `check this` with the coral attention border. No
extraction below `0.40` is pre-filled at all — the field stays blank and reads
`not found`, never a low-confidence guess presented as data.

## 2. Assessment summary confirmation — inline, not a seventh screen

The structured assessment stays in the step 02 sidebar. Each row becomes editable in
place, and advancing out of step 02 requires an explicit "This looks right" acknowledgement.

**Why:** the summary is LLM-generated, so it needs the same confirm-before-save treatment
the OCR fields get — the brief's bar is no hallucinated commitment, and an unreviewed
machine summary going to a clinician is exactly that failure. But the brief requires the
*confirmation*, not a separate screen. Six steps is already a lot for an anxious user, and
a seventh screen buys a route and a layout for a guarantee the sidebar can carry. The
mockup already promises this in copy — "you'll see this whole summary before anything is
sent to a clinician, and you can change any line" — so this makes the existing promise
literal rather than adding surface.

## 3. Supportive content on a long pause — pause plus evidence, never a bare timer

A pause alone never fires a card. The dwell trigger requires **a long pause *and* evidence
the user is still engaged and stuck** — specifically, the composer is focused with a
non-empty draft, or the tab regained visibility after being hidden. A pause with no
interaction and no draft fires nothing.

**Why:** a card that appears because someone got up for water is patronizing, and the
brief grades the negative case too — content is never shown when no trigger condition is
met. Requiring evidence of engagement keeps "long pause" as a real trigger (the brief
names it) while cutting the false-positive case that makes it feel surveillant.

**Governing rules for all triggers:**
- At most one supportive card **visible at a time**. (Revised during implementation from
  "one per step": the assessment step can run for several minutes, and refusing to
  acknowledge a genuine later signal — a long stall after an earlier card was dismissed —
  is worse than showing a second, different card. The no-repeat and dismissal rules below
  are what actually prevent nagging.)
- The same card never fires twice in a session.
- Every card is dismissible, and dismissal suppresses that trigger for the rest of the session.
- Triggers are a declarative table (condition → content), so the "never fires without a
  trigger" acceptance criterion is testable as a unit, not as an end-to-end.

### Trigger table

| Trigger | Condition | Fires on |
|---|---|---|
| `express-distress` | Distress intent detected in a user turn | Step 02 |
| `upload-failed` | Upload rejected or OCR returned nothing usable | Steps 03, 04 |
| `low-confidence` | Two or more fields below the check-this threshold | Step 04 |
| `dwell` | Long pause **and** focused composer with a non-empty draft, or tab re-shown | Steps 02, 04 |
| `no-slots` | User rejects the offered slots | Step 05 |
