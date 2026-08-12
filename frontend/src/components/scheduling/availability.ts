/**
 * Stand-in availability data for the booking screen.
 *
 * There is no scheduling API in this build. These fixtures have the shape the API is
 * expected to return, so swapping them for a fetch is a change to one module: the
 * components below only ever see `DayAvailability[]`.
 */

/**
 * Whether a slot can still be booked.
 *
 * `taken` exists as a first-class state because the brief requires a double-booking of
 * the same slot to be rejected. Rendering the conflict up front — struck through and
 * labelled — is the honest form of that rule; failing at submit is not.
 */
export type SlotStatus = "open" | "taken";

export interface Slot {
  /** Stable identifier. The real API is expected to key bookings on this. */
  id: string;
  /** Display time, e.g. `4:15 PM`. */
  time: string;
  status: SlotStatus;
}

export interface DayAvailability {
  id: string;
  /** Short weekday, e.g. `Thu`. */
  weekday: string;
  /** Short date, e.g. `Aug 14`. */
  date: string;
  slots: readonly Slot[];
}

export const AVAILABLE_DAYS: readonly DayAvailability[] = [
  {
    id: "2026-08-13",
    weekday: "Wed",
    date: "Aug 13",
    slots: [
      { id: "2026-08-13T09:00", time: "9:00 AM", status: "open" },
      { id: "2026-08-13T11:30", time: "11:30 AM", status: "open" },
      { id: "2026-08-13T14:00", time: "2:00 PM", status: "taken" },
    ],
  },
  {
    id: "2026-08-14",
    weekday: "Thu",
    date: "Aug 14",
    slots: [
      { id: "2026-08-14T08:30", time: "8:30 AM", status: "open" },
      { id: "2026-08-14T16:15", time: "4:15 PM", status: "open" },
      { id: "2026-08-14T17:30", time: "5:30 PM", status: "open" },
    ],
  },
  {
    id: "2026-08-15",
    weekday: "Fri",
    date: "Aug 15",
    slots: [
      { id: "2026-08-15T10:00", time: "10:00 AM", status: "open" },
      { id: "2026-08-15T13:00", time: "1:00 PM", status: "open" },
    ],
  },
  {
    id: "2026-08-18",
    weekday: "Mon",
    date: "Aug 18",
    slots: [
      { id: "2026-08-18T09:45", time: "9:45 AM", status: "open" },
      { id: "2026-08-18T15:00", time: "3:00 PM", status: "open" },
    ],
  },
] as const;

/** A slot together with the day it belongs to, so labels can name both. */
export interface DatedSlot {
  day: DayAvailability;
  slot: Slot;
}

/**
 * Looks a slot up by id across every day.
 *
 * @param slotId - the id to find, or null when nothing is selected
 * @param days - availability to search; defaults to the fixture
 * @returns the slot and its day, or null if the id is unknown
 */
export function findSlot(
  slotId: string | null,
  days: readonly DayAvailability[] = AVAILABLE_DAYS,
): DatedSlot | null {
  if (!slotId) return null;

  for (const day of days) {
    const slot = day.slots.find((candidate) => candidate.id === slotId);
    if (slot) return { day, slot };
  }
  return null;
}

/** Human phrase for a slot, e.g. `Thu, Aug 14 at 4:15 PM`. */
export function describeSlot({ day, slot }: DatedSlot): string {
  return `${day.weekday}, ${day.date} at ${slot.time}`;
}
