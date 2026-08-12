import { ConfidenceState, confidenceState, isPrefillable } from "./confidence";

/**
 * The extraction result the confirm screen renders, plus the fixture standing in for a
 * real OCR call.
 *
 * There is no extraction endpoint yet. `loadIdExtraction` is the seam: when the Rails
 * side exists, its body becomes a fetch and everything below the seam — the shapes, the
 * thresholds, the screen — is unchanged.
 */

/** Fields read off a government ID. Values match the mockup's `data-f` hooks. */
export enum IdFieldId {
  Name = "name",
  Dob = "dob",
  Street = "street",
  City = "city",
  IdNumber = "idnum",
}

/** What the extractor produced for one field. */
export interface ExtractedField {
  id: IdFieldId;
  /** Visible label. Also the accessible name of the input. */
  label: string;
  /**
   * Raw text the extractor produced, or null when it produced nothing.
   *
   * A non-null value is *not* a promise that it will be shown: a value whose confidence
   * falls below the pre-fill threshold is discarded rather than rendered.
   */
  value: string | null;
  /** Field-level confidence on the 0..1 scale, or null when nothing was read. */
  confidence: number | null;
  /** Placeholder for when the field is left blank. */
  placeholder?: string;
  /** Plain-language explanation of why this field needs the user's attention. */
  note?: string;
  /** A more likely reading the extractor offers for a low-confidence field. */
  suggestion?: string;
}

/** Which path the user arrived on the confirm screen by. */
export enum ExtractionOutcome {
  /** The photo was read. Fields are pre-filled and scored. */
  Read = "read",
  /** The photo could not be read. Fields are blank and the failure is explained. */
  Failed = "failed",
  /** The user chose to type instead. Fields are blank and nothing failed. */
  Skipped = "skipped",
}

export interface IdExtraction {
  outcome: ExtractionOutcome;
  fields: readonly ExtractedField[];
}

/**
 * A successful read of the sample ID.
 *
 * The values are deliberately imperfect, because the interesting behaviour is what
 * happens to the imperfect ones:
 *
 * - `street` came back garbled at 0.61 — above the pre-fill threshold, so it is shown,
 *   but below `checkThis`, so it is flagged.
 * - `idnum` came back at 0.22. The extractor *did* return characters; we throw them away
 *   rather than present a guess as data.
 */
export const SAMPLE_ID_EXTRACTION: readonly ExtractedField[] = [
  {
    id: IdFieldId.Name,
    label: "Full name",
    value: "Marisol A. Reyes",
    confidence: 0.98,
  },
  {
    id: IdFieldId.Dob,
    label: "Date of birth",
    value: "1991-03-14",
    confidence: 0.96,
  },
  {
    id: IdFieldId.Street,
    label: "Street address",
    value: "142O W Fultcn St, Apt 3B",
    confidence: 0.61,
    note: "The print was blurry here.",
    suggestion: "1420 W Fulton St",
  },
  {
    id: IdFieldId.City,
    label: "City, state, ZIP",
    value: "Chicago, IL 60607",
    confidence: 0.94,
  },
  {
    id: IdFieldId.IdNumber,
    label: "ID number",
    // Returned by the extractor and then discarded: 0.22 is below the pre-fill
    // threshold, so this string never reaches the form.
    value: "D4?1-88O2-9I74",
    confidence: 0.22,
    placeholder: "Type it from your card",
    note: "We left this blank rather than guess. It's the number under your photo.",
  },
];

/** The same five fields with nothing read — the manual-entry form. */
const BLANK_ID_FIELDS: readonly ExtractedField[] = SAMPLE_ID_EXTRACTION.map((field) => ({
  id: field.id,
  label: field.label,
  value: null,
  confidence: null,
  placeholder: "Type it here",
}));

/**
 * Resolves the extraction to render.
 *
 * This is the only place the confirm screen touches "the OCR service". Replacing the
 * fixture with a real call means changing this function body and nothing else.
 *
 * @param outcome - which path the user arrived by.
 * @returns the fields to confirm, in display order.
 */
export function loadIdExtraction(outcome: ExtractionOutcome): IdExtraction {
  return {
    outcome,
    fields: outcome === ExtractionOutcome.Read ? SAMPLE_ID_EXTRACTION : BLANK_ID_FIELDS,
  };
}

/**
 * The value to pre-fill into the form for a field.
 *
 * @param field - the extracted field.
 * @returns the extracted text, or an empty string when it is missing or too weak to
 *   trust. Never a below-threshold guess.
 */
export function prefilledValue(field: ExtractedField): string {
  return field.value !== null && isPrefillable(field.confidence) ? field.value : "";
}

/** How many fields were read cleanly, for the panel's summary chip. */
export function confidentFieldCount(fields: readonly ExtractedField[]): number {
  return fields.filter((field) => confidenceState(field.confidence) === ConfidenceState.Read).length;
}

/**
 * How many fields the user has to look at — flagged or blank.
 *
 * Drives the `low-confidence` supportive-content trigger, which fires at two or more.
 */
export function attentionFieldCount(fields: readonly ExtractedField[]): number {
  return fields.filter((field) => confidenceState(field.confidence) !== ConfidenceState.Read).length;
}

/** Fields at or above which the `low-confidence` support trigger becomes eligible. */
export const LOW_CONFIDENCE_TRIGGER_COUNT = 2;
