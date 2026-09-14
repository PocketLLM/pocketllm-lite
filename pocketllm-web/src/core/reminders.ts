import { startReminderLoop } from "./tools";

let stop: (() => void) | undefined;

export function bootReminderScheduler() {
  stop?.();
  stop = startReminderLoop();
}

export function stopReminderScheduler() {
  stop?.();
  stop = undefined;
}
