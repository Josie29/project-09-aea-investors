"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Actions, Banner, Button, ScreenHead } from "@/components/ui";
import { AssessmentSummary } from "@/components/chat/AssessmentSummary";
import { ChatThread } from "@/components/chat/ChatThread";
import { Composer } from "@/components/chat/Composer";
import { useDwellTrigger } from "@/components/chat/useDwellTrigger";
import { useSupportCards } from "@/components/chat/useSupportCards";
import {
  ASSISTANT_REPLY_DELAY_MS,
  ASSISTANT_SLOW_AFTER_MS,
  INITIAL_ASSESSMENT_ROWS,
  SCRIPTED_CONVERSATION,
  assistantReplyTo,
  type AssessmentRow,
  type ChatItem,
} from "@/components/chat/scriptedConversation";
import { nextStep } from "@/lib/onboarding/steps";

/** The dwell card lands at the end of the thread, where the user is looking. */
const DWELL_SUPPORT_ITEM: ChatItem = { kind: "support", id: "s-dwell", trigger: "dwell" };

/**
 * Step 02 — the assessment conversation.
 *
 * The chat is fixture-backed (see `components/chat/scriptedConversation`); the structured
 * summary beside it is editable in place and must be acknowledged before the user can
 * move on, which is this build's answer to "no unreviewed machine summary reaches a
 * clinician" — see docs/ux-decisions.md §2.
 */
export default function AssessmentPage() {
  const router = useRouter();
  const forward = nextStep("assessment");

  const [items, setItems] = useState<readonly ChatItem[]>(SCRIPTED_CONVERSATION);
  const [rows, setRows] = useState<readonly AssessmentRow[]>(INITIAL_ASSESSMENT_ROWS);
  const [acknowledged, setAcknowledged] = useState(false);

  const [draft, setDraft] = useState("");
  const [composerFocused, setComposerFocused] = useState(false);

  // The message awaiting a reply, plus a retry counter so "Try again" restarts the wait.
  const [pendingMessage, setPendingMessage] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [assistantSlow, setAssistantSlow] = useState(false);

  // The scripted conversation opens with the distress card already showing, so it holds
  // the one visible slot until the user dismisses it.
  const support = useSupportCards("express-distress");
  const { visible: visibleTrigger, fire, dismiss } = support;

  const handleDwell = useCallback(() => fire("dwell"), [fire]);
  useDwellTrigger({
    draft,
    focused: composerFocused,
    enabled: visibleTrigger === null,
    onDwell: handleDwell,
  });

  useEffect(() => {
    if (pendingMessage === null) return;

    // Stand-in for the network round trip. The slow timer is the graceful-degradation
    // path the brief requires: the wait is bounded here, so a hanging provider surfaces
    // a way out instead of a spinner that never resolves.
    const replyTimer = window.setTimeout(() => {
      setItems((previous) => [
        ...previous,
        { kind: "turn", id: `a-${Date.now()}`, role: "assistant", text: assistantReplyTo(pendingMessage) },
      ]);
      setPendingMessage(null);
      setAssistantSlow(false);
    }, ASSISTANT_REPLY_DELAY_MS);

    const slowTimer = window.setTimeout(() => setAssistantSlow(true), ASSISTANT_SLOW_AFTER_MS);

    return () => {
      window.clearTimeout(replyTimer);
      window.clearTimeout(slowTimer);
    };
  }, [pendingMessage, attempt]);

  function handleSend() {
    const message = draft.trim();
    if (message.length === 0) return;

    setItems((previous) => [
      ...previous,
      { kind: "turn", id: `u-${Date.now()}`, role: "user", text: message },
    ]);
    setDraft("");
    setPendingMessage(message);
  }

  function handleRowChange(id: string, value: string) {
    setRows((previous) => previous.map((row) => (row.id === id ? { ...row, value } : row)));
    // What was confirmed is no longer what is on screen.
    setAcknowledged(false);
  }

  function handleRetry() {
    setAssistantSlow(false);
    setAttempt((previous) => previous + 1);
  }

  function handleUseShortForm() {
    // No separate form to route to: the summary beside the thread is already editable,
    // so abandoning the stalled request leaves the user typing their answers directly.
    setPendingMessage(null);
    setAssistantSlow(false);
  }

  function handleNext() {
    if (!acknowledged || !forward) return;
    router.push(forward.href);
  }

  function handleSkip() {
    // The brief's user can skip anything. Skipping does not defeat the acknowledgement
    // gate — it means there is no confirmed summary to send, not a confirmed one sent
    // unread.
    if (forward) router.push(forward.href);
  }

  const threadItems = useMemo(
    () => (visibleTrigger === "dwell" ? [...items, DWELL_SUPPORT_ITEM] : items),
    [items, visibleTrigger],
  );

  return (
    <div className="screen">
      <ScreenHead step="02" title="Tell us what's going on">
        In your own words. There are no wrong answers, and you can skip anything.
      </ScreenHead>

      {assistantSlow && (
        <Banner
          actions={
            <>
              <Button onClick={handleRetry}>Try again</Button>
              <Button variant="ghost" onClick={handleUseShortForm}>
                Use the short form
              </Button>
            </>
          }
        >
          <strong>The assistant is taking longer than usual.</strong>{" "}
          {"You don't have to wait — the short form asks the same questions."}
        </Banner>
      )}

      <div className="cols">
        <div>
          <ChatThread
            items={threadItems}
            step="assessment"
            visibleTrigger={visibleTrigger}
            onDismissSupport={dismiss}
          />
          <Composer
            value={draft}
            onChange={setDraft}
            onSend={handleSend}
            onFocusChange={setComposerFocused}
            busy={pendingMessage !== null}
          />
        </div>

        <AssessmentSummary
          rows={rows}
          onRowChange={handleRowChange}
          acknowledged={acknowledged}
          onAcknowledgedChange={setAcknowledged}
        />
      </div>

      <Actions>
        <Button
          onClick={handleNext}
          disabled={!acknowledged}
          withArrow
          aria-describedby={acknowledged ? undefined : "assess-gate-hint"}
        >
          Next: your ID
        </Button>
        <Button variant="quiet" onClick={handleSkip}>
          Skip the questions for now
        </Button>
      </Actions>

      {!acknowledged && (
        <p className="note" id="assess-gate-hint">
          <span className="mark" aria-hidden="true">
            →
          </span>
          <span>
            Tick &ldquo;This looks right&rdquo; beside the summary to continue. Nothing goes to a
            clinician until you do.
          </span>
        </p>
      )}
    </div>
  );
}
