"""Run the safe DAST pass and write automated_test/report.json."""

from __future__ import annotations

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories()
    print_summary(records)
