import { useEffect, useState } from "react";
import { PawPrint } from "lucide-react";
import { supabase } from "../lib/supabaseClient.ts";
import { getMediaSignedUrl } from "../lib/queries.ts";
import { cn } from "../lib/cn.ts";
import { dogTint } from "../lib/dogTint.ts";
import type { Dog } from "../../../../packages/shared/types/index.ts";

/** A dog's photo, or its tinted paw when it has none. Size comes from className. */
export function DogPhoto({ dog, className }: { dog: Dog; className: string }) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!dog.photo_path) return;
    let cancelled = false;
    getMediaSignedUrl(supabase, dog.photo_path)
      .then((signed) => {
        if (!cancelled) setUrl(signed);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [dog.photo_path]);

  return url ? (
    <img src={url} alt="" className={cn("shrink-0 object-cover", className)} />
  ) : (
    <div className={cn("flex shrink-0 items-center justify-center text-white", dogTint(dog.id), className)}>
      <PawPrint size="55%" aria-hidden="true" />
    </div>
  );
}
