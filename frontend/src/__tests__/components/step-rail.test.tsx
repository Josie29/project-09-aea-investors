import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { StepRail } from "@/components/ui/StepRail";

// The rail is the only persistent orientation cue in a six-step flow aimed at
// someone anxious. These guard the two properties that make it trustworthy:
// it says where you are, and it does not let you skip ahead into a screen with
// nothing in it yet.

const mockPathname = vi.fn();
vi.mock("next/navigation", () => ({
  usePathname: () => mockPathname(),
}));

describe("StepRail", () => {
  it("marks the current step for assistive technology, not just visually", () => {
    mockPathname.mockReturnValue("/onboarding/document");

    render(<StepRail />);

    const current = screen.getByText("Your ID").closest(".step");
    expect(current).toHaveAttribute("aria-current", "step");
  });

  // Completion is carried by a checkmark glyph as well as colour, so progress is
  // readable without colour perception.
  it("marks completed steps as done and links back to them", () => {
    mockPathname.mockReturnValue("/onboarding/schedule");

    render(<StepRail />);

    const consent = screen.getByText("Consent").closest(".step");
    expect(consent).toHaveAttribute("data-done", "true");
    expect(consent?.tagName).toBe("A");
  });

  // Jumping to confirmation before uploading anything would present a screen with
  // nothing to confirm, which reads as a broken product rather than a fast one.
  it("does not let the user skip to a step they have not reached", () => {
    mockPathname.mockReturnValue("/onboarding/consent");

    render(<StepRail />);

    const future = screen.getByText("Book a time").closest(".step");
    expect(future?.tagName).not.toBe("A");
    expect(future).toHaveAttribute("aria-disabled", "true");
  });
});
