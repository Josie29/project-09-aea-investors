"use client";

import { useAuth } from "@clerk/nextjs";
import { useCallback } from "react";
import { request } from "./core";

/**
 * Returns a fetcher for calling the Rails API from a Client Component.
 *
 * The returned function resolves a fresh token on every invocation. Clerk tokens
 * live 60 seconds, so storing one in component state, a ref, or a memoised client's
 * default headers guarantees a 401 later in the wizard. Treat the token as
 * request-scoped, never as session-scoped.
 *
 * @returns an async function taking an API path and optional fetch options
 */
export function useApi() {
  const { getToken } = useAuth();

  return useCallback(
    async <T,>(path: string, init?: RequestInit): Promise<T> => {
      let token: string | null = null;

      try {
        token = await getToken();
      } catch {
        // Core 3 throws when the browser is offline rather than returning null.
        // Fall through unauthenticated so the API returns a clean 401 that the
        // caller can surface, instead of an unhandled rejection in the UI.
        token = null;
      }

      return request<T>(path, token, init);
    },
    [getToken],
  );
}
