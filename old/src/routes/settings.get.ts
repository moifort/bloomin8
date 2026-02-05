import { defineEventHandler } from "h3";
import { loadSettings } from "../lib/storage";

export default defineEventHandler(async () => {
  const settings = await loadSettings();
  return { status: 200, data: settings };
});
