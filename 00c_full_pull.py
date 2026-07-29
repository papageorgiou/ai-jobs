"""Full get_volumes pull for the AI job-title keyword universe.

This run is a single batch, but the sharded/resumable structure is kept anyway:
it makes a rerun free (already-completed batches are skipped) and means the
script does not need rewriting if the keyword list later outgrows one request.
"""

import ast
import os
import sys
from pathlib import Path

for _ca in ("/etc/ssl/certs/ca-certificates.crt",
            "/etc/pki/tls/certs/ca-bundle.crt"):
    if os.path.exists(_ca):
        os.environ.setdefault("GRPC_DEFAULT_SSL_ROOTS_FILE_PATH", _ca)
        break

import pandas as pd  # noqa: E402

import config  # noqa: E402

sys.path.append(config.ADS_API_DIR)

from google.ads.googleads.client import GoogleAdsClient  # noqa: E402
from kwideas_funcs import get_volumes  # noqa: E402
from pyevangelion_powerfuncs_ai import (  # noqa: E402
    get_summary_table, process_row_arg_dicts_simple,
)


def main():
    arg_df = pd.read_csv(config.out("arg_df_gapi.csv"))
    # kw_list survives the CSV round-trip as a string repr of a list.
    arg_df["kw_list"] = arg_df["kw_list"].map(ast.literal_eval)
    arg_dicts = arg_df.to_dict(orient="records")

    shards = Path(config.out("shards"))
    shards.mkdir(parents=True, exist_ok=True)
    done = {int(p.stem.split("_")[1]) for p in shards.glob("batch_*.pkl")}

    start_batch = int(sys.argv[sys.argv.index("--start-batch") + 1]) \
        if "--start-batch" in sys.argv else 0
    todo = [(i, d) for i, d in enumerate(arg_dicts)
            if i not in done and i >= start_batch]

    n_kw = sum(len(d["kw_list"]) for _, d in todo)
    print(f"{len(arg_dicts)} batches total, {len(done)} already on disk, "
          f"{len(todo)} to run ({n_kw:,} keywords)")
    if not todo:
        print("nothing to do")
    else:
        client = GoogleAdsClient.load_from_storage(config.ADS_YAML_PATH)
        for i, argd in todo:
            res = process_row_arg_dicts_simple([argd], get_volumes, client=client)
            pd.to_pickle(res, shards / f"batch_{i:05d}.pkl")
            print(f"  shard {i} written")

    # Concatenate every shard - including ones from earlier runs - into the
    # artifacts 01_clean.py consumes.
    results = []
    for p in sorted(shards.glob("batch_*.pkl")):
        results.extend(pd.read_pickle(p))

    pd.to_pickle(results, config.out("full_results.pkl"))
    get_summary_table(results).to_csv(config.out("full_summary.csv"), index=False)
    print(f"\nwrote full_results.pkl ({len(results)} result rows) and full_summary.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
