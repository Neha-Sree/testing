"""Run only the injection probe DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["injection_probe"])
    print_summary(records)
