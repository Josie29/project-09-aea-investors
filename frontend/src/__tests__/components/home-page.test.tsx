import HomePage from "@/app/page";
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

// Guards the toolchain end to end: JSX from src/app compiles, the `@/*` alias
// resolves, and a route component renders in jsdom. If this breaks, every
// later component test breaks with it and the failure is hard to localise.
describe("home page", () => {
  it("shows the onboarding assistant heading", () => {
    render(<HomePage />);

    expect(
      screen.getByRole("heading", { name: "Onboarding Assistant" }),
    ).toBeInTheDocument();
  });
});
