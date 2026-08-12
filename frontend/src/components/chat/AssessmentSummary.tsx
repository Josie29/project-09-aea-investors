"use client";

import { Chip } from "@/components/ui";
import type { AssessmentRow } from "./scriptedConversation";
import "./chat.css";

interface AssessmentSummaryProps {
  rows: readonly AssessmentRow[];
  onRowChange: (id: string, value: string) => void;
  acknowledged: boolean;
  onAcknowledgedChange: (acknowledged: boolean) => void;
}

/**
 * What the assistant has understood so far, editable in place.
 *
 * Per docs/ux-decisions.md this sidebar *is* the summary-review step — there is no
 * seventh screen. The summary is machine-written, so it gets the same treatment the OCR
 * fields get: every line is editable, and leaving the step requires the user to say the
 * summary is right. Editing a line withdraws that acknowledgement, because what was
 * confirmed is no longer what is on screen.
 */
export function AssessmentSummary({
  rows,
  onRowChange,
  acknowledged,
  onAcknowledgedChange,
}: AssessmentSummaryProps) {
  const noted = rows.filter((row) => row.value.trim().length > 0).length;

  return (
    <aside className="panel" aria-labelledby="assess-h">
      <header className="panel-head">
        <p className="eyebrow" id="assess-h">
          What I&apos;ve noted
        </p>
        <Chip tone="info">
          {noted} / {rows.length}
          <span className="sr-only"> lines noted</span>
        </Chip>
      </header>

      <div className="panel-body">
        <div className="assess">
          {rows.map((row) => {
            const pending = row.value.trim().length === 0;

            return (
              <div className="row" key={row.id}>
                <label className="k" htmlFor={`assess-${row.id}`}>
                  {row.label}
                </label>
                <input
                  id={`assess-${row.id}`}
                  className={pending ? "v pending" : "v"}
                  type="text"
                  value={row.value}
                  placeholder={row.pendingLabel}
                  onChange={(event) => onRowChange(row.id, event.target.value)}
                />
              </div>
            );
          })}
        </div>

        <p className="assess-foot">
          {
            "You'll see this whole summary before anything is sent to a clinician, and you can change any line."
          }
        </p>

        <label className="ack">
          <input
            type="checkbox"
            checked={acknowledged}
            onChange={(event) => onAcknowledgedChange(event.target.checked)}
          />
          <span>This looks right. Send it to my clinician as written.</span>
        </label>
      </div>
    </aside>
  );
}
