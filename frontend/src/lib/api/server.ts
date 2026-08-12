import "server-only";
import { auth } from "@clerk/nextjs/server";
import { request } from "./core";

/**
 * Calls the Rails API from a Server Component, Route Handler, or Server Action.
 *
 * The token is fetched on every call by design. Clerk session tokens expire after
 * 60 seconds; the SDK refreshes them transparently, but only if `getToken()` is
 * invoked immediately before use. Caching a token at module scope or across a
 * render would 401 partway through the ten-minute onboarding flow.
 *
 * @param path - API path beginning with a slash
 * @param init - additional fetch options
 * @returns the parsed JSON body
 * @throws {ApiError} when the response status is not 2xx
 */
export async function serverApi<T>(path: string, init?: RequestInit): Promise<T> {
  // `auth()` is asynchronous in Clerk Core 2 and later — omitting the await
  // yields a Promise whose `getToken` is undefined.
  const { getToken } = await auth();
  const token = await getToken();

  return request<T>(path, token, init);
}
