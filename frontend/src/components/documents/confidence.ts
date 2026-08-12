/**
 * Field-level confidence policy for document extraction.
 *
 * Both thresholds live here and nowhere else. They are product decisions recorded in
 * docs/ux-decisions.md, not incidental numbers, and the confirm screen's two graded
 * behaviours — "flag it" and "never pre-fill it" — are both derived from them.
 */

/**
 * Confidence cut-offs, expressed on the 0..1 scale the OCR engine reports.
 *
 * `checkThis` — at or above this a field is presented as read; below it the field is
 * flagged for the user to check, in words as well as colour.
 *
 * `prefill` — below this nothing is pre-filled. A reading this weak is discarded rather
 * than shown, because a wrong value the user has to spot is worse than a blank one they
 * are asked to fill.
 */
export const CONFIDENCE_THRESHOLDS = {
  checkThis: 0.8,
  prefill: 0.4,
} as const;

/** How a single extracted field is presented to the user. */
export enum ConfidenceState {
  /** Read cleanly. Pre-filled, chip reads `read`. */
  Read = "read",
  /** Read, but not well enough to trust. Pre-filled, flagged, chip reads `check this`. */
  CheckThis = "check-this",
  /** Nothing usable. Left blank, chip reads `not found`. */
  NotFound = "not-found",
}

/** Chip tones available in the shared stylesheet. */
export type ChipTone = "ok" | "check" | "missing";

/** A rendered confidence chip: plain language paired with the number. */
export interface ConfidenceChip {
  tone: ChipTone;
  label: string;
}

/** Shown when a field was not read, or was read too poorly to keep. */
export const NOT_FOUND_LABEL = "not found";

/**
 * Classifies a field-level confidence score.
 *
 * @param confidence - score on the 0..1 scale, or null when the extractor returned
 *   nothing at all for the field.
 * @returns how the field should be presented.
 */
export function confidenceState(confidence: number | null): ConfidenceState {
  if (confidence === null || !Number.isFinite(confidence)) {
    return ConfidenceState.NotFound;
  }
  if (confidence < CONFIDENCE_THRESHOLDS.prefill) {
    return ConfidenceState.NotFound;
  }
  if (confidence < CONFIDENCE_THRESHOLDS.checkThis) {
    return ConfidenceState.CheckThis;
  }
  return ConfidenceState.Read;
}

/**
 * Whether an extracted value is trustworthy enough to put in front of the user.
 *
 * @param confidence - score on the 0..1 scale, or null.
 * @returns true when the value may be pre-filled into the form.
 */
export function isPrefillable(confidence: number | null): boolean {
  return confidenceState(confidence) !== ConfidenceState.NotFound;
}

/**
 * Builds the confidence chip for a field.
 *
 * The label always carries words, so status is never conveyed by colour alone — the
 * accessibility bar the brief sets, and the reason the number alone is not enough.
 *
 * @param confidence - score on the 0..1 scale, or null.
 * @returns the chip tone and its full label, e.g. `check this · 0.61`.
 */
export function confidenceChip(confidence: number | null): ConfidenceChip {
  const state = confidenceState(confidence);

  if (confidence === null || state === ConfidenceState.NotFound) {
    return { tone: "missing", label: NOT_FOUND_LABEL };
  }

  // Two decimals matches how the mockup renders scores, and tabular numerals in the
  // chip style keep the column from jittering between fields.
  const score = confidence.toFixed(2);

  // · is the middle dot separating the words from the number.
  return state === ConfidenceState.CheckThis
    ? { tone: "check", label: `check this · ${score}` }
    : { tone: "ok", label: `read · ${score}` };
}
