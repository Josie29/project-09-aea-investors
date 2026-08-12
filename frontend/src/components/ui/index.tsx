import type { ReactNode } from "react";

/**
 * Shared UI primitives, styled by the global classes in `styles/components.css`.
 *
 * Deliberately thin: they exist so screens compose from named pieces rather than
 * repeating class strings, and so a style change happens in one place.
 */

type ButtonVariant = "primary" | "ghost" | "quiet";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  /** Renders a trailing arrow, matching the design's forward affordance. */
  withArrow?: boolean;
}

export function Button({
  variant = "primary",
  withArrow = false,
  children,
  className,
  type = "button",
  ...rest
}: ButtonProps) {
  const variantClass = variant === "primary" ? "" : ` ${variant}`;

  return (
    <button type={type} className={`btn${variantClass}${className ? ` ${className}` : ""}`} {...rest}>
      {children}
      {withArrow && (
        <span className="arrow" aria-hidden="true">
          &rarr;
        </span>
      )}
    </button>
  );
}

/** Status chip. Tone is paired with text in the label — never colour alone. */
export function Chip({ tone, children }: { tone: "ok" | "check" | "missing" | "info"; children: ReactNode }) {
  return <span className={`chip ${tone}`}>{children}</span>;
}

export function Panel({
  title,
  aside,
  children,
}: {
  title?: string;
  aside?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="panel">
      {title && (
        <header className="panel-head">
          <p className="eyebrow">{title}</p>
          {aside}
        </header>
      )}
      <div className="panel-body">{children}</div>
    </section>
  );
}

/** Quiet inline explanation. Used for privacy and retention statements. */
export function Note({ children }: { children: ReactNode }) {
  return (
    <p className="note">
      <span className="mark" aria-hidden="true">
        &rarr;
      </span>
      <span>{children}</span>
    </p>
  );
}

/**
 * Attention banner for a failure the user must act on.
 *
 * `role="status"` rather than `alert`: these announce a recoverable problem with a
 * path forward, and an assertive interruption is the wrong register for a user the
 * product assumes is already stressed.
 */
export function Banner({ children, actions }: { children: ReactNode; actions?: ReactNode }) {
  return (
    <div className="banner" role="status">
      <span className="b-text">{children}</span>
      {actions && <span className="b-actions">{actions}</span>}
    </div>
  );
}

export function ScreenHead({
  step,
  title,
  children,
}: {
  step: string;
  title: string;
  children?: ReactNode;
}) {
  return (
    <header className="screen-head">
      <p className="eyebrow">Step {step}</p>
      <h2>{title}</h2>
      {children && <p>{children}</p>}
    </header>
  );
}

/** Footer action row, separated from content by a rule. */
export function Actions({ children }: { children: ReactNode }) {
  return <div className="actions">{children}</div>;
}
