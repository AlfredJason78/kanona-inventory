// File ini membuat koneksi ke Supabase dari sisi server (server components, server actions)

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Diabaikan jika dipanggil dari Server Component
          }
        },
      },
    },
  );
}

/* 
Kenapa berbeda dengan client.ts?

- Di browser, Supabase cukup tahu URL dan Key saja
- Di server, Supabase perlu akses ke cookie — karena info login user disimpan di cookie
- cookies() dari Next.js dipakai untuk membaca dan menyimpan cookie itu

*/
