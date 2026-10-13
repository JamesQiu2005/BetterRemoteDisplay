// Sells BetterRemoteDisplay Pro: Stripe takes the payment, this Worker hands over the download.
//
//   /                      -> the Stripe Payment Link
//   /thanks?session_id=…   -> where Stripe sends the buyer afterwards; shows the download button
//   /download?session_id=… -> the file, a limited number of times per purchase
//
// There are no accounts, licence keys or webhooks. The Checkout Session id in the URL is the
// proof of purchase: each request asks Stripe whether that session was paid.

interface Env {
  DOWNLOADS: KVNamespace;
  RELEASES: R2Bucket;
  STRIPE_SECRET_KEY: string;
  PAYMENT_LINK_URL: string;
  PAYMENT_LINK_ID?: string;
  RELEASE_KEY: string;
  MAX_DOWNLOADS: string;
  LINK_VALID_DAYS: string;
  /** Tests only: point at a fake Stripe. */
  STRIPE_API_BASE?: string;
}

type Purchase =
  | { ok: true; id: string; remaining: number }
  | { ok: false; status: number; message: string };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", { status: 405 });
    }
    switch (url.pathname) {
      case "/":
        return Response.redirect(env.PAYMENT_LINK_URL, 302);
      case "/thanks":
        return thanks(url, env);
      case "/download":
        return download(request, url, env);
      default:
        return page(404, "Not found", "<p>There’s nothing at this address.</p>");
    }
  },
} satisfies ExportedHandler<Env>;

async function thanks(url: URL, env: Env): Promise<Response> {
  const purchase = await lookUp(url.searchParams.get("session_id"), env);
  if (!purchase.ok) return page(purchase.status, "Download unavailable", `<p>${purchase.message}</p>`);
  const times = purchase.remaining === 1 ? "once" : `${purchase.remaining} more times`;
  return page(
    200,
    "Thank you",
    `<p>Your copy of BetterRemoteDisplay Pro is ready.</p>
     <p><a class="button" href="/download?session_id=${encodeURIComponent(purchase.id)}">Download</a></p>
     <p class="note">This link is yours: it works ${times}, for ${env.LINK_VALID_DAYS} days after purchase.
     Bookmark this page if you want to download later.</p>`,
  );
}

async function download(request: Request, url: URL, env: Env): Promise<Response> {
  const purchase = await lookUp(url.searchParams.get("session_id"), env);
  if (!purchase.ok) return page(purchase.status, "Download unavailable", `<p>${purchase.message}</p>`);

  const range = request.headers.get("range");
  const object = await env.RELEASES.get(env.RELEASE_KEY, { range: request.headers });
  if (!object) return page(503, "Download unavailable", "<p>The file is missing on our side. Please try again later.</p>");

  // Count a download when it starts. Resumed pieces of one already under way are free.
  const isStart = request.method === "GET" && (!range || /^bytes=0-/.test(range));
  if (isStart) {
    const used = Number(env.MAX_DOWNLOADS) - purchase.remaining;
    await env.DOWNLOADS.put(purchase.id, String(used + 1));
  }

  const headers = new Headers({
    "content-type": "application/zip",
    "content-disposition": `attachment; filename="${env.RELEASE_KEY}"`,
    "cache-control": "private, no-store",
    "accept-ranges": "bytes",
    etag: object.httpEtag,
  });
  if (object.range && "offset" in object.range && object.range.offset !== undefined && range) {
    const start = object.range.offset;
    const length = object.range.length ?? object.size - start;
    headers.set("content-range", `bytes ${start}-${start + length - 1}/${object.size}`);
    headers.set("content-length", String(length));
    return new Response(request.method === "HEAD" ? null : object.body, { status: 206, headers });
  }
  headers.set("content-length", String(object.size));
  return new Response(request.method === "HEAD" ? null : object.body, { headers });
}

/** Asks Stripe about a Checkout Session and works out whether it still entitles a download. */
async function lookUp(id: string | null, env: Env): Promise<Purchase> {
  if (!id || !/^cs_(live|test)_[A-Za-z0-9]{10,200}$/.test(id)) {
    return { ok: false, status: 400, message: "This link is incomplete. Use the link from your purchase confirmation page." };
  }
  const base = env.STRIPE_API_BASE ?? "https://api.stripe.com";
  const response = await fetch(`${base}/v1/checkout/sessions/${id}`, {
    headers: { authorization: `Bearer ${env.STRIPE_SECRET_KEY}` },
  });
  if (response.status === 404) {
    return { ok: false, status: 404, message: "We couldn’t find this purchase." };
  }
  if (!response.ok) {
    return { ok: false, status: 502, message: "We couldn’t reach the payment provider. Please try again in a minute." };
  }
  const session = (await response.json()) as { payment_status?: string; payment_link?: string | null; created?: number };

  if (session.payment_status !== "paid") {
    return { ok: false, status: 402, message: "This payment hasn’t completed yet. If you just paid, refresh in a moment." };
  }
  if (env.PAYMENT_LINK_ID && session.payment_link !== env.PAYMENT_LINK_ID) {
    return { ok: false, status: 403, message: "This purchase isn’t for BetterRemoteDisplay Pro." };
  }
  const validSeconds = Number(env.LINK_VALID_DAYS) * 86400;
  if (!session.created || Date.now() / 1000 - session.created > validSeconds) {
    return { ok: false, status: 410, message: "This download link has expired. Reply to your receipt email and we’ll send a new one." };
  }
  const used = Number((await env.DOWNLOADS.get(id)) ?? 0);
  const remaining = Number(env.MAX_DOWNLOADS) - used;
  if (remaining <= 0) {
    return { ok: false, status: 410, message: "This download link has already been used. Reply to your receipt email and we’ll send a new one." };
  }
  return { ok: true, id, remaining };
}

function page(status: number, title: string, body: string): Response {
  const html = `<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${title} · BetterRemoteDisplay</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 17px/1.5 -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; min-height: 100vh;
         display: grid; place-items: center; }
  main { max-width: 26rem; padding: 2rem; text-align: center; }
  h1 { font-size: 1.75rem; margin: 0 0 .5rem; }
  .button { display: inline-block; padding: .7rem 1.8rem; border-radius: 999px; background: #0a84ff;
            color: #fff; text-decoration: none; font-weight: 600; }
  .note { font-size: .85rem; opacity: .65; }
</style>
<main><h1>${title}</h1>${body}</main>
</html>`;
  return new Response(html, {
    status,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "private, no-store" },
  });
}
