"use client";

import { useState } from "react";
import { Button } from "@/components/ui";
import { DATA_RECEIPTS, RETAINED_DATA_STATEMENT, type DataReceipt } from "./confirmation";
import "./scheduling.css";

/**
 * "Your data" panel: what was deleted, what was kept, and how to get rid of the rest.
 *
 * The brief requires retention and deletion to be visible to the user and deletion to be
 * requestable on demand, so the receipts and both controls sit on the last screen the
 * user sees rather than in a settings page they would have to go looking for.
 *
 * Neither control is wired to anything — there is no backend in this build. "Download my
 * record" is disabled with a reason; withdrawal is left pressable, because burying the
 * revocation control would be the wrong thing to demonstrate, but pressing it says
 * plainly that nothing was sent and nothing was deleted. Claiming a deletion that did
 * not happen would be a worse failure than not having the feature.
 *
 * @param receipts - logged data events to show; defaults to the fixture in `confirmation.ts`
 */
export function DataPanel({ receipts = DATA_RECEIPTS }: { receipts?: readonly DataReceipt[] }) {
  const [withdrawalAttempted, setWithdrawalAttempted] = useState(false);

  return (
    <aside className="panel" aria-labelledby="data-h">
      <header className="panel-head">
        <p className="eyebrow" id="data-h">
          Your data
        </p>
      </header>
      <div className="panel-body">
        <div className="data-controls">
          {receipts.map((receipt) => (
            <p className="receipt" key={receipt.event}>
              <span className="ok" aria-hidden="true">
                &#10003;
              </span>
              <span>
                {receipt.event}
                <br />
                {receipt.timestamp}
              </span>
            </p>
          ))}

          <p className="kept">{RETAINED_DATA_STATEMENT}</p>

          <Button variant="ghost" disabled title="Record export is not built yet in this prototype.">
            Download my record
          </Button>

          <Button
            variant="ghost"
            aria-expanded={withdrawalAttempted}
            aria-controls="withdraw-status"
            onClick={() => setWithdrawalAttempted(true)}
          >
            Withdraw consent and delete everything
          </Button>

          {withdrawalAttempted && (
            <p className="not-wired" id="withdraw-status" role="status">
              Nothing has been deleted. This prototype has no server behind it, so the request was
              not sent anywhere. In the clinic build this stops processing immediately, purges your
              ID data and intake summary, and emails you a deletion receipt.
            </p>
          )}
        </div>
      </div>
    </aside>
  );
}
