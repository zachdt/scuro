#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const ethers = require("ethers");

const REGISTRY_ADDRESS = "0x0000000000000000000000000000000000000801";
const DEFAULT_ADMIN_ROLE = ethers.constants.HashZero;
const REGISTRAR_ROLE =
  "0xedcc084d3dcd65a1f7f23c65c46722faca6953d28e43150a467cf43e5c309238";
const DEFAULT_CHAIN_ID = 31338;
const DEFAULT_CLIQUE_PERIOD = 0;
const DEFAULT_BALANCE = "0x3635C9ADC5DEA00000"; // 1000 ether

function loadEnv(name, fallback) {
  const value = process.env[name];
  if (value) {
    return value;
  }
  if (fallback !== undefined) {
    return fallback;
  }
  throw new Error(`Missing required env var: ${name}`);
}

function normalizePrivateKey(value) {
  return value.startsWith("0x") ? value : `0x${value}`;
}

function pad32(value) {
  return ethers.utils.hexZeroPad(ethers.BigNumber.from(value).toHexString(), 32);
}

function mappingSlot(keyTypes, values, slot) {
  return ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode([...keyTypes, "uint256"], [...values, slot])
  );
}

function registryRuntimeBytecode() {
  const artifactPath = path.join(
    process.cwd(),
    "out",
    "ScuroVerifierRegistry.sol",
    "ScuroVerifierRegistry.json"
  );
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
  const object = artifact.deployedBytecode && artifact.deployedBytecode.object;
  if (!object) {
    throw new Error(`Missing deployed bytecode in ${artifactPath}`);
  }
  return object.startsWith("0x") ? object : `0x${object}`;
}

function roleStorage(adminAddress) {
  const defaultRoleBase = ethers.BigNumber.from(
    mappingSlot(["bytes32"], [DEFAULT_ADMIN_ROLE], 0)
  );
  const registrarRoleBase = ethers.BigNumber.from(
    mappingSlot(["bytes32"], [REGISTRAR_ROLE], 0)
  );

  return {
    [mappingSlot(["address"], [adminAddress], defaultRoleBase)]: pad32(1),
    [mappingSlot(["address"], [adminAddress], registrarRoleBase)]: pad32(1),
    [pad32(registrarRoleBase.add(1))]: pad32(DEFAULT_ADMIN_ROLE),
  };
}

function cliqueExtraData(signerAddress) {
  return `0x${"00".repeat(32)}${signerAddress.slice(2)}${"00".repeat(65)}`;
}

function renderGenesis() {
  const adminKey = normalizePrivateKey(loadEnv("PRIVATE_KEY"));
  const player1Key = normalizePrivateKey(
    loadEnv(
      "PLAYER1_PRIVATE_KEY",
      "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    )
  );
  const player2Key = normalizePrivateKey(
    loadEnv(
      "PLAYER2_PRIVATE_KEY",
      "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
    )
  );
  const chainId = Number(loadEnv("CHAIN_ID", `${DEFAULT_CHAIN_ID}`));
  const cliquePeriod = Number(loadEnv("CLIQUE_PERIOD", `${DEFAULT_CLIQUE_PERIOD}`));

  const adminAddress = new ethers.Wallet(adminKey).address;
  const player1Address = new ethers.Wallet(player1Key).address;
  const player2Address = new ethers.Wallet(player2Key).address;

  return {
    config: {
      chainId,
      homesteadBlock: 0,
      eip150Block: 0,
      eip155Block: 0,
      eip158Block: 0,
      byzantiumBlock: 0,
      constantinopleBlock: 0,
      petersburgBlock: 0,
      istanbulBlock: 0,
      muirGlacierBlock: 0,
      berlinBlock: 0,
      londonBlock: 0,
      clique: {
        period: cliquePeriod,
        epoch: 30000,
      },
      scuroBlock: 0,
    },
    nonce: "0x0",
    timestamp: "0x0",
    extraData: cliqueExtraData(adminAddress),
    gasLimit: "0x1c9c380",
    difficulty: "0x1",
    mixHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    coinbase: "0x0000000000000000000000000000000000000000",
    alloc: {
      [adminAddress]: { balance: DEFAULT_BALANCE },
      [player1Address]: { balance: DEFAULT_BALANCE },
      [player2Address]: { balance: DEFAULT_BALANCE },
      [REGISTRY_ADDRESS]: {
        balance: "0x0",
        code: registryRuntimeBytecode(),
        storage: roleStorage(adminAddress),
      },
    },
    number: "0x0",
    gasUsed: "0x0",
    parentHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    baseFeePerGas: "0x3b9aca00",
  };
}

function main() {
  const outputPath = process.argv[2] || process.env.GENESIS_OUTPUT;
  const genesis = renderGenesis();
  const encoded = `${JSON.stringify(genesis, null, 2)}\n`;

  if (outputPath) {
    fs.writeFileSync(outputPath, encoded);
    return;
  }

  process.stdout.write(encoded);
}

main();
