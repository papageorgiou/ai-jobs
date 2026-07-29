"""Required gate before the full pull.

Proves credentials, network, CA trust, quota tier and 48-month wiring in a few
seconds, so a misconfiguration fails here rather than part-way through a real
pull. Exercises get_volumes - the same entry point the full pull uses - so the
exact code path is validated rather than a neighbouring one.
"""

import os
import sys

# gRPC bundles its own CA roots and ignores SSL_CERT_FILE, so behind a
# self-signed egress proxy it rejects the cert and every call hangs through the
# full retry sequence. Point it at the system bundle, but only if that bundle
# exists - otherwise gRPC prints a noisy load error on every run (e.g. macOS,
# where neither path is present).
for _ca in ("/etc/ssl/certs/ca-certificates.crt",   # Debian/Ubuntu
            "/etc/pki/tls/certs/ca-bundle.crt"):    # RHEL/Fedora
    if os.path.exists(_ca):
        os.environ.setdefault("GRPC_DEFAULT_SSL_ROOTS_FILE_PATH", _ca)
        break

import config

sys.path.append(config.ADS_API_DIR)

from google.ads.googleads.client import GoogleAdsClient  # noqa: E402
from kwideas_funcs import get_volumes  # noqa: E402
from pyevangelion_powerfuncs_ai import (  # noqa: E402
    get_final_res_df, get_summary_table, process_row_arg_dicts_simple,
)


def fail(msg):
    print(f"PREFLIGHT FAILED: {msg}")
    return 1


def main():
    # 1. Credentials load.
    try:
        client = GoogleAdsClient.load_from_storage(config.ADS_YAML_PATH)
    except Exception as exc:
        return fail(f"could not load credentials from {config.ADS_YAML_PATH}: {exc}")
    print("1/3 credentials loaded")

    # 2. One real call through the same function the full pull uses.
    arg_dicts = [{
        "kw_list": config.TEST_KEYWORDS,
        "start": 0,
        "finish": len(config.TEST_KEYWORDS),
        "location_ids": config.TEST_LOCATION_ID,
        "language_id": config.TEST_LANGUAGE_ID,
        "iteration": 1,
    }]
    try:
        results = process_row_arg_dicts_simple(arg_dicts, get_volumes, client=client)
    except Exception as exc:
        return fail(f"API call raised: {exc}\n"
                    "A hang-then-fail here is the gRPC/proxy CA problem.")
    print("2/3 API call returned")

    import pandas as pd
    pd.to_pickle(results, config.out("preflight_results.pkl"))
    get_summary_table(results).to_csv(config.out("preflight_summary.csv"), index=False)

    # 3. Response sanity - real, correctly-scaled data rather than zeros.
    df = get_final_res_df(results)
    row = df[df["keyword"] == "weather"]
    if row.empty:
        return fail(f"no 'weather' row in the response (got {len(df)} rows)")
    row = row.iloc[0]

    vol = row["avg_monthly_searches"]
    lo, hi = config.TEST_REFERENCE_VOLUME * 0.25, config.TEST_REFERENCE_VOLUME * 4
    if not lo <= vol <= hi:
        return fail(f"'weather' volume {vol:,} outside {lo:,.0f}-{hi:,.0f}. "
                    "Location/language wiring is likely wrong.")

    series = row["searches_past_months"]
    if len(series) != config.N_MONTHS:
        return fail(f"'weather' series has {len(series)} months, expected {config.N_MONTHS}")
    if not any(series):
        return fail("'weather' series is all zeros")

    print(f"3/3 sanity ok - weather = {vol:,}/mo, {len(series)} months")
    print("\nPreflight passed - safe to run the full pull.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
