import ConsentPage from "@/app/(onboarding)/onboarding/consent/page";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";

const push = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));

describe("consent screen", () => {
  beforeEach(() => {
    push.mockClear();
  });

  // The brief requires explicit consent before anything is uploaded or processed. If
  // this breaks, a user reaches the ID upload without ever having agreed — the single
  // most visible compliance failure in the flow.
  it("keeps the forward button disabled until the box is ticked", async () => {
    const user = userEvent.setup();
    render(<ConsentPage />);

    const start = screen.getByRole("button", { name: /start intake/i });
    expect(start).toBeDisabled();

    await user.click(screen.getByRole("checkbox"));

    expect(start).toBeEnabled();
    await user.click(start);
    expect(push).toHaveBeenCalledWith("/onboarding/assessment");
  });

  // Guards against the gate being enforced by styling alone: a disabled-looking button
  // that still navigates would pass a screenshot review and fail a real one.
  it("does not navigate while consent is withheld", async () => {
    const user = userEvent.setup();
    render(<ConsentPage />);

    await user.click(screen.getByRole("button", { name: /start intake/i }));

    expect(push).not.toHaveBeenCalled();
  });

  // The retention promise is the reason a stressed user agrees at all; losing it turns
  // an informed consent into a blind one.
  it("states what happens to the ID photo before asking for agreement", () => {
    render(<ConsentPage />);

    expect(
      screen.getByText(/The photo is deleted the moment you confirm the fields/i),
    ).toBeInTheDocument();
  });
});
