import { ConfirmDetailsScreen } from "@/components/documents/ConfirmDetailsScreen";
import { CONFIDENCE_THRESHOLDS } from "@/components/documents/confidence";
import {
  ExtractionOutcome,
  IdFieldId,
  SAMPLE_ID_EXTRACTION,
  loadIdExtraction,
} from "@/components/documents/idExtraction";
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

// The screen navigates on confirm and on "start over", so the app router has to exist
// for it to render at all. Nothing here asserts on navigation.
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: vi.fn() }) }));

function field(id: IdFieldId) {
  const match = SAMPLE_ID_EXTRACTION.find((candidate) => candidate.id === id);
  if (!match) throw new Error(`fixture has no field ${id}`);
  return match;
}

describe("confirm details screen", () => {
  // The brief's headline acceptance criterion: every field the extractor touched is put
  // in front of the user before anything is saved. If a field is ever rendered
  // read-only, or dropped because it scored badly, this catches it.
  it("shows every extracted field as an editable, labelled input", () => {
    render(<ConfirmDetailsScreen extraction={loadIdExtraction(ExtractionOutcome.Read)} />);

    for (const extracted of SAMPLE_ID_EXTRACTION) {
      expect(screen.getByLabelText(extracted.label)).toBeInstanceOf(HTMLInputElement);
    }
  });

  // The "never fabricate a field" guarantee. The ID number *was* returned by the
  // extractor, at 0.22 — if the pre-fill threshold is ever removed or lowered, a garbled
  // string appears in the form looking like data the user is expected to accept.
  it("leaves a field below the pre-fill threshold blank rather than showing the guess", () => {
    const idNumber = field(IdFieldId.IdNumber);
    expect(idNumber.value).not.toBeNull();
    expect(idNumber.confidence).toBeLessThan(CONFIDENCE_THRESHOLDS.prefill);

    render(<ConfirmDetailsScreen extraction={loadIdExtraction(ExtractionOutcome.Read)} />);

    const input = screen.getByLabelText(idNumber.label);
    expect(input).toHaveValue("");
    expect(screen.queryByDisplayValue(idNumber.value ?? "")).not.toBeInTheDocument();
    expect(screen.getByText("not found")).toBeInTheDocument();
  });

  // Status conveyed by more than colour is an explicit accessibility requirement. The
  // coral border alone is invisible to a chunk of users; the words are what they read.
  // Removing the chip text would leave the flag colour-only and this fails.
  it("flags a low-confidence field in words, not colour alone", () => {
    const street = field(IdFieldId.Street);
    expect(street.confidence).toBeLessThan(CONFIDENCE_THRESHOLDS.checkThis);
    expect(street.confidence).toBeGreaterThanOrEqual(CONFIDENCE_THRESHOLDS.prefill);

    render(<ConfirmDetailsScreen extraction={loadIdExtraction(ExtractionOutcome.Read)} />);

    const input = screen.getByLabelText(street.label);
    // Pre-filled, because it cleared the pre-fill threshold...
    expect(input).toHaveValue(street.value);
    // ...but announced as needing a check, with the score, alongside the field.
    expect(input).toHaveAccessibleDescription(expect.stringContaining("check this · 0.61"));
  });

  // The failure path must never dead-end. If the banner or the blank form regresses, a
  // user whose photo failed has no way to finish onboarding.
  it("offers manual entry with blank fields when the photo could not be read", () => {
    render(<ConfirmDetailsScreen extraction={loadIdExtraction(ExtractionOutcome.Failed)} />);

    // Curly apostrophe: the screen renders &rsquo;, so a straight quote would not match.
    expect(screen.getByText("We couldn’t read that photo.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Retake photo" })).toBeInTheDocument();

    for (const extracted of SAMPLE_ID_EXTRACTION) {
      expect(screen.getByLabelText(extracted.label)).toHaveValue("");
    }
    // No reading happened, so no confidence is claimed for any field.
    expect(screen.queryByText(/^read · /)).not.toBeInTheDocument();
  });

  // Guards the negative half of the supportive-content criterion: the card is tied to a
  // trigger condition, so a screen with nothing wrong must not show one.
  it("shows the low-confidence card only when fields actually need attention", () => {
    const { unmount } = render(<ConfirmDetailsScreen extraction={loadIdExtraction(ExtractionOutcome.Read)} />);
    expect(screen.getByText("trigger: low-confidence")).toBeInTheDocument();
    unmount();

    render(<ConfirmDetailsScreen extraction={loadIdExtraction(ExtractionOutcome.Skipped)} />);
    expect(screen.queryByText("trigger: low-confidence")).not.toBeInTheDocument();
  });
});
