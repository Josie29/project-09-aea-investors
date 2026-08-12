"use client";

import { useEffect, useRef } from "react";
import { SupportCard } from "@/components/support/SupportCard";
import { contentFor, type TriggerId } from "@/lib/onboarding/supportTriggers";
import type { StepId } from "@/lib/onboarding/steps";
import type { ChatItem } from "./scriptedConversation";
import "./chat.css";

interface ChatThreadProps {
  items: readonly ChatItem[];
  /** The step the thread is on, so a trigger cannot render where it does not belong. */
  step: StepId;
  /** The one supportive card allowed on screen, or null for none. */
  visibleTrigger: TriggerId | null;
  onDismissSupport: (trigger: TriggerId) => void;
}

/**
 * The conversation, with supportive cards rendered inline where they were triggered.
 *
 * `role="log"` because turns arrive over time and a screen reader should hear the new
 * ones without the user hunting for them.
 */
export function ChatThread({ items, step, visibleTrigger, onDismissSupport }: ChatThreadProps) {
  const threadRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Keep the newest turn in view; the thread scrolls internally at 30rem.
    const thread = threadRef.current;
    if (thread) thread.scrollTop = thread.scrollHeight;
  }, [items]);

  return (
    <div className="thread" role="log" aria-label="Conversation with the intake assistant" ref={threadRef}>
      {items.map((item) => {
        if (item.kind === "turn") {
          return (
            <div key={item.id} className={item.role === "user" ? "turn user" : "turn"}>
              <span className="who">{item.role === "user" ? "You" : "Assistant"}</span>
              <p className="bubble">{item.text}</p>
            </div>
          );
        }

        // Two independent gates, both of which must hold: the trigger has to be
        // allowed on this step, and it has to be the card currently granted the
        // single visible slot.
        const content = contentFor(item.trigger, step);
        if (!content || visibleTrigger !== item.trigger) return null;

        return (
          <SupportCard
            key={item.id}
            trigger={item.trigger}
            content={content}
            onDismiss={() => onDismissSupport(item.trigger)}
          />
        );
      })}
    </div>
  );
}
