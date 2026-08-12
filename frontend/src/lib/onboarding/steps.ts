/**
 * The six onboarding steps, in order.
 *
 * This list is the single source of truth for the step rail, for step ordering, and
 * (later) for mapping to the backend `OnboardingSession` state machine — the `id`
 * values are chosen to match those states.
 */
export const STEPS = [
  { id: "consent", label: "Consent", href: "/onboarding/consent" },
  { id: "assessment", label: "Assessment", href: "/onboarding/assessment" },
  { id: "document", label: "Your ID", href: "/onboarding/document" },
  { id: "confirm", label: "Confirm details", href: "/onboarding/confirm" },
  { id: "schedule", label: "Book a time", href: "/onboarding/schedule" },
  { id: "done", label: "You're set", href: "/onboarding/done" },
] as const;

export type StepId = (typeof STEPS)[number]["id"];

/** Zero-based position of a step, or -1 if the id is unknown. */
export function stepIndex(id: StepId | string): number {
  return STEPS.findIndex((step) => step.id === id);
}

/** The step after `id`, or null at the end of the flow. */
export function nextStep(id: StepId): (typeof STEPS)[number] | null {
  const index = stepIndex(id);
  return index >= 0 && index < STEPS.length - 1 ? STEPS[index + 1] : null;
}

/** The step before `id`, or null at the start of the flow. */
export function previousStep(id: StepId): (typeof STEPS)[number] | null {
  const index = stepIndex(id);
  return index > 0 ? STEPS[index - 1] : null;
}

/** Two-digit display number, e.g. `01`. */
export function stepNumber(index: number): string {
  return String(index + 1).padStart(2, "0");
}
