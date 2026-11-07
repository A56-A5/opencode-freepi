import type { Plugin } from "@opencode-ai/plugin"

// free-pi allows only 4 concurrent sessions per account, keyed by the
// x-session-id header. opencode sends its own per-session id (as
// X-Session-Id), so every new opencode session registered as a new
// free-pi session and tripped the cap. Pin all freepi traffic to one
// stable id: opencode = 1 slot. Set both casings — opencode's default
// uses X-Session-Id and object keys are case-sensitive.
export default (async () => {
  return {
    "chat.headers": async (input, output) => {
      if (input.model.providerID === "freepi") {
        output.headers["x-session-id"] = "opencode-freepi"
        output.headers["X-Session-Id"] = "opencode-freepi"
      }
    },
  }
}) satisfies Plugin
