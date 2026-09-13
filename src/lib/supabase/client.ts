// File ini membuat koneksi ke Supabase dari sisi broswer (saat user klik tombol, isi form, dll)

import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}

/* 
Penjelasan:

createBrowserClient → fungsi dari Supabase untuk dipakai di browser
process.env.NEXT_PUBLIC_... → membaca nilai dari .env.local yang sudah kita buat
! di akhir → bilang ke TypeScript "percaya saya, nilai ini pasti ada"
*/
