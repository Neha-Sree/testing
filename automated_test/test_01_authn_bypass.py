"""Run only the AuthN bypass DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["authn_bypass"])
    print_summary(records)
