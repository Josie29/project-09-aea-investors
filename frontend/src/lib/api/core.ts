const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

/** A non-2xx response from the Rails API. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly body: unknown,
  ) {
    super(`API request failed with ${status}`);
    this.name = "ApiError";
  }
}

/**
 * Issues a request against the Rails API.
 *
 * The token is passed in rather than resolved here because the two calling
 * contexts obtain it differently (`auth()` on the server, `useAuth()` on the
 * client). Keeping that split out of this function means the URL, headers, and
 * error handling exist in exactly one place.
 *
 * @param path - API path beginning with a slash, e.g. `/api/v1/me`
 * @param token - Clerk session token, or null for unauthenticated endpoints
 * @param init - additional fetch options
 * @returns the parsed JSON body, or undefined for a 204
 * @throws {ApiError} when the response status is not 2xx
 */
export async function request<T>(
  path: string,
  token: string | null,
  init: RequestInit = {},
): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
    // Authenticated responses are per-user and must never be served from a
    // shared cache to somebody else.
    cache: "no-store",
  });

  if (!response.ok) {
    const body = await response.json().catch(() => null);
    throw new ApiError(response.status, body);
  }

  return response.status === 204 ? (undefined as T) : ((await response.json()) as T);
}
