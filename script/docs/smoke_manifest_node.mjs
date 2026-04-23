import fs from "node:fs";

const manifest = JSON.parse(fs.readFileSync(new URL("../../docs/generated/protocol-manifest.json", import.meta.url), "utf8"));

if (!Array.isArray(manifest.contracts) || manifest.contracts.length === 0) {
  throw new Error("manifest.contracts must be a non-empty array");
}

if (!manifest.enum_labels) {
  throw new Error("manifest must include enum_labels");
}

const required = ["ProtocolSettlement", "GameCatalog", "NumberPickerAdapter", "SlotMachineController", "SlotMachineEngine"];
for (const name of required) {
  if (!manifest.contracts.find((entry) => entry.name === name)) {
    throw new Error(`missing contract ${name}`);
  }
}

console.log("node manifest smoke passed");
