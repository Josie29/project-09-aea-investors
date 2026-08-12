"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Actions, Button, Chip, Note, Panel, ScreenHead } from "@/components/ui";
import { nextStep } from "@/lib/onboarding/steps";
import "./consent.css";

/**
 * Step 01 — consent.
 *
 * Nothing in the flow is reachable without passing through here: the brief requires
 * explicit, logged consent before any document is uploaded or processed, so the forward
 * button is disabled until the box is ticked rather than merely warning afterwards.
 */
export default function ConsentPage() {
  const router = useRouter();
  const [agreed, setAgreed] = useState(false);

  const forward = nextStep("consent");

  function handleStart() {
    if (!agreed || !forward) return;

    // Seam: the consent record belongs in the backend audit log. Until that endpoint
    // exists it is stamped locally so the timestamp is real and inspectable, and the
    // swap is one function body.
    recordConsent();
    router.push(forward.href);
  }

  return (
    <div className="screen">
      <ScreenHead step="01" title="Before we start, here's what we collect">
        {
          "Nothing is uploaded or processed until you agree below. You can withdraw at any point, and we'll delete what we have."
        }
      </ScreenHead>

      <Panel title="What we ask for and why" aside={<Chip tone="info">HIPAA</Chip>}>
        <ul className="consent-list">
          <li>
            <span className="mark" aria-hidden="true">
              01
            </span>
            <span>
              <strong>A few questions about what brings you in.</strong>{" "}
              <span className="why">So your first appointment is with the right clinician.</span>
            </span>
          </li>
          <li>
            <span className="mark" aria-hidden="true">
              02
            </span>
            <span>
              <strong>A photo of your ID.</strong>{" "}
              <span className="why">
                {
                  "To fill in your name, date of birth, and address so you don't have to type them. The photo is deleted the moment you confirm the fields — we keep the text, not the image."
                }
              </span>
            </span>
          </li>
          <li>
            <span className="mark" aria-hidden="true">
              03
            </span>
            <span>
              <strong>Your appointment preferences.</strong>{" "}
              <span className="why">To hold a slot with a clinician who has availability.</span>
            </span>
          </li>
        </ul>

        <Note>
          {
            "Your answers stay inside this clinic's systems. Your ID photo is never sent to an outside AI service."
          }
        </Note>

        <label className="checkrow">
          <input
            type="checkbox"
            id="consent-box"
            checked={agreed}
            onChange={(event) => setAgreed(event.target.checked)}
          />
          <span>
            {"I understand what's collected and agree to Northline processing it for my intake."}{" "}
            <span className="why">
              Consent is recorded with a timestamp and can be withdrawn from the last screen.
            </span>
          </span>
        </label>
      </Panel>

      <Actions>
        <Button
          onClick={handleStart}
          disabled={!agreed}
          withArrow
          // The disabled attribute alone is not a reason a user can read, so the
          // requirement is spelled out rather than left to the greyed-out styling.
          aria-describedby={agreed ? undefined : "consent-gate-hint"}
        >
          Start intake
        </Button>
        <Button variant="quiet">Read the full privacy notice</Button>
      </Actions>

      {!agreed && (
        <p className="note" id="consent-gate-hint">
          <span className="mark" aria-hidden="true">
            →
          </span>
          <span>Tick the box above to start. Nothing is collected before you do.</span>
        </p>
      )}
    </div>
  );
}

/** sessionStorage key holding the ISO timestamp of the consent tick. */
const CONSENT_RECORD_KEY = "northline.consent.grantedAt";

/** Records the consent timestamp for this session. */
function recordConsent(): void {
  try {
    window.sessionStorage.setItem(CONSENT_RECORD_KEY, new Date().toISOString());
  } catch {
    // Private-browsing modes can refuse storage. Consent was still given in the UI,
    // and blocking the user on a storage quirk would be worse than the missing stamp.
  }
}
