from __future__ import annotations

import unittest

from analysis.slot_ev.preset_loader import DEFAULT_FIXTURE_PATH, load_preset, load_presets


class PresetLoaderTest(unittest.TestCase):
    def test_load_presets_returns_expected_fixture_ids(self) -> None:
        presets = load_presets(DEFAULT_FIXTURE_PATH)
        self.assertEqual(set(presets), {1, 2, 3, 4})
        self.assertEqual(presets[1]["configHash"], "0xf1f3eb40f5bc1ad1344716ced8b8a0431d840b5783aea1fd01786bc26f35ac0f")

    def test_load_preset_supports_id_and_hash_lookup(self) -> None:
        by_id = load_preset(3, DEFAULT_FIXTURE_PATH)
        by_hash = load_preset("0xccdf4588aee8626420140e6351c1da88c4fba6d94cac2bc0cc2c122399da74c0", DEFAULT_FIXTURE_PATH)
        self.assertEqual(by_id["presetId"], 3)
        self.assertEqual(by_id["configHash"], by_hash["configHash"])


if __name__ == "__main__":
    unittest.main()
