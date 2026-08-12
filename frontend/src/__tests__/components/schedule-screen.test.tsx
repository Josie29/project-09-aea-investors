import SchedulePage from "@/app/(onboarding)/onboarding/schedule/page";
import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";

const routerMock = vi.hoisted(() => ({ push: vi.fn() }));

vi.mock("next/navigation", () => ({
  useRouter: () => routerMock,
}));

// Anchored: once a slot is chosen the book button's label repeats the slot's name, so
// an unanchored pattern matches both the slot and the action.
const TAKEN_SLOT = /^Wed, Aug 13 at 2:00 PM — Just taken$/;
const OPEN_SLOT = /^Thu, Aug 14 at 4:15 PM$/;
const OTHER_OPEN_SLOT = /^Fri, Aug 15 at 1:00 PM$/;

describe("schedule screen", () => {
  beforeEach(() => {
    routerMock.push.mockClear();
  });

  // The brief requires a double-booking of the same slot to be rejected. If this
  // breaks, a slot someone else holds looks bookable and the user finds out only
  // when the submit fails.
  it("renders an already-taken slot as unselectable and labelled", () => {
    render(<SchedulePage />);

    const taken = screen.getByRole("button", { name: TAKEN_SLOT });

    expect(taken).toBeDisabled();
    expect(taken).toHaveTextContent("Just taken");
    // Unavailability must not rest on colour alone, so it is never merely "unpressed".
    expect(taken).not.toHaveAttribute("aria-pressed");

    fireEvent.click(taken);

    expect(screen.getByRole("button", { name: /^Pick a time to continue/ })).toBeDisabled();
  });

  // Catches the bug where the primary action is live with nothing chosen, which would
  // book an arbitrary slot or fail silently.
  it("keeps the book button disabled until a slot is chosen, then names the slot", async () => {
    const user = userEvent.setup();
    render(<SchedulePage />);

    expect(screen.getByRole("button", { name: /^Pick a time to continue/ })).toBeDisabled();

    await user.click(screen.getByRole("button", { name: OPEN_SLOT }));

    const book = screen.getByRole("button", { name: /^Book Thu, Aug 14 at 4:15 PM/ });
    expect(book).toBeEnabled();

    await user.click(book);
    expect(routerMock.push).toHaveBeenCalledWith("/onboarding/done");
  });

  // Two slots pressed at once would make the confirmation ambiguous — the label says
  // one time while the grid shows two.
  it("allows only one selected slot at a time", async () => {
    const user = userEvent.setup();
    render(<SchedulePage />);

    await user.click(screen.getByRole("button", { name: OPEN_SLOT }));
    await user.click(screen.getByRole("button", { name: OTHER_OPEN_SLOT }));

    expect(screen.getByRole("button", { name: OPEN_SLOT })).toHaveAttribute(
      "aria-pressed",
      "false",
    );
    expect(screen.getByRole("button", { name: OTHER_OPEN_SLOT })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
  });

  // The brief grades the negative case for supportive content: it must not appear
  // until its trigger condition is met — here, the user rejecting the offered slots.
  it("shows the no-slots supportive content only after the user rejects the times", async () => {
    const user = userEvent.setup();
    render(<SchedulePage />);

    expect(screen.queryByRole("note")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Nothing here works/ }));

    expect(screen.getByRole("note")).toHaveTextContent(/same-week slots that open daily/);

    await user.click(screen.getByRole("button", { name: "Dismiss" }));
    expect(screen.queryByRole("note")).not.toBeInTheDocument();
  });
});
