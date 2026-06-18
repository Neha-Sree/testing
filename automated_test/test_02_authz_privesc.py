"""Run only the AuthZ / privilege escalation DAST category."""

from safe_dast_suite import run_categories, print_summary


if __name__ == "__main__":
    records = run_categories(["authz_privesc"])
    print_summary(records)
