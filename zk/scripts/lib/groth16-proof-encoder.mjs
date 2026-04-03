function pad32(value) {
  return BigInt(value).toString(16).padStart(64, "0");
}

export function encodeGroth16Proof(proof) {
  const words = [
    proof.pi_a[0],
    proof.pi_a[1],
    proof.pi_b[0][1],
    proof.pi_b[0][0],
    proof.pi_b[1][1],
    proof.pi_b[1][0],
    proof.pi_c[0],
    proof.pi_c[1]
  ];

  return `0x${words.map((value) => pad32(value)).join("")}`;
}
