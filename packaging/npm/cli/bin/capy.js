#!/usr/bin/env node
"use strict";

const childProcess = require("node:child_process");
const path = require("node:path");

const platformPackages = {
  "darwin-arm64": "@capybara/darwin-arm64",
  "darwin-x64": "@capybara/darwin-x64",
  "linux-x64": "@capybara/linux-x64",
  "linux-arm64": "@capybara/linux-arm64",
};

const target = process.platform + "-" + process.arch;
const packageName = platformPackages[target];

if (!packageName) {
  process.stderr.write(
    "capy: unsupported platform " + target + ". Supported platforms: " +
    Object.keys(platformPackages).join(", ") + "\n"
  );
  process.exit(1);
}

let packageJsonPath;
try {
  packageJsonPath = require.resolve(packageName + "/package.json");
} catch (error) {
  process.stderr.write(
    "capy: platform package " + packageName + " is not installed. " +
    "Reinstall @capybara/cli for this platform.\n"
  );
  process.exit(1);
}

const executable = path.join(path.dirname(packageJsonPath), "bin", "capy");
const child = childProcess.spawnSync(executable, process.argv.slice(2), {
  stdio: "inherit",
});

if (child.error) {
  process.stderr.write("capy: could not launch platform binary: " + child.error.message + "\n");
  process.exit(1);
}

process.exit(child.status === null ? 1 : child.status);
