"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { STEPS, stepNumber } from "@/lib/onboarding/steps";

/**
 * Progress rail for the onboarding wizard.
 *
 * Steps behind the current one are marked done with a checkmark glyph in addition to
 * colour, so progress is readable without colour perception. The current step carries
 * `aria-current="step"` rather than relying on styling alone.
 *
 * Steps ahead of the current one are rendered but not linked — the flow is ordered,
 * and letting someone jump to confirmation before uploading anything would present a
 * screen with nothing to confirm.
 */
export function StepRail() {
  const pathname = usePathname();
  const currentIndex = STEPS.findIndex((step) => pathname.startsWith(step.href));

  return (
    <nav className="rail" aria-label="Intake steps">
      {STEPS.map((step, index) => {
        const isCurrent = index === currentIndex;
        const isDone = currentIndex > -1 && index < currentIndex;
        const content = (
          <>
            <span className="num">{stepNumber(index)}</span>
            <span className="label">{step.label}</span>
          </>
        );

        if (isDone) {
          return (
            <Link
              key={step.id}
              href={step.href}
              className="step"
              data-done="true"
            >
              {content}
            </Link>
          );
        }

        return (
          <span
            key={step.id}
            className="step"
            aria-current={isCurrent ? "step" : undefined}
            aria-disabled={!isCurrent}
          >
            {content}
          </span>
        );
      })}

      <p className="rail-foot">
        About 10 minutes.
        <br />
        Your progress saves as you go — close the tab and pick it back up.
      </p>
    </nav>
  );
}
