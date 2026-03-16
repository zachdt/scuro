#!/usr/bin/env ruby
require "fileutils"
require "json"
require_relative "sdk_docs_inventory"

ROOT = File.expand_path("../..", __dir__)
GENERATED_DIR = File.join(ROOT, "docs/generated")
CONTRACTS_DIR = File.join(GENERATED_DIR, "contracts")

def artifact_path_for(entry)
  matches = Dir.glob(File.join(ROOT, "out/**/#{entry[:name]}.json"))
  preferred = matches.find { |path| path.include?(File.basename(entry[:source])) }
  preferred || matches.first
end

def load_abi(entry)
  artifact = artifact_path_for(entry)
  raise "missing artifact for #{entry[:name]} - run forge build first" unless artifact

  json = JSON.parse(File.read(artifact))
  abi = json.fetch("abi")
  [artifact, abi]
end

def signature(item)
  name = item.fetch("name")
  types = item.fetch("inputs", []).map { |input| input.fetch("type") }
  "#{name}(#{types.join(',')})"
end

def public_members(source)
  body = File.read(File.join(ROOT, source))
  functions = body.scan(/function\s+([A-Za-z0-9_]+)\s*\([^)]*\)(?:(?!function).)*?\b(?:public|external)\b/m).flatten.uniq.sort
  events = body.scan(/event\s+([A-Za-z0-9_]+)\s*\(/).flatten.uniq.sort
  [functions, events]
end

FileUtils.mkdir_p(CONTRACTS_DIR)

event_signatures = {}
manifest_contracts = []

SdkDocsInventory.entries.each do |entry|
  artifact_path, abi = load_abi(entry)
  functions, events = public_members(entry[:source])

  abi_path = File.join(CONTRACTS_DIR, "#{entry[:name]}.abi.json")
  File.write(abi_path, JSON.pretty_generate(abi))

  event_signatures[entry[:name]] = abi.select { |item| item["type"] == "event" }.map do |item|
    {
      "name" => item["name"],
      "signature" => signature(item),
      "anonymous" => item["anonymous"]
    }
  end

  manifest_contracts << {
    "name" => entry[:name],
    "category" => entry[:category],
    "source" => entry[:source],
    "artifact" => artifact_path.sub("#{ROOT}/", ""),
    "reference_doc" => entry[:doc],
    "abi_path" => abi_path.sub("#{ROOT}/", ""),
    "functions" => functions,
    "events" => events
  }
end

schema = {
  "$schema" => "https://json-schema.org/draft/2020-12/schema",
  "title" => "Scuro protocol manifest",
  "type" => "object",
  "required" => %w[contracts enum_labels proof_inputs local_defaults deployment_output_labels],
  "properties" => {
    "contracts" => { "type" => "array" },
    "enum_labels" => { "type" => "object" },
    "proof_inputs" => { "type" => "object" },
    "local_defaults" => { "type" => "object" },
    "deployment_output_labels" => { "type" => "object" }
  }
}

manifest = {
  "contracts" => manifest_contracts,
  "enum_labels" => SdkDocsInventory.enum_labels,
  "proof_inputs" => SdkDocsInventory.proof_inputs,
  "local_defaults" => SdkDocsInventory.local_defaults,
  "deployment_output_labels" => SdkDocsInventory.deployment_output_labels
}

File.write(File.join(GENERATED_DIR, "protocol-manifest.schema.json"), JSON.pretty_generate(schema))
File.write(File.join(GENERATED_DIR, "protocol-manifest.json"), JSON.pretty_generate(manifest))
File.write(File.join(GENERATED_DIR, "event-signatures.json"), JSON.pretty_generate(event_signatures))
File.write(File.join(GENERATED_DIR, "enum-labels.json"), JSON.pretty_generate(SdkDocsInventory.enum_labels))
File.write(File.join(GENERATED_DIR, "proof-inputs.json"), JSON.pretty_generate(SdkDocsInventory.proof_inputs))

puts "generated protocol metadata in docs/generated"
