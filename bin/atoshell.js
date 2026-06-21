#!/usr/bin/env node
// Package-manager launcher for the atoshell Bash dispatcher and ato alias.
const { spawnSync } = require("child_process");
const path = require("path");
const fs = require("fs");

function bashPath(filePath) {
  if (process.platform !== "win32") {
    return filePath;
  }

  const converted = spawnSync("cygpath", ["-u", filePath], { encoding: "utf8" });
  if (converted.status === 0 && converted.stdout.trim()) {
    return converted.stdout.trim();
  }

  return filePath
    .replace(/\\/g, "/")
    .replace(/^([A-Za-z]):/, (_, drive) => `/${drive.toLowerCase()}`);
}

function bashCommand() {
  if (process.env.ATOSHELL_BASH) {
    return process.env.ATOSHELL_BASH;
  }

  if (process.platform === "win32") {
    const candidates = [
      "C:\\Program Files\\Git\\bin\\bash.exe",
      "C:\\Program Files\\Git\\usr\\bin\\bash.exe",
      "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
      "C:\\Program Files (x86)\\Git\\usr\\bin\\bash.exe"
    ];
    const found = candidates.find((candidate) => fs.existsSync(candidate));
    if (found) {
      return found;
    }
  }

  return "bash";
}

const script = bashPath(path.resolve(__dirname, "..", "atoshell.sh"));
const bash = bashCommand();
const result = spawnSync(bash, [script, ...process.argv.slice(2)], {
  stdio: "inherit",
  windowsHide: false
});

if (result.error) {
  console.error(`Error: failed to launch ${bash}: ${result.error.message}`);
  console.error("Atoshell package installs require Bash 4.3 or newer.");
  console.error("On Windows, install Git Bash or set ATOSHELL_BASH to a Bash executable.");
  console.error("On macOS, install modern Bash with Homebrew and set ATOSHELL_BASH if needed.");
  process.exit(1);
}

process.exit(result.status === null ? 1 : result.status);
