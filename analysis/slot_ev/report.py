from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .preset_loader import DEFAULT_FIXTURE_PATH, load_preset, load_presets
from .simulator import simulate_many


ROOT = Path(__file__).resolve().parent
DEFAULT_THRESHOLDS_PATH = ROOT / "thresholds.json"


def _load_thresholds(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def _build_warnings(report: dict[str, Any], preset: dict[str, Any], thresholds: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    if abs(report["ev_deviation"]) > thresholds["max_abs_ev_deviation"]:
        warnings.append(
            f"EV deviation {report['ev_deviation']:.4f} exceeds threshold {thresholds['max_abs_ev_deviation']:.4f}"
        )
    if report["sample_size"] < thresholds["min_samples_per_preset"]:
        warnings.append(
            f"sample size {report['sample_size']} is below threshold {thresholds['min_samples_per_preset']}"
        )
    if preset["maxTotalEvents"] > thresholds["max_event_cap"]:
        warnings.append(
            f"preset maxTotalEvents {preset['maxTotalEvents']} exceeds advisory threshold {thresholds['max_event_cap']}"
        )
    return warnings


def _markdown_summary(report: dict[str, Any], warnings: list[str]) -> str:
    lines = [
        f"## Preset {report['preset_id']}",
        "",
        f"- `configHash`: `{report['config_hash']}`",
        f"- `volatilityTier`: `{report['volatility_tier']}`",
        f"- `sampleSize`: `{report['sample_size']}`",
        f"- `evRatio`: `{report['ev_ratio']:.6f}`",
        f"- `evDeviation`: `{report['ev_deviation']:.6f}`",
        f"- `stddev`: `{report['stddev']:.6f}`",
        f"- `hitRate`: `{report['hit_rate']:.6f}`",
        f"- `freeSpins`: `{report['bonus_trigger_frequency']['free_spins']:.6f}`",
        f"- `pickBonus`: `{report['bonus_trigger_frequency']['pick_bonus']:.6f}`",
        f"- `holdAndSpin`: `{report['bonus_trigger_frequency']['hold_and_spin']:.6f}`",
        f"- `maxObservedPayout`: `{report['max_observed_payout']}`",
        f"- `maxObservedEventCount`: `{report['max_observed_event_count']}`",
        f"- `confidence95`: `{report['confidence_interval_95'][0]:.6f}` to `{report['confidence_interval_95'][1]:.6f}`",
        f"- `spinsPerSecond`: `{report['performance']['spins_per_second']:.2f}`",
    ]
    if warnings:
        lines.append("- `warnings`:")
        lines.extend([f"  - {warning}" for warning in warnings])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate report-first EV analysis for slot presets.")
    parser.add_argument("--preset", default="all", help="Preset id or config hash. Use 'all' to analyze every fixture preset.")
    parser.add_argument("--fixture", default=str(DEFAULT_FIXTURE_PATH), help="Path to ABI-shaped preset fixture JSON.")
    parser.add_argument("--samples", type=int, default=10_000, help="Number of Monte Carlo spins per preset.")
    parser.add_argument("--seed", type=int, default=1, help="Base RNG seed for deterministic report generation.")
    parser.add_argument("--stake", type=int, default=10**18, help="Stake used for each simulated spin.")
    parser.add_argument("--json-out", default="", help="Optional path for machine-readable JSON output.")
    parser.add_argument("--markdown-out", default="", help="Optional path for human-readable markdown output.")
    args = parser.parse_args()

    thresholds = _load_thresholds(DEFAULT_THRESHOLDS_PATH)
    fixture_path = Path(args.fixture)

    if args.preset == "all":
        selected = list(load_presets(fixture_path).values())
    else:
        selected = [load_preset(args.preset, fixture_path)]

    reports = []
    markdown_sections = []
    for preset in selected:
        report = simulate_many(
            preset,
            sample_size=args.samples,
            base_seed=args.seed + preset["presetId"],
            stake=args.stake,
            target_ev_ratio=thresholds["target_ev_ratio"],
        )
        warnings = _build_warnings(report, preset, thresholds)
        report["warnings"] = warnings
        reports.append(report)
        markdown_sections.append(_markdown_summary(report, warnings))

    payload = {"fixture": str(fixture_path), "reports": reports}
    markdown = "\n\n".join(markdown_sections)

    if args.json_out:
        Path(args.json_out).write_text(json.dumps(payload, indent=2, sort_keys=True))
    if args.markdown_out:
        Path(args.markdown_out).write_text(markdown + "\n")

    print(json.dumps(payload, indent=2, sort_keys=True))
    print()
    print(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
