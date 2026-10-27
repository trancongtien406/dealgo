import { NextResponse } from "next/server";

/** Reads a JSON request body for a BFF mutation; `null` means not JSON. */
export async function readJsonBody(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

export function badRequest(message: string) {
  return NextResponse.json({ success: false, message }, { status: 400 });
}
