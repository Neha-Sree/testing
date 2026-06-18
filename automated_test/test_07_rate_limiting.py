"""Run only the rate limiting DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["rate_limiting"])
    print_summary(records)
