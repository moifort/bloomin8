export const nextCronTimeUtc = (intervalHours: number, nowMs = Date.now()): string => {
  const safeHours = Number.isFinite(intervalHours) && intervalHours > 0 ? intervalHours : 2;
  const next = new Date(nowMs + safeHours * 60 * 60 * 1000);
  return next.toISOString().replace(/\.\d{3}Z$/, "Z");
};
