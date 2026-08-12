import { ConfirmDetailsScreen } from "@/components/documents/ConfirmDetailsScreen";
import { ExtractionOutcome, loadIdExtraction } from "@/components/documents/idExtraction";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

/**
 * Resolves which extraction state to render.
 *
 * There is no OCR service yet, so the state is chosen by query parameter. A reviewer
 * needs to reach the failure path without a deliberately bad photo, and the upload
 * screen links here with these parameters already set.
 *
 * @param params - the request's search parameters.
 * @returns the outcome to render; a clean read by default.
 */
function outcomeFrom(params: Record<string, string | string[] | undefined>): ExtractionOutcome {
  if (params.ocr === "failed") return ExtractionOutcome.Failed;
  if (params.entry === "manual") return ExtractionOutcome.Skipped;
  return ExtractionOutcome.Read;
}

/** Step 04 — confirm every extracted field before anything is saved. */
export default async function ConfirmPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;

  return <ConfirmDetailsScreen extraction={loadIdExtraction(outcomeFrom(params))} />;
}
