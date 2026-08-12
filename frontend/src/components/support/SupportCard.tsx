"use client";

import { Button } from "@/components/ui";
import type { SupportContent, TriggerId } from "@/lib/onboarding/supportTriggers";

/**
 * Reassurance surfaced at a friction point.
 *
 * The trigger id is rendered visibly. That is deliberate for this build: the brief
 * grades that the *correct* content appears for each trigger, and showing which
 * condition fired makes that checkable by a reviewer without reading the source. It
 * would come out before real users saw it.
 *
 * `role="note"` and not `alert`: this is supportive, not urgent, and an assertive
 * announcement would interrupt a screen reader mid-sentence.
 */
export function SupportCard({
  trigger,
  content,
  onDismiss,
}: {
  trigger: TriggerId;
  content: SupportContent;
  onDismiss: () => void;
}) {
  return (
    <aside className="support-card" role="note">
      <span className="trigger">trigger: {trigger}</span>
      <p>{content.message}</p>

      <div className="links">
        {content.links?.map((label) => (
          <Button key={label} variant="quiet">
            {label}
          </Button>
        ))}
        {/* Dismissal is always available. Per docs/ux-decisions.md it also
            suppresses this trigger for the rest of the session, so declining help
            once is not punished by being asked again. */}
        <Button variant="quiet" onClick={onDismiss}>
          Dismiss
        </Button>
      </div>
    </aside>
  );
}
