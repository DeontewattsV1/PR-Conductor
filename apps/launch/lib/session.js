import crypto from "node:crypto";

function key() {
  const secret = process.env.PRODUCT_HUNT_SESSION_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error("PRODUCT_HUNT_SESSION_SECRET must be at least 32 characters.");
  }
  return crypto.createHash("sha256").update(secret, "utf8").digest();
}

export function randomUrlSafe(bytes = 48) {
  return crypto.randomBytes(bytes).toString("base64url");
}

export function seal(value) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key(), iv);
  const encrypted = Buffer.concat([
    cipher.update(value, "utf8"),
    cipher.final()
  ]);
  const tag = cipher.getAuthTag();

  return Buffer.concat([iv, tag, encrypted]).toString("base64url");
}

export function open(sealed) {
  if (!sealed) return null;

  try {
    const payload = Buffer.from(sealed, "base64url");
    const iv = payload.subarray(0, 12);
    const tag = payload.subarray(12, 28);
    const encrypted = payload.subarray(28);
    const decipher = crypto.createDecipheriv("aes-256-gcm", key(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([
      decipher.update(encrypted),
      decipher.final()
    ]).toString("utf8");
  } catch {
    return null;
  }
}

export function sha256Base64Url(value) {
  return crypto.createHash("sha256").update(value, "ascii").digest("base64url");
}
