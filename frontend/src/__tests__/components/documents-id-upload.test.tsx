import { IdUploadScreen } from "@/components/documents/IdUploadScreen";
import { MAX_UPLOAD_MB } from "@/components/documents/uploadLimits";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";

const push = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: (href: string) => push(href) }) }));

beforeEach(() => {
  push.mockClear();
});

describe("ID upload screen", () => {
  // The brief requires file type and size limits to be enforced; stating them before the
  // user picks means a rejection is never a surprise. If the constraints line moves
  // behind an error state, the user only learns the rule by breaking it.
  it("states the file type and size limits before anything is uploaded", () => {
    render(<IdUploadScreen />);

    expect(screen.getByText(`JPG or PNG · up to ${MAX_UPLOAD_MB} MB · both sides not needed`)).toBeInTheDocument();
  });

  // OCR failure must never dead-end. Typing is reachable here *before* an upload is
  // attempted, so the guarantee does not depend on the failure path working. If this
  // button ever becomes conditional on a failure, that guarantee is gone.
  it("offers typing details as a first-class action, with no upload attempted", async () => {
    const user = userEvent.setup();
    render(<IdUploadScreen />);

    // Curly apostrophe: the screen renders &rsquo;.
    await user.click(screen.getByRole("button", { name: "I’d rather type my details" }));

    expect(push).toHaveBeenCalledWith("/onboarding/confirm?entry=manual");
  });

  // Both pickers must accept only the types the copy promises, or the client-side guard
  // is the only thing standing between a PDF and the extraction call.
  it("restricts both file pickers to the accepted image types", () => {
    render(<IdUploadScreen />);

    for (const label of ["Photograph your ID", "Choose a photo of your ID"]) {
      expect(screen.getByLabelText(label)).toHaveAttribute("accept", "image/jpeg,image/png");
    }
  });

  // Supportive content is trigger-driven: arriving here normally must not show a card,
  // and coming back from a failed read must.
  it("surfaces the upload-failed card only after a read has failed", () => {
    const { unmount } = render(<IdUploadScreen />);
    expect(screen.queryByText("trigger: upload-failed")).not.toBeInTheDocument();
    unmount();

    render(<IdUploadScreen uploadFailed />);
    expect(screen.getByText("trigger: upload-failed")).toBeInTheDocument();
  });
});
