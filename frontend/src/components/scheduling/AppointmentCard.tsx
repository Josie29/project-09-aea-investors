import Link from "next/link";
import { Button } from "@/components/ui";
import { BOOKED_APPOINTMENT, type BookedAppointment } from "./confirmation";
import "./scheduling.css";

/**
 * The booked appointment, stated in full on the confirmation screen.
 *
 * Every fact the user needs in order to show up — who, where, how long — is on the card
 * rather than only in the confirmation email, because an email can be missed and this
 * screen is the one they are already looking at.
 *
 * @param appointment - the booking to show; defaults to the fixture in `confirmation.ts`
 */
export function AppointmentCard({
  appointment = BOOKED_APPOINTMENT,
}: {
  appointment?: BookedAppointment;
}) {
  return (
    <div className="appt">
      <p className="eyebrow">Your first appointment</p>
      <p className="when">{appointment.when}</p>
      <dl>
        <dt>With</dt>
        <dd>{appointment.clinician}</dd>
        <dt>Where</dt>
        <dd>{appointment.location}</dd>
        <dt>Length</dt>
        <dd>{appointment.length}</dd>
      </dl>
      <div className="appt-actions">
        {/* No calendar export exists yet. Disabled with a reason beats a button that
            silently does nothing. */}
        <Button variant="ghost" disabled title="Calendar export is not built yet in this prototype.">
          Add to calendar
        </Button>
        <Link className="btn quiet" href="/onboarding/schedule">
          Reschedule
        </Link>
      </div>
    </div>
  );
}
