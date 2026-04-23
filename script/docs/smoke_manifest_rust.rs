use std::fs;

fn main() {
    let raw = fs::read_to_string("docs/generated/protocol-manifest.json")
        .expect("manifest should be readable");

    for needle in [
        "\"contracts\"",
        "\"enum_labels\"",
        "\"ProtocolSettlement\"",
        "\"SlotMachineController\"",
        "\"SlotMachineEngine\"",
    ] {
        assert!(raw.contains(needle), "manifest missing {}", needle);
    }

    println!("rust manifest smoke passed");
}
