"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Actions, Button } from "@/components/ui";
import { SupportCard } from "@/components/support/SupportCard";
import { contentFor } from "@/lib/onboarding/supportTriggers";
import { nextStep } from "@/lib/onboarding/steps";
import {
  AVAILABLE_DAYS,
  describeSlot,
  findSlot,
  type DayAvailability,
  type Slot,
} from "./availability";
import "./scheduling.css";

/** Accessible name for a slot button: the visible time, qualified by its day. */
function slotLabel(day: DayAvailability, slot: Slot): string {
  const base = `${day.weekday}, ${day.date} at ${slot.time}`;
  return slot.status === "taken" ? `${base} — Just taken` : base;
}

/**
 * Four days of appointment slots with single-select behaviour.
 *
 * Slots another patient already holds are rendered disabled, struck through, and
 * labelled "Just taken" rather than being hidden or left bookable. The brief requires a
 * double-booking of the same slot to be rejected; rejecting it in the UI, before the
 * user invests a click, is the version that does not waste their time.
 *
 * Selection state is `aria-pressed` on real `<button>` elements, so the grid is
 * keyboard operable and announces its state without any custom key handling.
 *
 * @param days - availability to render; defaults to the fixture in `availability.ts`
 */
export function SlotPicker({ days = AVAILABLE_DAYS }: { days?: readonly DayAvailability[] }) {
  const router = useRouter();
  const [selectedSlotId, setSelectedSlotId] = useState<string | null>(null);
  const [supportRequested, setSupportRequested] = useState(false);
  const [supportDismissed, setSupportDismissed] = useState(false);

  const selection = findSlot(selectedSlotId, days);

  // Per docs/ux-decisions.md dismissal suppresses the trigger for the rest of the
  // session, so declining help once is not punished by being asked again.
  const support = supportRequested && !supportDismissed ? contentFor("no-slots", "schedule") : null;

  function book() {
    if (!selection) return;
    router.push(nextStep("schedule")?.href ?? "/onboarding/done");
  }

  return (
    <>
      <div className="cal" role="group" aria-label="Available appointment times">
        {days.map((day) => (
          <div className="day" key={day.id}>
            <span className="dhead">
              <span className="dow">{day.weekday}</span>
              <span className="date">{day.date}</span>
            </span>
            <div className="slots">
              {day.slots.map((slot) => {
                const taken = slot.status === "taken";
                return (
                  <button
                    className="slot"
                    type="button"
                    key={slot.id}
                    aria-label={slotLabel(day, slot)}
                    aria-pressed={taken ? undefined : slot.id === selectedSlotId}
                    disabled={taken}
                    onClick={() => setSelectedSlotId(slot.id)}
                  >
                    {slot.time}
                    {taken && <span className="taken">Just taken</span>}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      {support && (
        <SupportCard
          trigger="no-slots"
          content={support}
          onDismiss={() => setSupportDismissed(true)}
        />
      )}

      <Actions>
        {/* The label names the slot being booked, so the commitment is legible before
            it is made rather than only on the confirmation screen. */}
        <Button withArrow disabled={!selection} onClick={book}>
          {selection ? `Book ${describeSlot(selection)}` : "Pick a time to continue"}
        </Button>
        <Button variant="quiet" onClick={() => setSupportRequested(true)}>
          Nothing here works — show more times
        </Button>
      </Actions>
    </>
  );
}
