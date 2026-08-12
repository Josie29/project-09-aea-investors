import type { ReactNode } from "react";
import { StepRail } from "@/components/ui/StepRail";

/**
 * Chrome shared by every onboarding screen: the clinic bar and the step rail.
 *
 * The sample clinic is "Northline Behavioral Health" — the brief's specialised
 * service is assumed to be behavioral health, which is what makes consent, retention,
 * and supportive content load-bearing rather than decorative.
 */
export default function OnboardingLayout({ children }: { children: ReactNode }) {
  return (
    <div className="wrap">
      <div className="app">
        <div className="appbar">
          <div className="brandmark">
            <span className="glyph" aria-hidden="true">
              NB
            </span>
            <span>
              <span className="name">Northline Behavioral Health</span>
              <br />
              <span className="sub">New patient intake · sample clinic</span>
            </span>
          </div>

          {/* Reassurance in the chrome, where it is visible at every step rather
              than only on the consent screen. */}
          <p className="secure">
            <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" aria-hidden="true">
              <rect x="3" y="7" width="10" height="7" />
              <path d="M5.5 7V4.5a2.5 2.5 0 0 1 5 0V7" />
            </svg>
            Encrypted · you can stop anytime
          </p>
        </div>

        <div className="frame">
          <StepRail />
          <main>{children}</main>
        </div>
      </div>
    </div>
  );
}
