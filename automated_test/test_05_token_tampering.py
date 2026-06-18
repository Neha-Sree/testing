"""Run only the token tampering DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["token_tampering"])
    print_summary(records)
