const hexByte = (value: number): string => value.toString(16).padStart(2, "0");

export const sha256Hex = async (value: string): Promise<string> => {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map(hexByte).join("");
};

const randomHex = (byteCount: number): string => {
  const bytes = new Uint8Array(byteCount);
  crypto.getRandomValues(bytes);
  return [...bytes].map(hexByte).join("");
};

export const newSecret = (prefix: string): string =>
  `${prefix}_${randomHex(24)}`;
