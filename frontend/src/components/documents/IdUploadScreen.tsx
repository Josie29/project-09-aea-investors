"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { SupportCard } from "@/components/support/SupportCard";
import { Actions, Banner, Button, Note, Panel, ScreenHead } from "@/components/ui";
import { nextStep, previousStep, stepIndex, stepNumber } from "@/lib/onboarding/steps";
import { contentFor } from "@/lib/onboarding/supportTriggers";
import { Dropzone } from "./Dropzone";
import "./documents.css";

const CONFIRM_HREF = nextStep("document")?.href ?? "/onboarding/confirm";
const BACK_HREF = previousStep("document")?.href ?? "/onboarding/assessment";

/** Confirm screen with the fixture in its unreadable-photo state. */
const CONFIRM_FAILED_HREF = `${CONFIRM_HREF}?ocr=failed`;

/** Confirm screen as a blank form, chosen deliberately rather than after a failure. */
const CONFIRM_MANUAL_HREF = `${CONFIRM_HREF}?entry=manual`;

/**
 * Step 03 — photograph your ID.
 *
 * Typing is offered as a peer action, not a fallback. It sits in the same action row as
 * everything else and is reachable before an upload is ever attempted, because the brief
 * requires that a failed read never dead-ends and the cheapest way to guarantee that is
 * to never make the photo the only door.
 *
 * @param uploadFailed - true when the user came back here from a failed read, which is
 *   the `upload-failed` supportive-content trigger.
 */
export function IdUploadScreen({ uploadFailed = false }: { uploadFailed?: boolean }) {
  const router = useRouter();
  const [rejection, setRejection] = useState<string | null>(null);
  const [supportDismissed, setSupportDismissed] = useState(false);

  // Trigger condition per docs/ux-decisions.md: the upload was rejected, or a previous
  // read returned nothing usable. No other condition shows a card on this step.
  const supportContent = contentFor("upload-failed", "document");
  const showSupport = (uploadFailed || rejection !== null) && !supportDismissed && supportContent !== null;

  return (
    <div className="screen">
      <ScreenHead step={stepNumber(stepIndex("document"))} title="Photograph your ID instead of typing it">
        A driver&rsquo;s licence or state ID. We read your name, date of birth, and address off it, show you what we
        got, and delete the photo once you confirm.
      </ScreenHead>

      {rejection !== null && (
        <Banner
          actions={
            <Button variant="ghost" onClick={() => setRejection(null)}>
              Try another photo
            </Button>
          }
        >
          <strong>We can&rsquo;t use that file.</strong> {rejection}
        </Banner>
      )}

      <Panel>
        {/* No upload endpoint exists yet, so an accepted file moves straight to the
            confirm screen. When the extraction API lands, this is where the POST goes. */}
        <Dropzone onAccepted={() => router.push(CONFIRM_HREF)} onRejected={setRejection} />

        <Note>
          Reading happens on Northline&rsquo;s own servers. Your ID image is not sent to any third-party AI service,
          and it&rsquo;s purged after you confirm the fields.
        </Note>
      </Panel>

      {showSupport && (
        <div className="support-slot">
          <SupportCard trigger="upload-failed" content={supportContent} onDismiss={() => setSupportDismissed(true)} />
        </div>
      )}

      <Actions>
        <Button variant="ghost" onClick={() => router.push(CONFIRM_MANUAL_HREF)}>
          I&rsquo;d rather type my details
        </Button>
        <Button variant="quiet" onClick={() => router.push(BACK_HREF)}>
          Back
        </Button>
      </Actions>

      <aside className="reviewer-switch">
        <span className="tag">reviewer</span>
        <p>
          No extraction service is wired up yet. These jump to the confirm screen with the sample extraction in each
          state, so the failure path is reachable without a bad photo.
        </p>
        <span className="opts">
          <Button variant="quiet" onClick={() => router.push(CONFIRM_HREF)}>
            Successful read
          </Button>
          <Button variant="quiet" onClick={() => router.push(CONFIRM_FAILED_HREF)}>
            Unreadable photo
          </Button>
        </span>
      </aside>
    </div>
  );
}
