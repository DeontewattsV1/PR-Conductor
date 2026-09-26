import { NextResponse } from "next/server";

export const runtime = "nodejs";

export async function POST(request) {
  const response = NextResponse.redirect(new URL("/", request.url), 303);
  response.cookies.set("prc_ph_access", "", { path: "/", maxAge: 0 });
  response.cookies.set("prc_ph_verifier", "", { path: "/", maxAge: 0 });
  response.cookies.set("prc_ph_state", "", { path: "/", maxAge: 0 });
  return response;
}
