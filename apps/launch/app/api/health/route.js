import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    ok: true,
    service: "pr-conductor-launch",
    productHuntConfigured: Boolean(
      process.env.PRODUCT_HUNT_CLIENT_ID &&
      process.env.PRODUCT_HUNT_SESSION_SECRET
    )
  });
}
