export function json(data: unknown, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set("content-type", "application/json");
  return new Response(JSON.stringify(data, null, 2), { ...init, headers });
}

export async function readJsonRequest(request: Request): Promise<Record<string, unknown>> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return {};
  }
  return (await request.json()) as Record<string, unknown>;
}

export function notFound(): Response {
  return json({ error: "not_found" }, { status: 404 });
}
