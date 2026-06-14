#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const root = process.cwd();
const skillDir = path.join(root, ".agents", "skills", "pharos-agent-safepay");
const required = [
  "SKILL.md",
  "assets/networks.json",
  "assets/tokens.json",
  "references/deploy.md",
  "references/configure.md",
  "references/pay.md",
  "references/receipts.md",
  "templates/payment-plan.md.tpl"
];

const failures = [];

for (const rel of required) {
  const abs = path.join(skillDir, rel);
  if (!fs.existsSync(abs)) failures.push(`Missing ${rel}`);
}

function read(rel) {
  return fs.readFileSync(path.join(skillDir, rel), "utf8");
}

if (failures.length === 0) {
  const skill = read("SKILL.md");
  for (const needle of [
    "name: pharos-agent-safepay",
    "Capability Index",
    "references/deploy.md",
    "references/configure.md",
    "references/pay.md",
    "references/receipts.md"
  ]) {
    if (!skill.includes(needle)) failures.push(`SKILL.md missing ${needle}`);
  }

  const networks = JSON.parse(read("assets/networks.json"));
  if (networks.atlantic.chainId !== 688689) failures.push("Atlantic chainId must be 688689");
  if (networks.atlantic.rpcUrl !== "https://atlantic.dplabs-internal.com") {
    failures.push("Atlantic RPC URL mismatch");
  }

  const tokens = JSON.parse(read("assets/tokens.json"));
  if (tokens.atlantic.PHRS.address !== "0x0000000000000000000000000000000000000000") {
    failures.push("PHRS token address must be zero address");
  }

  const allText = required.map((rel) => read(rel)).join("\n");
  for (const forbidden of [
    /0x[a-fA-F0-9]{64}/,
    /PRIVATE_KEY=0x[a-fA-F0-9]/,
    /AGENT_PRIVATE_KEY=0x[a-fA-F0-9]/
  ]) {
    if (forbidden.test(allText)) failures.push(`Forbidden secret-like pattern: ${forbidden}`);
  }
}

if (failures.length > 0) {
  console.error("Skill validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Skill validation passed");
