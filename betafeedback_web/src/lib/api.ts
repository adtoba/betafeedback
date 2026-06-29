/** Build an API path. Uses relative URLs so Next.js rewrites can proxy to the backend. */
export function apiUrl(path: string): string {
  const base = process.env.NEXT_PUBLIC_API_URL ?? "";
  return `${base}${path}`;
}
