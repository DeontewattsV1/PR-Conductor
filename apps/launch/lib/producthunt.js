const AUTHORIZATION_URL = "https://api.producthunt.com/v2/oauth/authorize";
const TOKEN_URL = "https://api.producthunt.com/v2/oauth/token";
const GRAPHQL_URL = "https://api.producthunt.com/v2/api/graphql";

export function productHuntClientId() {
  const value = process.env.PRODUCT_HUNT_CLIENT_ID;
  if (!value) throw new Error("PRODUCT_HUNT_CLIENT_ID is not configured.");
  return value;
}

export function productHuntScopes() {
  return process.env.PRODUCT_HUNT_SCOPES || "public private";
}

export function productHuntRedirectUri(request) {
  return (
    process.env.PRODUCT_HUNT_REDIRECT_URI ||
    new URL("/api/producthunt/callback", request.url).toString()
  );
}

export function authorizationUrl({ clientId, redirectUri, scope, state, challenge }) {
  const url = new URL(AUTHORIZATION_URL);
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("scope", scope);
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge", challenge);
  url.searchParams.set("code_challenge_method", "S256");
  return url;
}

export async function exchangeAuthorizationCode({
  clientId,
  code,
  redirectUri,
  verifier
}) {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: clientId,
    code,
    redirect_uri: redirectUri,
    code_verifier: verifier
  });

  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body,
    cache: "no-store"
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    throw new Error(
      payload.error_description || payload.error || "Product Hunt token exchange failed."
    );
  }

  return payload;
}

export async function productHuntGraphQL(accessToken, query, variables = {}) {
  const response = await fetch(GRAPHQL_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`
    },
    body: JSON.stringify({ query, variables }),
    cache: "no-store"
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload.errors?.length) {
    const message =
      payload.errors?.[0]?.error_description ||
      payload.errors?.[0]?.message ||
      `Product Hunt API request failed with status ${response.status}.`;
    throw new Error(message);
  }

  return payload.data;
}
