import DonePage from "@/app/(onboarding)/onboarding/done/page";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

describe("done screen", () => {
  // The brief requires retention and deletion to be visible to the user. If the
  // receipts or the withdrawal control disappear, the flow ends with the user unable
  // to see what was kept or ask for it to go.
  it("shows deletion receipts, what was retained, and both data controls", () => {
    render(<DonePage />);

    const dataPanel = screen.getByRole("complementary", { name: "Your data" });

    expect(dataPanel).toHaveTextContent("ID photo deleted");
    expect(dataPanel).toHaveTextContent("2026-08-11 14:12 CDT");
    expect(dataPanel).toHaveTextContent("Consent recorded");
    expect(dataPanel).toHaveTextContent("2026-08-11 13:58 CDT");
    expect(dataPanel).toHaveTextContent(
      "We kept five identity fields, your intake summary, and this booking. Nothing else.",
    );

    expect(screen.getByRole("button", { name: "Download my record" })).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Withdraw consent and delete everything" }),
    ).toBeInTheDocument();
  });

  // There is no backend. Telling a user their data was deleted when nothing happened
  // is the worst failure this screen can produce, so the response must say so.
  it("states plainly that withdrawal is not wired up rather than claiming a deletion", async () => {
    const user = userEvent.setup();
    render(<DonePage />);

    await user.click(screen.getByRole("button", { name: "Withdraw consent and delete everything" }));

    const status = screen.getByRole("status");
    expect(status).toHaveTextContent("Nothing has been deleted.");
    expect(status).toHaveTextContent(/the request was not sent anywhere/);
  });

  // The appointment details are the reason the user came; losing any of them means
  // they cannot attend the session they just booked.
  it("confirms when, with whom, where, and how long", () => {
    render(<DonePage />);

    expect(screen.getByText("Thursday, August 14 · 4:15 PM")).toBeInTheDocument();
    expect(screen.getByText("Dr. Amara Osei, LCSW — anxiety & panic")).toBeInTheDocument();
    expect(screen.getByText("Video — link arrives 15 minutes before")).toBeInTheDocument();
    expect(screen.getByText("50 minutes")).toBeInTheDocument();
  });
});
