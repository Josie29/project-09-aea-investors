/** The authenticated user's own record, as returned by `GET /api/v1/me`. */
export interface CurrentUser {
  id: number;
  clerk_id: string;
  created_at: string;
}

/** A single dependency's entry in the health report. */
export interface HealthCheck {
  status: "ok" | "unavailable" | "not_configured";
  latency_ms?: number;
  error?: string;
}

/** Response shape of `GET /api/v1/health`. */
export interface HealthReport {
  status: "ok" | "unavailable";
  checks: Record<string, HealthCheck>;
  checked_at: string;
}
