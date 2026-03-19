from __future__ import annotations

import unittest

from analysis.slot_ev.preset_loader import DEFAULT_FIXTURE_PATH, load_preset
from analysis.slot_ev.simulator import simulate_many, simulate_spin

try:
    from hypothesis import given
    from hypothesis import strategies as st
except ImportError:  # pragma: no cover - optional dependency
    given = None
    st = None


PRESET = load_preset(4, DEFAULT_FIXTURE_PATH)


class SlotSimulatorTest(unittest.TestCase):
    def test_same_seed_produces_same_result(self) -> None:
        outcome_a = simulate_spin(PRESET, 42)
        outcome_b = simulate_spin(PRESET, 42)
        self.assertEqual(outcome_a, outcome_b)

    def test_many_report_respects_caps(self) -> None:
        report = simulate_many(PRESET, sample_size=64, base_seed=7)
        self.assertLessEqual(report["max_observed_event_count"], PRESET["maxTotalEvents"])
        self.assertGreater(report["performance"]["spins_per_second"], 0)


if given is not None and st is not None:
    class SlotSimulatorPropertyTest(unittest.TestCase):
        @given(st.integers(min_value=1, max_value=2**32 - 1))
        def test_determinism_property(self, seed: int) -> None:
            outcome_a = simulate_spin(PRESET, seed)
            outcome_b = simulate_spin(PRESET, seed)
            self.assertEqual(outcome_a, outcome_b)


if __name__ == "__main__":
    unittest.main()
