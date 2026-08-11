import "@testing-library/jest-dom/vitest";

import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// Vitest globals are disabled, so React Testing Library's automatic cleanup
// never registers itself. Unmount explicitly to keep tests isolated.
afterEach(cleanup);
