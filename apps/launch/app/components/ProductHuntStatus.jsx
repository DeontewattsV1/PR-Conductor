"use client";

import { useEffect, useState } from "react";

export default function ProductHuntStatus() {
  const [status, setStatus] = useState({ loading: true });

  useEffect(() => {
    let active = true;
    fetch("/api/producthunt/me", { cache: "no-store" })
      .then(async (response) => {
        const body = await response.json().catch(() => ({}));
        if (!active) return;
        setStatus({
          loading: false,
          connected: response.ok && body.connected,
          username: body.username || null
        });
      })
      .catch(() => {
        if (active) setStatus({ loading: false, connected: false });
      });

    return () => {
      active = false;
    };
  }, []);

  if (status.loading) {
    return <div className="connectionCard">Checking Product Hunt connection…</div>;
  }

  if (!status.connected) {
    return (
      <div className="connectionCard">
        <strong>Product Hunt not connected</strong>
        <span>Authorize the public PKCE client for user-context API access.</span>
        <a className="button primary compact" href="/api/producthunt/connect">
          Connect Product Hunt
        </a>
      </div>
    );
  }

  return (
    <div className="connectionCard success">
      <strong>Product Hunt connected</strong>
      <span>{status.username ? `@${status.username}` : "Authenticated user"}</span>
      <form action="/api/producthunt/disconnect" method="post">
        <button className="button secondary compact" type="submit">
          Disconnect
        </button>
      </form>
    </div>
  );
}
