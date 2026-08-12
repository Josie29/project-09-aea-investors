import type { TriggerId } from "@/lib/onboarding/supportTriggers";

/**
 * The fixture behind step 02.
 *
 * There is no chat API yet, so the whole assistant side of the conversation lives in
 * this module. It is the seam: when the real endpoint exists, `SCRIPTED_CONVERSATION`
 * becomes the session's first server payload and `assistantReplyTo()` becomes the POST.
 * Nothing outside this file knows the conversation is canned.
 */

export type ChatRole = "assistant" | "user";

/** A spoken turn in the thread. */
export interface ChatTurn {
  kind: "turn";
  id: string;
  role: ChatRole;
  text: string;
}

/**
 * A supportive card positioned inside the thread.
 *
 * It is an item rather than a decoration on a turn because the mockup places it
 * between turns, and because whether it renders is decided by the trigger rules in
 * `lib/onboarding/supportTriggers`, not by the fixture.
 */
export interface ChatSupportItem {
  kind: "support";
  id: string;
  trigger: TriggerId;
}

export type ChatItem = ChatTurn | ChatSupportItem;

export const SCRIPTED_CONVERSATION: readonly ChatItem[] = [
  {
    kind: "turn",
    id: "a1",
    role: "assistant",
    text: "Hi — I'll get you set up with Northline. It takes about ten minutes and you can stop whenever you want. What's been going on?",
  },
  {
    kind: "turn",
    id: "u1",
    role: "user",
    text: "I've been having panic attacks at work, maybe two or three a week. My GP said I should talk to someone but I honestly don't know where to start.",
  },
  // Distress intent in the turn above is what fires this card. See the trigger table
  // in docs/ux-decisions.md.
  { kind: "support", id: "s1", trigger: "express-distress" },
  {
    kind: "turn",
    id: "a2",
    role: "assistant",
    text: "Thank you for telling me — that sounds exhausting, and it's a good reason to come in. Two quick things so I can match you with the right clinician: have you seen anyone about this before?",
  },
  { kind: "turn", id: "u2", role: "user", text: "No, this is the first time." },
  {
    kind: "turn",
    id: "a3",
    role: "assistant",
    text: "Got it. And would you rather meet in person at our Fulton Street office, or by video?",
  },
] as const;

/**
 * The assistant's answer to a user message.
 *
 * Canned for now — one reply for anything the user types. The signature is the one the
 * real call will have, so swapping in the API is a change to this body alone.
 *
 * @param message - what the user just sent
 * @returns the assistant's reply text
 */
export function assistantReplyTo(message: string): string {
  void message; // The canned reply ignores the input; the real call will not.

  return "Thanks — I've added that to the summary on the right. Have a look and change anything I got wrong.";
}

/** How long the canned reply pretends to think, in milliseconds. */
export const ASSISTANT_REPLY_DELAY_MS = 600;

/**
 * How long a pending reply may take before the user is offered a way out.
 *
 * The brief requires the chatbot to degrade gracefully on an LLM timeout rather than
 * hang, so the wait is bounded here and not by the network.
 */
export const ASSISTANT_SLOW_AFTER_MS = 3_000;

/** One line of the structured assessment the conversation is building. */
export interface AssessmentRow {
  id: string;
  label: string;
  /** Empty means the assistant has not established this yet. */
  value: string;
  /** Shown in place of an empty value — always words, never colour alone. */
  pendingLabel: string;
}

export const INITIAL_ASSESSMENT_ROWS: readonly AssessmentRow[] = [
  {
    id: "concern",
    label: "Presenting concern",
    value: "Panic attacks, workplace-triggered",
    pendingLabel: "Not yet assessed",
  },
  { id: "frequency", label: "Frequency", value: "2–3 per week", pendingLabel: "Not yet assessed" },
  { id: "referral", label: "Referral", value: "Primary care physician", pendingLabel: "Not yet assessed" },
  {
    id: "prior-care",
    label: "Prior care",
    value: "None — first episode of care",
    pendingLabel: "Not yet assessed",
  },
  { id: "modality", label: "Modality", value: "", pendingLabel: "Asking now…" },
  { id: "urgency", label: "Urgency", value: "", pendingLabel: "Not yet assessed" },
] as const;
