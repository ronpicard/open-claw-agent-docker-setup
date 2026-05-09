#!/usr/bin/env node
/**
 * Print a Control UI URL with #token=... when `openclaw dashboard` cannot copy
 * to the clipboard (headless / dev containers).
 *
 * Usage: node scripts/print-openclaw-dashboard-url.js
 */
const fs = require("fs");
const path = require("path");
const os = require("os");

const stateDir = process.env.OPENCLAW_STATE_DIR || path.join(os.homedir(), ".openclaw");
const configPath = path.join(stateDir, "openclaw.json");

if (!fs.existsSync(configPath)) {
  console.error(`No config at ${configPath}. Run: openclaw onboard`);
  process.exit(1);
}

let cfg;
try {
  cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
} catch {
  console.error(
    `Could not parse ${configPath} as JSON. If the file uses JSON5-only syntax, copy gateway.auth.token manually.`,
  );
  process.exit(1);
}

const token = cfg?.gateway?.auth?.token;
const port = typeof cfg?.gateway?.port === "number" ? cfg.gateway.port : 18789;

if (!token || typeof token !== "string") {
  console.error(
    "No gateway.auth.token in config. Try: openclaw doctor --generate-gateway-token   or   openclaw onboard",
  );
  process.exit(1);
}

console.log(`http://127.0.0.1:${port}/#token=${encodeURIComponent(token)}`);
