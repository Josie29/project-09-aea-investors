/**
 * Stand-in confirmation data for the final screen.
 *
 * Same contract as `availability.ts`: fixtures shaped like the eventual API response so
 * the components stay unchanged when a real booking exists.
 */

export interface BookedAppointment {
  /** Long form date and time, e.g. `Thursday, August 14 · 4:15 PM`. */
  when: string;
  clinician: string;
  location: string;
  length: string;
}

export const BOOKED_APPOINTMENT: BookedAppointment = {
  when: "Thursday, August 14 · 4:15 PM",
  clinician: "Dr. Amara Osei, LCSW — anxiety & panic",
  location: "Video — link arrives 15 minutes before",
  length: "50 minutes",
};

/**
 * A logged data event the user is entitled to see.
 *
 * The brief requires retention and deletion to be visible rather than buried in a
 * policy page, so each receipt carries the timestamp of the event it records.
 */
export interface DataReceipt {
  event: string;
  /** Timestamp as displayed, including the zone — a bare time is not a receipt. */
  timestamp: string;
}

export const DATA_RECEIPTS: readonly DataReceipt[] = [
  { event: "ID photo deleted", timestamp: "2026-08-11 14:12 CDT" },
  { event: "Consent recorded", timestamp: "2026-08-11 13:58 CDT" },
] as const;

/** Plain-language statement of everything still held. Shown verbatim to the user. */
export const RETAINED_DATA_STATEMENT =
  "We kept five identity fields, your intake summary, and this booking. Nothing else.";
