interface Env {
  ANTHROPIC_API_KEY: string;
  APP_SHARED_SECRET: string;
  RESEND_API_KEY: string;
  RATE_LIMITER: RateLimit;
}

interface NotifyRequest {
  to: string;
  userName: string;
  type: "protection_disabled" | "protection_bypassed" | "considering_disable";
}

const EMAIL_FROM = "MindfulPhone <alerts@mindfulphone.app>";

const EMAIL_TEMPLATES: Record<NotifyRequest["type"], { subject: string; html: (name: string) => string }> = {
  protection_bypassed: {
    subject: "⚠️ MindfulPhone protection was removed",
    html: (name) => `
      <p>Hi,</p>
      <p><strong>${name}</strong>'s MindfulPhone protection was removed by revoking Screen Time access.</p>
      <p>This bypasses the normal disable process. You may want to check in with them.</p>
      <p style="color: #888; font-size: 13px;">— MindfulPhone</p>
    `,
  },
  protection_disabled: {
    subject: "MindfulPhone was disabled",
    html: (name) => `
      <p>Hi,</p>
      <p><strong>${name}</strong> chose to disable MindfulPhone protection through the app.</p>
      <p>They went through the 5-minute waiting period before confirming.</p>
      <p style="color: #888; font-size: 13px;">— MindfulPhone</p>
    `,
  },
  considering_disable: {
    subject: "MindfulPhone disable timer started",
    html: (name) => `
      <p>Hi,</p>
      <p><strong>${name}</strong> started the 5-minute timer to disable MindfulPhone.</p>
      <p>They may change their mind — no action needed yet.</p>
      <p style="color: #888; font-size: 13px;">— MindfulPhone</p>
    `,
  },
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method !== "POST") {
      return new Response("Not found\n", { status: 404 });
    }

    // Auth check — reject before consuming rate limit tokens
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || authHeader !== `Bearer ${env.APP_SHARED_SECRET}`) {
      return Response.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Rate limit by client IP
    const clientIP = request.headers.get("cf-connecting-ip") ?? "unknown";
    const { success } = await env.RATE_LIMITER.limit({ key: clientIP });
    if (!success) {
      return Response.json(
        { error: "Rate limit exceeded. Try again shortly." },
        { status: 429 },
      );
    }

    // Route
    if (url.pathname === "/v1/messages") {
      return handleMessages(request, env, clientIP);
    }
    if (url.pathname === "/v1/notify") {
      return handleNotify(request, env, clientIP);
    }

    return new Response("Not found\n", { status: 404 });
  },
} satisfies ExportedHandler<Env>;

// MARK: - Proxy Claude messages

async function handleMessages(request: Request, env: Env, clientIP: string): Promise<Response> {
  const start = Date.now();
  try {
    const body = await request.text();

    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "anthropic-version": "2023-06-01",
        "x-api-key": env.ANTHROPIC_API_KEY,
      },
      body,
    });

    const elapsed = Date.now() - start;
    console.log(`POST /v1/messages → ${upstream.status} (${elapsed}ms) [${clientIP}]`);

    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "content-type": upstream.headers.get("content-type") ?? "application/json",
      },
    });
  } catch (err) {
    const elapsed = Date.now() - start;
    console.error(`POST /v1/messages → 502 (${elapsed}ms) [${clientIP}]`, err);
    return Response.json(
      { error: "Proxy failed to reach Anthropic API" },
      { status: 502 },
    );
  }
}

// MARK: - Notify accountability partner

async function handleNotify(request: Request, env: Env, clientIP: string): Promise<Response> {
  let body: NotifyRequest;
  try {
    body = await request.json() as NotifyRequest;
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!body.to || !body.userName || !body.type) {
    return Response.json({ error: "Missing required fields: to, userName, type" }, { status: 400 });
  }

  const template = EMAIL_TEMPLATES[body.type];
  if (!template) {
    return Response.json({ error: `Unknown notification type: ${body.type}` }, { status: 400 });
  }

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: [body.to],
        subject: template.subject,
        html: template.html(body.userName),
      }),
    });

    const result = await res.json();
    console.log(`POST /v1/notify → ${res.status} [${body.type}] [${clientIP}]`);

    if (!res.ok) {
      console.error("Resend error:", result);
      return Response.json({ error: "Failed to send notification" }, { status: 502 });
    }

    return Response.json({ success: true });
  } catch (err) {
    console.error("Resend request failed:", err);
    return Response.json({ error: "Failed to send notification" }, { status: 502 });
  }
}
