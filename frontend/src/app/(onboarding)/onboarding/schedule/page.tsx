import { ScreenHead } from "@/components/ui";
import { SlotPicker } from "@/components/scheduling/SlotPicker";

/** Step 05 — pick a first appointment from the open slots. */
export default function SchedulePage() {
  return (
    <div className="screen">
      <ScreenHead step="05" title="Pick a first appointment">
        Fifty minutes, video, with a clinician who works with panic and anxiety. Move it later if
        you need to.
      </ScreenHead>

      <SlotPicker />
    </div>
  );
}
