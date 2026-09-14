export type BusyKind = "generation" | "model-download" | "backup-restore" | "document-index" | "audio-transcription";

const counts = new Map<BusyKind, number>();
const listeners = new Set<() => void>();

function emit() {
  for (const listener of listeners) listener();
}

export function beginBusy(kind: BusyKind) {
  counts.set(kind, (counts.get(kind) ?? 0) + 1);
  emit();
  let released = false;
  return () => {
    if (released) return;
    released = true;
    const next = Math.max(0, (counts.get(kind) ?? 1) - 1);
    if (next) counts.set(kind, next);
    else counts.delete(kind);
    emit();
  };
}

export function busySnapshot() {
  return [...counts.entries()]
    .filter(([, count]) => count > 0)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([kind, count]) => `${kind}:${count}`)
    .join("|");
}

export function subscribeBusy(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function busyLabels(snapshot = busySnapshot()) {
  if (!snapshot) return [] as BusyKind[];
  return snapshot.split("|").map((item) => item.split(":")[0] as BusyKind);
}
