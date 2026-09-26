import { NextResponse } from "next/server";
import {
  exchangeAuthorizationCode,
  productHuntClientId,
  productHuntRedirectUri
} from "../../../../lib/producthunt";
import { open, seal } from "../../../../lib/session";

export const runtime = "nodejs";

function clearTransientCookies(response) {
  response.cookies.set("prc_ph_verifier", "", { path: "/", maxAge: 0 });
  response.cookies.set("prc_ph_state", "", { path: "/", maxAge: 0 });
}

export async function GET(request) {
  const code = request.nextUrl.searchParams.get("code");
  const returnedState = request.nextUrl.searchParams.get("state");
  const expectedState = request.cookies.get("prc_ph_state")?.value;
  const verifier = open(request.cookies.get("prc_ph_verifier")?.value);

  if (!code || !returnedState || !expectedState || returnedState !== expectedState || !verifier) {
    const response = NextResponse.redirect(new URL("/?producthunt=invalid_state", request.url));
    clearTransientCookies(response);
    return response;
  }

  try {
    const token = await exchangeAuthorizationCode({
      clientId: productHuntClientId(),
      code,
      redirectUri: productHuntRedirectUri(request),
      verifier
    });

    const response = NextResponse.redirect(new URL("/?producthunt=connected", request.url));
    const secure = process.env.NODE_ENV === "production";

    response.cookies.set("prc_ph_access", seal(token.access_token), {
      httpOnly: true,
      secure,
      sameSite: "lax",
      path: "/",
      maxAge: 30 * 24 * 60 * 60
    });

    clearTransientCookies(response);
    return response;
  } catch {
    const response = NextResponse.redirect(new URL("/?producthunt=token_error", request.url));
    clearTransientCookies(response);
    return response;
  }
}
