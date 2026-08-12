"use client";

import type { FormEvent } from "react";
import { Button } from "@/components/ui";
import "./chat.css";

interface ComposerProps {
  value: string;
  onChange: (value: string) => void;
  onSend: () => void;
  onFocusChange: (focused: boolean) => void;
  /** True while the assistant is answering; sending again would queue up nonsense. */
  busy?: boolean;
}

/**
 * The reply box.
 *
 * A `<form>` rather than an input plus a click handler, so Enter sends — the shortcut
 * every messaging app has trained users to expect.
 */
export function Composer({ value, onChange, onSend, onFocusChange, busy = false }: ComposerProps) {
  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || value.trim().length === 0) return;
    onSend();
  }

  return (
    <form className="composer" onSubmit={handleSubmit}>
      <label className="sr-only" htmlFor="chat-input">
        Your reply
      </label>
      <input
        id="chat-input"
        type="text"
        placeholder="Type your reply…"
        autoComplete="off"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        onFocus={() => onFocusChange(true)}
        onBlur={() => onFocusChange(false)}
      />
      <Button type="submit" className="send" disabled={busy || value.trim().length === 0}>
        {busy ? "Sending…" : "Send"}
      </Button>
    </form>
  );
}
