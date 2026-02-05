import { describe, expect, it } from "bun:test";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

const baseUrl = process.env.TEST_BASE_URL ?? "http://localhost:3000";
const imagePath =
  process.env.TEST_IMAGE_PATH ??
  join(process.cwd(), "data", "images", "test.jpeg");

describe("upload", () => {
  it("uploads a jpeg via raw body", async () => {
    const jpegBytes = await readFile(imagePath);
    const res = await fetch(`${baseUrl}/upload?filename=test_P.jpg`, {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: jpegBytes
    });

    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.status).toBe(200);
    expect(json.data.file).toBe("test_P.jpg");
  });
});
