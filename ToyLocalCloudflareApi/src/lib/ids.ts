export const newId = (prefix: string): string =>
  `${prefix}_${crypto.randomUUID().replaceAll("-", "")}`;
