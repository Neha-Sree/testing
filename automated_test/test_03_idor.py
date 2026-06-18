"""Run only the IDOR DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["idor"])
    print_summary(records)
