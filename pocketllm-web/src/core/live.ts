import { liveQuery } from "dexie";
import { useEffect, useState } from "react";

export function useLiveValue<T>(query: () => Promise<T> | T, initial: T, deps: unknown[] = []) {
  const [value, setValue] = useState<T>(initial);
  useEffect(() => {
    const subscription = liveQuery(query).subscribe({
      next: setValue,
      error: (error) => console.error("PocketLLM live query failed", error),
    });
    return () => subscription.unsubscribe();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return value;
}
