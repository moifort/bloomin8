import { getRequestURL } from "h3";
import {defineNitroPlugin} from "nitropack/runtime";

export default defineNitroPlugin((nitroApp) => {
  nitroApp.h3App.use((event) => {
    const start = Date.now();
    const { req, res } = event.node;
    const url = getRequestURL(event).toString();

    res.on("finish", () => {
      const durationMs = Date.now() - start;
      const status = res.statusCode;
      const method = req.method ?? "UNKNOWN";
      // Single-line log for easy grepping
      console.log(`${method} ${url} -> ${status} (${durationMs}ms)`);
    });
  });
});
