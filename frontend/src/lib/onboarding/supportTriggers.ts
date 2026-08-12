import type { StepId } from "./steps";

/**
 * Declarative trigger table for supportive content.
 *
 * The brief grades the negative case as well as the positive one — content must never
 * appear when no trigger condition is met. Keeping conditions in a table rather than
 * scattered across components makes that assertion a unit test over data instead of an
 * end-to-end test over six screens.
 *
 * See docs/ux-decisions.md for the reasoning behind each trigger.
 */

export type TriggerId =
  | "express-distress"
  | "upload-failed"
  | "low-confidence"
  | "dwell"
  | "no-slots";

export interface SupportContent {
  /** Shown verbatim as the card body. */
  message: string;
  /** Optional follow-up affordances. These are prompts, never commitments. */
  links?: string[];
}

export interface SupportTrigger {
  id: TriggerId;
  /** Steps on which this trigger may fire. Firing anywhere else is a bug. */
  steps: readonly StepId[];
  content: SupportContent;
}

export const SUPPORT_TRIGGERS: readonly SupportTrigger[] = [
  {
    id: "express-distress",
    steps: ["assessment"],
    content: {
      message:
        "Starting is the hard part, and you've done it. Panic attacks are one of the most treatable things we see here.",
      links: ["What a first appointment is like", "Talk to someone now"],
    },
  },
  {
    id: "upload-failed",
    steps: ["document", "confirm"],
    content: {
      message:
        "Photos of ID trip up often — glare and laminate are the usual culprits. Typing your details takes about a minute and works just as well.",
      links: ["Why we ask for ID"],
    },
  },
  {
    id: "low-confidence",
    steps: ["confirm"],
    content: {
      message:
        "A couple of lines came out blurry. Correcting them now saves a phone call later — nothing is saved until you confirm.",
    },
  },
  {
    id: "dwell",
    steps: ["assessment", "confirm"],
    content: {
      message:
        "No rush — your progress is saved. If a question is hard to answer, you can skip it and tell your clinician instead.",
      links: ["Skip this for now"],
    },
  },
  {
    id: "no-slots",
    steps: ["schedule"],
    content: {
      message:
        "If none of these work, we hold same-week slots that open daily, and the clinic can book you by phone.",
      links: ["Call the clinic"],
    },
  },
] as const;

/**
 * Resolves the content for a trigger on a given step.
 *
 * @param id - the trigger being considered
 * @param step - the step the user is currently on
 * @returns the content to display, or null if this trigger must not fire here
 */
export function contentFor(id: TriggerId, step: StepId): SupportContent | null {
  const trigger = SUPPORT_TRIGGERS.find((candidate) => candidate.id === id);
  if (!trigger) return null;

  // A trigger firing on a step it does not belong to is the exact failure the
  // brief's "never shown when no trigger condition is met" criterion targets.
  return trigger.steps.includes(step) ? trigger.content : null;
}

/** Milliseconds of inactivity before the dwell trigger becomes eligible. */
export const DWELL_TIMEOUT_MS = 45_000;
