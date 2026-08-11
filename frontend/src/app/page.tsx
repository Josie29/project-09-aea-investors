import Link from "next/link";
import { auth } from "@clerk/nextjs/server";
import { UserButton } from "@clerk/nextjs";
import { serverApi } from "@/lib/api/server";
import type { CurrentUser } from "@/types/api";

/**
 * Placeholder home page whose real job is to prove the Clerk to Rails round trip:
 * sign in here, and the record below is fetched from the Rails API using a verified
 * Clerk token. The onboarding wizard replaces this once its screens are built.
 */
export default async function Home() {
  const { userId } = await auth();

  if (!userId) {
    return (
      <main style={styles.main}>
        <h1 style={styles.heading}>Onboarding Assistant</h1>
        <p style={styles.muted}>Sign in to continue.</p>
        <Link href="/sign-in" style={styles.link}>
          Sign in
        </Link>
      </main>
    );
  }

  let user: CurrentUser | null = null;
  let error: string | null = null;

  try {
    user = await serverApi<CurrentUser>("/api/v1/me");
  } catch (cause) {
    // Surfaced rather than swallowed: while the API contract is being wired up, a
    // failure here is the single most useful diagnostic on the page.
    error = cause instanceof Error ? cause.message : "Unknown error";
  }

  return (
    <main style={styles.main}>
      <div style={styles.row}>
        <h1 style={styles.heading}>Onboarding Assistant</h1>
        <UserButton />
      </div>

      {user ? (
        <section>
          <p style={styles.muted}>Authenticated round trip to the Rails API succeeded.</p>
          <dl style={styles.list}>
            <dt style={styles.term}>User ID</dt>
            <dd style={styles.value}>{user.id}</dd>
            <dt style={styles.term}>Clerk ID</dt>
            <dd style={styles.value}>{user.clerk_id}</dd>
            <dt style={styles.term}>Created</dt>
            <dd style={styles.value}>{user.created_at}</dd>
          </dl>
        </section>
      ) : (
        <p style={styles.error}>Could not reach the API: {error}</p>
      )}
    </main>
  );
}

const styles: Record<string, React.CSSProperties> = {
  main: {
    minHeight: "100dvh",
    padding: "3rem 1.5rem",
    maxWidth: "40rem",
    margin: "0 auto",
    display: "flex",
    flexDirection: "column",
    gap: "1.5rem",
  },
  row: { display: "flex", alignItems: "center", justifyContent: "space-between", gap: "1rem" },
  heading: { fontSize: "1.75rem", margin: 0 },
  muted: { color: "#5c5c5c", margin: 0 },
  link: { alignSelf: "flex-start" },
  list: { display: "grid", gridTemplateColumns: "auto 1fr", gap: "0.5rem 1.5rem", marginTop: "1rem" },
  term: { fontSize: "0.75rem", textTransform: "uppercase", letterSpacing: "0.08em", color: "#8a8a8a" },
  value: { margin: 0, fontFamily: "ui-monospace, monospace" },
  error: { color: "#d9563a" },
};
