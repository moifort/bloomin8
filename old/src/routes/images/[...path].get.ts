import { defineEventHandler, getRouterParam, setHeader, createError } from "h3";
import { readFile } from "node:fs/promises";
import { paths } from "../../lib/storage";
import { join } from "node:path";

export default defineEventHandler(async (event) => {
  const param = getRouterParam(event, "path");
  if (!param || param.includes("/") || param.includes("\\")) {
    throw createError({ statusCode: 400, statusMessage: "Invalid path" });
  }

  const filePath = join(paths.imagesDir, param);
  try {
    const file = await readFile(filePath);
    setHeader(event, "content-type", "image/jpeg");
    return file;
  } catch {
    throw createError({ statusCode: 404, statusMessage: "Not found" });
  }
});
