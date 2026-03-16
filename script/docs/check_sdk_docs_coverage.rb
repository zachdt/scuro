#!/usr/bin/env ruby
require "json"
require_relative "sdk_docs_inventory"

ROOT = File.expand_path("../..", __dir__)
GENERATED_DIR = File.join(ROOT, "docs/generated")

def public_members(source)
  body = File.read(File.join(ROOT, source))
  functions = body.scan(/function\s+([A-Za-z0-9_]+)\s*\([^)]*\)(?:(?!function).)*?\b(?:public|external)\b/m).flatten.uniq.sort
  events = body.scan(/event\s+([A-Za-z0-9_]+)\s*\(/).flatten.uniq.sort
  [functions, events]
end

def assert!(condition, message)
  raise message unless condition
end

manifest_path = File.join(GENERATED_DIR, "protocol-manifest.json")
event_signatures_path = File.join(GENERATED_DIR, "event-signatures.json")
enum_labels_path = File.join(GENERATED_DIR, "enum-labels.json")
proof_inputs_path = File.join(GENERATED_DIR, "proof-inputs.json")

[manifest_path, event_signatures_path, enum_labels_path, proof_inputs_path].each do |path|
  assert!(File.exist?(path), "missing generated artifact #{path.sub("#{ROOT}/", "")}")
end

manifest = JSON.parse(File.read(manifest_path))
assert!(manifest["contracts"].is_a?(Array), "manifest contracts must be an array")
assert!(manifest["enum_labels"].is_a?(Hash), "manifest enum_labels must be an object")
assert!(manifest["proof_inputs"].is_a?(Hash), "manifest proof_inputs must be an object")
assert!(manifest["local_defaults"].is_a?(Hash), "manifest local_defaults must be an object")
assert!(manifest["deployment_output_labels"].is_a?(Hash), "manifest deployment_output_labels must be an object")

manifest_contracts = manifest["contracts"].map { |entry| [entry.fetch("name"), entry] }.to_h

SdkDocsInventory.entries.each do |entry|
  doc = File.read(File.join(ROOT, entry[:doc]))
  functions, events = public_members(entry[:source])

  functions.each do |name|
    assert!(doc.include?(name), "doc coverage missing function #{entry[:name]}.#{name} in #{entry[:doc]}")
  end

  events.each do |name|
    assert!(doc.include?(name), "doc coverage missing event #{entry[:name]}.#{name} in #{entry[:doc]}")
  end

  abi_path = File.join(ROOT, "docs/generated/contracts/#{entry[:name]}.abi.json")
  assert!(File.exist?(abi_path), "missing generated ABI for #{entry[:name]}")

  manifest_entry = manifest_contracts[entry[:name]]
  assert!(manifest_entry, "manifest missing #{entry[:name]}")
  assert!(manifest_entry["reference_doc"] == entry[:doc], "manifest reference doc mismatch for #{entry[:name]}")
  assert!(manifest_entry["abi_path"] == "docs/generated/contracts/#{entry[:name]}.abi.json", "manifest abi path mismatch for #{entry[:name]}")
end

scenario_matrix = File.read(File.join(ROOT, "test/e2e/MATRIX.md")).scan(/`([A-Z0-9-]+)`/).flatten.uniq
scenario_mapping = File.read(File.join(ROOT, "docs/integration/scenario-mapping.md"))
scenario_matrix.each do |scenario_id|
  assert!(scenario_mapping.include?("`#{scenario_id}`"), "scenario mapping missing #{scenario_id}")
end

puts "sdk docs coverage check passed"
