"use client";

import { Chip } from "@/components/ui";
import { ConfidenceState, confidenceChip, confidenceState } from "./confidence";
import type { ExtractedField } from "./idExtraction";

/**
 * One extracted field, shown for confirmation before anything is saved.
 *
 * The confidence state is expressed three ways at once — the input's border, the chip's
 * words, and (where the extractor can explain itself) a hint underneath. A user who
 * cannot see the coral border still reads `check this · 0.61`, and the chip and hint are
 * wired to the input through `aria-describedby` so a screen reader announces them with
 * the field rather than after it.
 */
export function ExtractedFieldRow({
  field,
  value,
  onChange,
  showConfidence,
}: {
  field: ExtractedField;
  /** Current form value. Owned by the parent so the whole set can be submitted. */
  value: string;
  onChange: (value: string) => void;
  /**
   * Whether to render the confidence chip and hint. False on the manual-entry paths,
   * where there is no reading to report and a chip would be noise.
   */
  showConfidence: boolean;
}) {
  const state = showConfidence ? confidenceState(field.confidence) : ConfidenceState.NotFound;
  const chip = confidenceChip(field.confidence);

  const inputId = `f-${field.id}`;
  const statusId = `${inputId}-status`;
  const hintId = `${inputId}-hint`;

  const hasHint = showConfidence && field.note !== undefined;
  const describedBy = [showConfidence ? statusId : null, hasHint ? hintId : null]
    .filter((id): id is string => id !== null)
    .join(" ");

  const stateClass =
    state === ConfidenceState.CheckThis ? " attention" : state === ConfidenceState.NotFound ? " blank" : "";

  return (
    <div className={`field${stateClass}`} data-f={field.id}>
      <label htmlFor={inputId}>{field.label}</label>

      <input
        id={inputId}
        type="text"
        value={value}
        placeholder={field.placeholder}
        onChange={(event) => onChange(event.target.value)}
        aria-describedby={describedBy === "" ? undefined : describedBy}
      />

      {showConfidence && (
        <span className="status" id={statusId}>
          <Chip tone={chip.tone}>{chip.label}</Chip>
        </span>
      )}

      {hasHint && (
        <p className="hint" id={hintId}>
          {field.suggestion === undefined ? (
            field.note
          ) : (
            <>
              {field.note} Is that <strong>{field.suggestion}</strong>?
            </>
          )}
        </p>
      )}
    </div>
  );
}
