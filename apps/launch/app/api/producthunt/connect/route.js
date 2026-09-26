import { NextResponse } from "next/server";
import {
  authorizationUrl,
  productHuntClientId,
  productHuntRedirectUri,
  productHuntScopes
} from "../../../../lib/producthunt";
import { randomUrlSafe, seal, sha256Base64Url } from "../../../../lib/session";

export const runtime = "nodejs";

export async function GET(request) {
  try {
    const verifier = randomUrlSafe(64);
    const challenge = sha256Base64Url(verifier);
    const state = randomUrlSafe(32);
    const redirectUri = productHuntRedirectUri(request);

    const url = authorizationUrl({
      clientId: productHuntClientId(),
      redirectUri,
      scope: productHuntScopes(),
      state,
      challenge
    });

    const response = NextResponse.redirect(url);
    const secure = process.env.NODE_ENV === "production";

    response.cookies.set("prc_ph_verifier", seal(verifier), {
      httpOnly: true,
      secure,
      sameSite: "lax",
      path: "/",
      maxAge: 10 * 60
    });

    response.cookies.set("prc_ph_state", state, {
      httpOnly: true,
      secure,
      sameSite: "lax",
      path: "/",
      maxAge: 10 * 60
    });

    return response;
  } catch (error) {
    return NextResponse.json(
      { error: "product_hunt_not_configured", detail: error.message },
      { status: 500 }
    );
  }
}
