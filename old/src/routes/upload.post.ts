import { defineEventHandler, getQuery, readRawBody } from "h3";
import { basename, extname } from "node:path";
import { writeFile } from "node:fs/promises";
import { ensureDataDirs, loadIndex, paths, saveIndex } from "../lib/storage";

const parseOrientation = (fileName: string): "P" | "L" | null => {
  if (fileName.endsWith("_P.jpg") || fileName.endsWith("_P.jpeg")) return "P";
  if (fileName.endsWith("_L.jpg") || fileName.endsWith("_L.jpeg")) return "L";
  return null;
};

export default defineEventHandler(async (event) => {
  const query = getQuery(event);
  const rawName = typeof query.filename === "string" ? query.filename : "";
  const safeName = basename(rawName);
  const extension = extname(safeName).toLowerCase();

  if (!safeName || safeName !== rawName) {
    return { status: 400, message: "Invalid filename" };
  }

  if (extension !== ".jpg" && extension !== ".jpeg") {
    return { status: 400, message: "Only .jpg/.jpeg allowed" };
  }

  const orientation = parseOrientation(safeName);
  if (!orientation) {
    return { status: 400, message: "Filename must end with _P.jpg or _L.jpg" };
  }

  const body = await readRawBody(event, false);
  if (!body || body.length === 0) {
    return { status: 400, message: "Empty body" };
  }

  await ensureDataDirs();
  const targetPath = `${paths.imagesDir}/${safeName}`;
  await writeFile(targetPath, body);

  const index = await loadIndex();
  index.photos.push({
    file: safeName,
    orientation,
    addedAt: new Date().toISOString()
  });
  await saveIndex(index);

  return {
    status: 200,
    message: "Uploaded",
    data: { file: safeName }
  };
});
