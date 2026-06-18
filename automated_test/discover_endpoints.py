"""Discovery step for the DAST pass.

Prints the route inventory and writes a savepoint so later category runners can
reuse the same catalog.
"""

from __future__ import annotations

from dast_common import discover_routes_from_main, filter_discovery_scope, route_catalog_as_dicts, write_savepoint


def main() -> None:
    routes = filter_discovery_scope(discover_routes_from_main())
    payload = {
        "completed": False,
        "timestamp": None,
        "total_tests": 0,
        "routes": route_catalog_as_dicts(routes),
    }
    write_savepoint(payload)

    print(f"Discovered {len(routes)} endpoints (excluding /health, /actuator, /metrics):")
    print(f"{'METHOD':<8} {'PATH'}")
    print("-" * 80)
    for route in routes:
        print(f"{route.method:<8} {route.path}")


if __name__ == "__main__":
    main()
