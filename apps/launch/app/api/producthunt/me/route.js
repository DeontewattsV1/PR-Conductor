import { NextResponse } from "next/server";
import { productHuntGraphQL } from "../../../../lib/producthunt";
import { open } from "../../../../lib/session";

export const runtime = "nodejs";

const VIEWER_QUERY = `
  query PRConductorViewer {
    viewer {
      user {
        username
      }
    }
  }
`;

export async function GET(request) {
  const accessToken = open(request.cookies.get("prc_ph_access")?.value);

  if (!accessToken) {
    return NextResponse.json({ connected: false }, { status: 401 });
  }

  try {
    const data = await productHuntGraphQL(accessToken, VIEWER_QUERY);
    return NextResponse.json({
      connected: Boolean(data?.viewer?.user),
      username: data?.viewer?.user?.username || null
    });
  } catch {
    const response = NextResponse.json(
      { connected: false, error: "product_hunt_session_invalid" },
      { status: 401 }
    );
    response.cookies.set("prc_ph_access", "", { path: "/", maxAge: 0 });
    return response;
  }
}
