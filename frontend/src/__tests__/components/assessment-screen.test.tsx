import AssessmentPage from "@/app/(onboarding)/onboarding/assessment/page";
import { ASSISTANT_REPLY_DELAY_MS } from "@/components/chat/scriptedConversation";
import { DWELL_TIMEOUT_MS } from "@/lib/onboarding/supportTriggers";
import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const push = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));

/**
 * Timer-driven behaviour needs a user-event instance that advances them too, otherwise
 * its internal delays never resolve and the test hangs rather than fails.
 */
function setupWithFakeTimers() {
  vi.useFakeTimers({ shouldAdvanceTime: true });
  return userEvent.setup({ advanceTimers: (ms) => vi.advanceTimersByTime(ms) });
}

function advance(ms: number) {
  act(() => {
    vi.advanceTimersByTime(ms);
  });
}

describe("assessment screen", () => {
  beforeEach(() => {
    push.mockClear();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  // docs/ux-decisions.md replaced the separate summary-review screen with this gate. If
  // it breaks, an unreviewed machine-written summary can reach a clinician — the
  // "no hallucinated commitment" failure the brief calls out.
  it("blocks the next step until the summary is acknowledged", async () => {
    const user = userEvent.setup();
    render(<AssessmentPage />);

    const next = screen.getByRole("button", { name: /next: your id/i });
    expect(next).toBeDisabled();

    await user.click(screen.getByRole("checkbox", { name: /this looks right/i }));

    expect(next).toBeEnabled();
    await user.click(next);
    expect(push).toHaveBeenCalledWith("/onboarding/document");
  });

  // Confirming and then editing must not leave a stale acknowledgement attached to
  // changed text, which would let an unseen correction through the gate.
  it("withdraws the acknowledgement when a summary line is edited", async () => {
    const user = userEvent.setup();
    render(<AssessmentPage />);

    await user.click(screen.getByRole("checkbox", { name: /this looks right/i }));
    await user.type(screen.getByLabelText("Frequency"), " (roughly)");

    expect(screen.getByRole("button", { name: /next: your id/i })).toBeDisabled();
  });

  // The brief grades the negative case: supportive content is never shown when no
  // trigger condition is met. A pause on its own is not a condition — a card appearing
  // because the user walked away is the exact false positive this guards.
  it("does not fire the dwell card on a bare timer", async () => {
    const user = setupWithFakeTimers();
    render(<AssessmentPage />);

    // Free the single card slot so only the dwell rules decide what happens next.
    await user.click(screen.getByRole("button", { name: /dismiss/i }));
    advance(DWELL_TIMEOUT_MS * 3);

    expect(screen.queryByText("trigger: dwell")).not.toBeInTheDocument();
  });

  // The other half of the same rule: a long pause with a half-written reply in the
  // composer is a user who is stuck, and that must still get help.
  it("fires the dwell card on a long pause with an unsent draft", async () => {
    const user = setupWithFakeTimers();
    render(<AssessmentPage />);

    await user.click(screen.getByRole("button", { name: /dismiss/i }));
    await user.type(screen.getByLabelText("Your reply"), "I think maybe");
    advance(DWELL_TIMEOUT_MS);

    expect(screen.getByText("trigger: dwell")).toBeInTheDocument();
  });

  // Dismissal suppresses a trigger for the session (docs/ux-decisions.md). Re-offering
  // help someone just declined is the behaviour that makes the feature feel surveillant.
  it("never shows the same card twice once dismissed", async () => {
    const user = setupWithFakeTimers();
    render(<AssessmentPage />);

    await user.click(screen.getByRole("button", { name: /dismiss/i }));
    await user.type(screen.getByLabelText("Your reply"), "I think maybe");
    advance(DWELL_TIMEOUT_MS);
    await user.click(screen.getByRole("button", { name: /dismiss/i }));
    await user.type(screen.getByLabelText("Your reply"), " something else");
    advance(DWELL_TIMEOUT_MS);

    expect(screen.queryByText("trigger: dwell")).not.toBeInTheDocument();
  });

  // The composer is the only way to add to the transcript; if sending stops appending,
  // the screen looks alive and silently discards what the user typed.
  it("appends the user's message and the assistant's reply", async () => {
    const user = setupWithFakeTimers();
    render(<AssessmentPage />);

    await user.type(screen.getByLabelText("Your reply"), "Video, please.{Enter}");
    expect(screen.getByText("Video, please.")).toBeInTheDocument();

    advance(ASSISTANT_REPLY_DELAY_MS);

    expect(screen.getByText(/added that to the summary on the right/i)).toBeInTheDocument();
  });
});
