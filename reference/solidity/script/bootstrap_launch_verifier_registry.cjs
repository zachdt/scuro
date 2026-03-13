#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const ethers = require("ethers");

const DOMAIN = "SCURO_GROTH16_BN254_V1";
const ABI = [
  {
    inputs: [
      {
        components: [
          { internalType: "uint16", name: "publicSignalCount", type: "uint16" },
          { internalType: "uint256", name: "alphaX", type: "uint256" },
          { internalType: "uint256", name: "alphaY", type: "uint256" },
          { internalType: "uint256", name: "betaX1", type: "uint256" },
          { internalType: "uint256", name: "betaX2", type: "uint256" },
          { internalType: "uint256", name: "betaY1", type: "uint256" },
          { internalType: "uint256", name: "betaY2", type: "uint256" },
          { internalType: "uint256", name: "gammaX1", type: "uint256" },
          { internalType: "uint256", name: "gammaX2", type: "uint256" },
          { internalType: "uint256", name: "gammaY1", type: "uint256" },
          { internalType: "uint256", name: "gammaY2", type: "uint256" },
          { internalType: "uint256", name: "deltaX1", type: "uint256" },
          { internalType: "uint256", name: "deltaX2", type: "uint256" },
          { internalType: "uint256", name: "deltaY1", type: "uint256" },
          { internalType: "uint256", name: "deltaY2", type: "uint256" },
          { internalType: "uint256[]", name: "ic", type: "uint256[]" },
        ],
        internalType: "struct ScuroVerifierRegistry.VerificationKey",
        name: "vk",
        type: "tuple",
      },
      { internalType: "uint64", name: "verifyGas", type: "uint64" },
    ],
    name: "upsertVerificationKey",
    outputs: [{ internalType: "bytes32", name: "vkHash", type: "bytes32" }],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const LAUNCH_KEYS = [
  { name: "poker_initial_deal", file: "poker_initial_deal.vkey.json", gas: 350000, hash: "0x833ed812656caee88783d418ddf6d1cebd9b7856d70b47c44cd59b3d55fc5b31" },
  { name: "poker_draw", file: "poker_draw_resolve.vkey.json", gas: 355000, hash: "0xd52c550d4b81a3176cec079ec43c1a3a8c239f324305dc2fcf5c50784ce34d06" },
  { name: "poker_showdown", file: "poker_showdown.vkey.json", gas: 335000, hash: "0xd93598d756e561a8991900b72c468bf1aeb9a89ecfe4f0728becea885d43164c" },
  { name: "blackjack_initial_deal", file: "blackjack_initial_deal.vkey.json", gas: 430000, hash: "0x6a6bfbb56d4b0242fda025b81ae810c1bf01669b5e1fb4418d0e088dbfc567a7" },
  { name: "blackjack_action", file: "blackjack_action_resolve.vkey.json", gas: 430000, hash: "0xd7e870e383aeae0287dc886e043a08faf6147914d22b439ba42e7d4d4a29505d" },
  { name: "blackjack_showdown", file: "blackjack_showdown.vkey.json", gas: 360000, hash: "0x0f33158026795cc64e25b5430ec06eff21f2e39eea00b36bc11f9c0654b265d2" },
];

function loadEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

function flattenIC(points) {
  const flat = [];
  for (const point of points) {
    flat.push(point[0], point[1]);
  }
  return flat;
}

function toVk(json) {
  return {
    publicSignalCount: Number(json.nPublic),
    alphaX: json.vk_alpha_1[0],
    alphaY: json.vk_alpha_1[1],
    betaX1: json.vk_beta_2[0][1],
    betaX2: json.vk_beta_2[0][0],
    betaY1: json.vk_beta_2[1][1],
    betaY2: json.vk_beta_2[1][0],
    gammaX1: json.vk_gamma_2[0][1],
    gammaX2: json.vk_gamma_2[0][0],
    gammaY1: json.vk_gamma_2[1][1],
    gammaY2: json.vk_gamma_2[1][0],
    deltaX1: json.vk_delta_2[0][1],
    deltaX2: json.vk_delta_2[0][0],
    deltaY1: json.vk_delta_2[1][1],
    deltaY2: json.vk_delta_2[1][0],
    ic: flattenIC(json.IC),
  };
}

function computeVkHash(vk) {
  const coder = new ethers.utils.AbiCoder();
  const encoded = coder.encode(
    [
      "string",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256[]",
    ],
    [
      DOMAIN,
      vk.publicSignalCount,
      vk.alphaX,
      vk.alphaY,
      vk.betaX1,
      vk.betaX2,
      vk.betaY1,
      vk.betaY2,
      vk.gammaX1,
      vk.gammaX2,
      vk.gammaY1,
      vk.gammaY2,
      vk.deltaX1,
      vk.deltaX2,
      vk.deltaY1,
      vk.deltaY2,
      vk.ic,
    ]
  );
  return ethers.utils.keccak256(encoded);
}

async function main() {
  const rpcUrl = loadEnv("RPC_URL");
  const privateKey = loadEnv("PRIVATE_KEY");
  const registryAddress =
    process.env.VERIFIER_REGISTRY_ADDRESS || "0x0000000000000000000000000000000000000801";

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);
  const registry = new ethers.Contract(registryAddress, ABI, wallet);

  for (const key of LAUNCH_KEYS) {
    const filePath = path.join(process.cwd(), "zk", "vkeys", key.file);
    const json = JSON.parse(fs.readFileSync(filePath, "utf8"));
    const vk = toVk(json);
    const computedHash = computeVkHash(vk);
    if (computedHash.toLowerCase() !== key.hash.toLowerCase()) {
      throw new Error(`Hash mismatch for ${key.name}: expected ${key.hash}, got ${computedHash}`);
    }

    const tx = await registry.upsertVerificationKey(vk, key.gas);
    await tx.wait();
    console.log(`registered ${key.name}: ${computedHash}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
