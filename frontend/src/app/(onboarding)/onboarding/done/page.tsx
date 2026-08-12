import Link from "next/link";
import { Actions, Panel, ScreenHead } from "@/components/ui";
import { AppointmentCard } from "@/components/scheduling/AppointmentCard";
import { DataPanel } from "@/components/scheduling/DataPanel";

/** The three things that happen after booking, in the order they happen. */
const NEXT_STEPS: readonly string[] = [
  "Dr. Osei reads your intake summary beforehand, so you won't have to tell the story twice.",
  "We check your insurance and email you the cost before the session — no surprises.",
  "If something comes up between now and then, call the clinic or use the crisis line on your confirmation.",
];

/** Step 06 — booking confirmation, what happens next, and the user's data controls. */
export default function DonePage() {
  return (
    <div className="screen">
      <ScreenHead step="06" title="You're booked">
        A confirmation is on its way to your email. That&apos;s everything we needed.
      </ScreenHead>

      <div className="cols">
        <div className="done-main">
          <AppointmentCard />

          <Panel title="What happens next">
            <ul className="next-steps">
              {NEXT_STEPS.map((step, index) => (
                <li key={step}>
                  <span className="n" aria-hidden="true">
                    {index + 1}
                  </span>
                  <span>{step}</span>
                </li>
              ))}
            </ul>
          </Panel>
        </div>

        <DataPanel />
      </div>

      <Actions>
        <Link className="btn quiet" href="/onboarding/consent">
          Restart the walkthrough
        </Link>
      </Actions>
    </div>
  );
}
