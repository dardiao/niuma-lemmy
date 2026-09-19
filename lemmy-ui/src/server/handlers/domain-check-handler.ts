import type { Request, Response } from "express";

// LOCAL: signup is tied to the operator's subdomain platform: a username is only accepted when
// `<name>.niuma.club` has really been registered there. The browser cannot query that platform
// directly (its CORS allowlist only covers its own pages), so this small same-origin proxy
// does it server-side. The name is validated against the DNS label charset before it is put
// into the upstream URL, so this cannot be used to reach anything else.
const DOMAIN_SUFFIX = "niuma.club";
const CHECK_URL = "https://hapdns.com/api/v1/check";
const LABEL_RE = /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/;
const UPSTREAM_TIMEOUT_MS = 5000;

export default async (req: Request, res: Response) => {
  const rawName = req.query.name;
  const name = (typeof rawName === "string" ? rawName : "")
    .trim()
    .toLowerCase();

  if (!LABEL_RE.test(name)) {
    res.status(400).json({ status: "invalid", reason: "格式不合法" });
    return;
  }

  const domain = `${name}.${DOMAIN_SUFFIX}`;
  try {
    const upstream = await fetch(
      `${CHECK_URL}?domain=${encodeURIComponent(domain)}`,
      { signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS) },
    );
    if (!upstream.ok) {
      res
        .status(502)
        .json({ status: "error", reason: `域名平台返回 ${upstream.status}` });
      return;
    }
    res.json(await upstream.json());
  } catch {
    res.status(502).json({ status: "error", reason: "无法连接域名平台" });
  }
};
