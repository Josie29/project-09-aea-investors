import { IdUploadScreen } from "@/components/documents/IdUploadScreen";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

/**
 * Step 03 — photograph your ID.
 *
 * `?ocr=failed` marks the user as having arrived back from a read that failed, which is
 * what makes the `upload-failed` supportive card eligible on this step.
 */
export default async function DocumentPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;

  return <IdUploadScreen uploadFailed={params.ocr === "failed"} />;
}
