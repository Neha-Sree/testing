"""Run only the RBAC matrix DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["rbac_matrix"])
    print_summary(records)
