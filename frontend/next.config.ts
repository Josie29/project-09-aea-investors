import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Next 16 regenerates AGENTS.md and CLAUDE.md on every `next dev`. A CLAUDE.md
  // in the tree is picked up as project instructions, so we keep that file ours
  // rather than tool-generated.
  agentRules: false,
};

export default nextConfig;
