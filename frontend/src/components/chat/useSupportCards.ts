"use client";

import { useCallback, useReducer } from "react";
import type { TriggerId } from "@/lib/onboarding/supportTriggers";

/**
 * Session bookkeeping for supportive content, implementing the governing rules in
 * docs/ux-decisions.md:
 *
 * - at most one card is on screen at a time;
 * - a trigger never fires twice in a session;
 * - dismissing a card suppresses that trigger for the rest of the session.
 *
 * Keeping this out of the screen component means the rules are one small reducer that a
 * test can drive directly, rather than something asserted through six screens.
 */

interface SupportCardState {
  /** The card currently on screen, if any. */
  visible: TriggerId | null;
  fired: readonly TriggerId[];
  dismissed: readonly TriggerId[];
}

type SupportCardAction = { type: "fire"; id: TriggerId } | { type: "dismiss"; id: TriggerId };

function reducer(state: SupportCardState, action: SupportCardAction): SupportCardState {
  switch (action.type) {
    case "fire": {
      const blocked =
        state.visible !== null || state.fired.includes(action.id) || state.dismissed.includes(action.id);
      if (blocked) return state;

      return { ...state, visible: action.id, fired: [...state.fired, action.id] };
    }
    case "dismiss": {
      if (state.visible !== action.id) return state;

      return {
        ...state,
        visible: null,
        dismissed: state.dismissed.includes(action.id) ? state.dismissed : [...state.dismissed, action.id],
      };
    }
  }
}

export interface SupportCards {
  /** The single card the screen may render right now. */
  visible: TriggerId | null;
  /** Requests a card. Silently ignored when the rules above forbid it. */
  fire: (id: TriggerId) => void;
  /** Dismisses a card and suppresses its trigger for the session. */
  dismiss: (id: TriggerId) => void;
}

/**
 * @param initiallyVisible - a trigger considered already fired at mount, for content the
 *   scripted conversation opens with. It occupies the one visible slot until dismissed.
 */
export function useSupportCards(initiallyVisible: TriggerId | null = null): SupportCards {
  const [state, dispatch] = useReducer(reducer, {
    visible: initiallyVisible,
    fired: initiallyVisible ? [initiallyVisible] : [],
    dismissed: [],
  });

  const fire = useCallback((id: TriggerId) => dispatch({ type: "fire", id }), []);
  const dismiss = useCallback((id: TriggerId) => dispatch({ type: "dismiss", id }), []);

  return { visible: state.visible, fire, dismiss };
}
