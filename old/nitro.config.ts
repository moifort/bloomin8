import { defineNitroConfig } from "nitro/config";

export default defineNitroConfig({
  preset: "bun",
  serverDir: "src",
  routeRules: {
    "/images/**": {
      headers: {
        "cache-control": "public, max-age=31536000, immutable"
      }
    }
  }
});
