import { timingSafeEqual } from "node:crypto";

const allowed = /^\/(?:robots\.txt|archives\/20\d{2}(?:\/20\d{2}(?:0[1-9]|1[0-2]))?|20\d{2}-schedule-examination|(?:index\.php\/)?article\/[a-z0-9-]+|prc-(?:resolution|memorandum-circular)-no-\d+[a-z]?-s-20\d{2}(?:-\d+)?)$/;
const maxBytes = 2 * 1024 * 1024;
const encoder = new TextEncoder();

Deno.serve(async (request) => {
  const expected = Deno.env.get("PRC_ARCHIVE_TOKEN");
  const actual = request.headers.get("Authorization") ?? "";
  const credential = encoder.encode("Bearer " + expected);
  const candidate = encoder.encode(actual);
  if (!expected || candidate.length !== credential.length || !timingSafeEqual(candidate, credential)) {
    return new Response(null, { status: 401 });
  }
  const query = new URL(request.url).searchParams;
  const host = query.get("host") ?? "";
  const route = query.get("route") ?? "";
  if (request.method !== "GET" || !["www.prc.gov.ph", "prc.gov.ph"].includes(host) || !allowed.test(route)) {
    return new Response(null, { status: 400 });
  }

  try {
    const upstream = await fetch("https://" + host + route, {
      headers: { "User-Agent": "ResView exam archive (public PRC updates)" },
      redirect: "manual",
      signal: AbortSignal.timeout(15_000),
    });
    const headers = new Headers({ "X-PRC-Status": String(upstream.status) });
    for (const name of ["location", "retry-after"]) {
      const value = upstream.headers.get(name);
      if (value) headers.set("X-PRC-" + name, value);
    }
    if (!upstream.ok || !upstream.body) {
      await upstream.body?.cancel();
      return new Response(null, { headers });
    }
    let count = 0;
    const limited = upstream.body.pipeThrough(new TransformStream<Uint8Array, Uint8Array>({
      transform(chunk, controller) {
        count += chunk.byteLength;
        if (count > maxBytes) controller.error(new Error("PRC document too large."));
        else controller.enqueue(chunk);
      },
    }));
    return new Response(limited, { headers });
  } catch {
    return new Response(null, { status: 502 });
  }
});
