"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { SupportCard } from "@/components/support/SupportCard";
import { Actions, Banner, Button, Chip, Note, Panel, ScreenHead } from "@/components/ui";
import { previousStep, nextStep, stepIndex, stepNumber } from "@/lib/onboarding/steps";
import { contentFor } from "@/lib/onboarding/supportTriggers";
import type { ChipTone } from "./confidence";
import { ExtractedFieldRow } from "./ExtractedFieldRow";
import {
  ExtractionOutcome,
  LOW_CONFIDENCE_TRIGGER_COUNT,
  attentionFieldCount,
  confidentFieldCount,
  prefilledValue,
  type IdExtraction,
} from "./idExtraction";
import "./documents.css";

const SCHEDULE_HREF = nextStep("confirm")?.href ?? "/onboarding/schedule";
const DOCUMENT_HREF = previousStep("confirm")?.href ?? "/onboarding/document";

/** Retaking sends the user back with the failure acknowledged, so the step explains itself. */
const RETAKE_HREF = `${DOCUMENT_HREF}?ocr=failed`;

interface OutcomeCopy {
  title: string;
  /** Sub-heading under the title. */
  lede: string;
  /** Eyebrow on the panel header. */
  panelHead: string;
}

/**
 * Per-outcome copy. Written for someone who is stressed and may have just failed at
 * something, so the failure variant leads with the alternative rather than the problem.
 */
const OUTCOME_COPY: Record<ExtractionOutcome, OutcomeCopy> = {
  [ExtractionOutcome.Read]: {
    title: "Check what we read",
    lede: "We filled in what we could. Two lines need your eyes — nothing is saved until you confirm.",
    panelHead: "Read from your ID",
  },
  [ExtractionOutcome.Failed]: {
    title: "Type your details instead",
    lede: "The photo didn't come through clearly enough to read. This is the same information, by hand.",
    panelHead: "Manual entry",
  },
  [ExtractionOutcome.Skipped]: {
    title: "Type your details instead",
    lede: "No photo needed. This is the same information, by hand — about a minute, and nothing is saved until you confirm.",
    panelHead: "Manual entry",
  },
};

/**
 * Step 04 — confirm the extracted details.
 *
 * Every field is rendered for confirmation, including the ones that came back badly and
 * the ones that did not come back at all. What confidence buys the user is presentation,
 * never a silent decision: a weak reading is flagged in words, and a reading below the
 * pre-fill threshold is dropped rather than shown, so nothing on this screen is a guess
 * dressed as data.
 *
 * @param extraction - the fields to confirm and how the user got here.
 */
export function ConfirmDetailsScreen({ extraction }: { extraction: IdExtraction }) {
  const router = useRouter();
  const { outcome, fields } = extraction;
  const wasRead = outcome === ExtractionOutcome.Read;

  const [values, setValues] = useState<Record<string, string>>(() =>
    Object.fromEntries(fields.map((field) => [field.id, wasRead ? prefilledValue(field) : ""])),
  );
  const [supportDismissed, setSupportDismissed] = useState(false);

  const copy = OUTCOME_COPY[outcome];
  const confident = confidentFieldCount(fields);
  const summary: { tone: ChipTone; label: string } = wasRead
    ? { tone: "ok", label: `${confident} of ${fields.length} confident` }
    : { tone: "missing", label: outcome === ExtractionOutcome.Failed ? "nothing read" : "typed by you" };

  // Trigger condition per docs/ux-decisions.md: two or more fields below the check-this
  // threshold. A clean read fires nothing, and neither does a manual-entry form.
  const supportContent = contentFor("low-confidence", "confirm");
  const showSupport =
    wasRead &&
    attentionFieldCount(fields) >= LOW_CONFIDENCE_TRIGGER_COUNT &&
    !supportDismissed &&
    supportContent !== null;

  function handleConfirm(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    // No persistence layer yet. The confirmed values are what the save call will take.
    router.push(SCHEDULE_HREF);
  }

  return (
    <div className="screen">
      <ScreenHead step={stepNumber(stepIndex("confirm"))} title={copy.title}>
        {copy.lede}
      </ScreenHead>

      {outcome === ExtractionOutcome.Failed && (
        <Banner
          actions={
            <Button variant="ghost" onClick={() => router.push(RETAKE_HREF)}>
              Retake photo
            </Button>
          }
        >
          <strong>We couldn&rsquo;t read that photo.</strong> Glare on the laminate, most likely. Type your details
          below instead &mdash; it takes about a minute &mdash; or try a new photo in better light.
        </Banner>
      )}

      <form onSubmit={handleConfirm}>
        <Panel title={copy.panelHead} aside={<Chip tone={summary.tone}>{summary.label}</Chip>}>
          <div className="fields">
            {fields.map((field) => (
              <ExtractedFieldRow
                key={field.id}
                field={field}
                value={values[field.id] ?? ""}
                onChange={(next) => setValues((current) => ({ ...current, [field.id]: next }))}
                showConfidence={wasRead}
              />
            ))}
          </div>

          <Note>
            When you confirm, we save these five lines and delete the photo. You&rsquo;ll get a receipt for the
            deletion.
          </Note>
        </Panel>

        {showSupport && (
          <div className="support-slot">
            <SupportCard
              trigger="low-confidence"
              content={supportContent}
              onDismiss={() => setSupportDismissed(true)}
            />
          </div>
        )}

        <Actions>
          <Button type="submit" withArrow>
            Confirm and continue
          </Button>
          <Button variant="quiet" onClick={() => router.push(DOCUMENT_HREF)}>
            Start over with a new photo
          </Button>
        </Actions>
      </form>
    </div>
  );
}
