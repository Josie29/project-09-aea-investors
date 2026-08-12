"use client";

import { useEffect } from "react";
import { DWELL_TIMEOUT_MS } from "@/lib/onboarding/supportTriggers";

interface DwellOptions {
  /** Current contents of the composer. */
  draft: string;
  /** Whether the composer has focus. */
  focused: boolean;
  /** False once the trigger can no longer fire, e.g. after it has been dismissed. */
  enabled: boolean;
  /** Called when the user has been stuck mid-sentence for DWELL_TIMEOUT_MS. */
  onDwell: () => void;
}

/**
 * Fires the `dwell` trigger on a long pause *with evidence the user is stuck*.
 *
 * Per docs/ux-decisions.md a bare timer is not a trigger: a card that appears because
 * someone got up for water is patronizing, and the brief grades the negative case. So no
 * timer is even scheduled unless the composer is focused and holds a non-empty draft —
 * someone typing a sentence and stopping. Every keystroke restarts the clock, so the
 * card only lands on a genuine pause.
 *
 * @param options - the evidence to watch and what to call when it holds
 */
export function useDwellTrigger({ draft, focused, enabled, onDwell }: DwellOptions): void {
  const stuckMidSentence = focused && draft.trim().length > 0;

  useEffect(() => {
    if (!enabled || !stuckMidSentence) return;

    const timer = window.setTimeout(onDwell, DWELL_TIMEOUT_MS);
    return () => window.clearTimeout(timer);
    // `draft` is a dependency on purpose: typing restarts the pause.
  }, [enabled, stuckMidSentence, draft, onDwell]);
}
