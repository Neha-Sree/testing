"""Run only the hardcoded credentials DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["hardcoded_creds"])
    print_summary(records)
