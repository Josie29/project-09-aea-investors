"use client";

import { useRef } from "react";
import { Button } from "@/components/ui";
import { ACCEPT_ATTRIBUTE, UPLOAD_CONSTRAINTS_TEXT, uploadRejectionReason } from "./uploadLimits";
import "./documents.css";

/**
 * The ID photo picker.
 *
 * Two inputs rather than one: the camera route asks for the rear camera via `capture`,
 * which is what a phone user wants, while the file route opens the picker. Both are
 * visually hidden and driven by the visible buttons, and both carry a real label so the
 * control is named for assistive technology.
 *
 * The file type and size limits are stated in the dropzone before anything is chosen,
 * and the same constants back the guard that runs after.
 */
export function Dropzone({
  onAccepted,
  onRejected,
}: {
  /** Called with a file that passed the stated type and size limits. */
  onAccepted: (file: File) => void;
  /** Called with a user-facing reason when the file did not pass. */
  onRejected: (reason: string) => void;
}) {
  const cameraInput = useRef<HTMLInputElement>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  function handleSelection(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;

    const reason = uploadRejectionReason(file);
    if (reason === null) {
      onAccepted(file);
    } else {
      onRejected(reason);
    }

    // Clear the input so picking the same file twice still fires a change event.
    event.target.value = "";
  }

  return (
    <div className="dropzone">
      <span className="icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
          <rect x="2" y="6" width="20" height="14" />
          <circle cx="12" cy="13" r="4" />
          <path d="M8 6l1.5-2h5L16 6" />
        </svg>
      </span>

      <h3>Take a photo, or drop a file here</h3>
      <p className="constraints">{UPLOAD_CONSTRAINTS_TEXT}</p>

      <label className="sr-only" htmlFor="id-photo-camera">
        Photograph your ID
      </label>
      <input
        className="sr-only"
        id="id-photo-camera"
        ref={cameraInput}
        type="file"
        accept={ACCEPT_ATTRIBUTE}
        capture="environment"
        onChange={handleSelection}
      />

      <label className="sr-only" htmlFor="id-photo-file">
        Choose a photo of your ID
      </label>
      <input
        className="sr-only"
        id="id-photo-file"
        ref={fileInput}
        type="file"
        accept={ACCEPT_ATTRIBUTE}
        onChange={handleSelection}
      />

      <div className="upload-opts">
        <Button onClick={() => cameraInput.current?.click()}>Use camera</Button>
        <Button variant="ghost" onClick={() => fileInput.current?.click()}>
          Choose a file
        </Button>
      </div>
    </div>
  );
}
