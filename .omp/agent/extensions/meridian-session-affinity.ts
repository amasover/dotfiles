// Preserve Meridian SDK-session continuity across OMP tool rounds. The static
// x-meridian-agent marker in models.yml scopes this to the loopback proxy.

const MERIDIAN_AGENT_HEADER = "x-meridian-agent"
const SESSION_AFFINITY_HEADER = "x-session-affinity"

type ProviderHeaders = Record<string, string | undefined>

function targetsMeridian(headers: ProviderHeaders): boolean {
  return Object.keys(headers).some(
    (name) => name.toLowerCase() === MERIDIAN_AGENT_HEADER,
  )
}

export function applySessionAffinity(headers: ProviderHeaders, sessionId: string | undefined): void {
  if (!sessionId || !targetsMeridian(headers)) return
  headers[SESSION_AFFINITY_HEADER] = sessionId
}

export default function meridianSessionAffinity(pi: {
  on(
    event: "before_provider_headers",
    handler: (event: { headers: ProviderHeaders }, context: {
      sessionManager: { getSessionId(): string | undefined }
    }) => void,
  ): void
}) {
  pi.on("before_provider_headers", (event, context) => {
    applySessionAffinity(event.headers, context.sessionManager.getSessionId())
  })
}
