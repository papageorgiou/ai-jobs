"""Validate, clean and deduplicate the raw get_volumes response."""

import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

import config  # noqa: E402

sys.path.append(config.ADS_API_DIR)
from pyevangelion_powerfuncs_ai import get_final_res_df  # noqa: E402

# Two rows describe the same underlying keyword when all of these match. The
# keyword string is deliberately excluded - it is the value being compared, not
# part of the identity.
IDENTITY = ["searches_past_months", "avg_monthly_searches",
            "competition_index", "high_top_bid", "low_top_bid"]


def main():
    results = pd.read_pickle(config.out("full_results.pkl"))
    summary = pd.read_csv(config.out("full_summary.csv"))

    ok = (summary["exception"] == "success").mean() * 100
    print(f"success rate: {ok:.1f}%")
    bad = summary[(summary["exception"] != "success") | (summary["length_of_results"] == 0)]
    if not bad.empty:
        print(f"failed/empty calls:\n{bad}")
    if ok < 95:
        print("WARNING: success rate below 95%")

    df = get_final_res_df(results)
    df.columns = [c.lower().replace(" ", "_") for c in df.columns]
    print(f"flattened to {len(df)} keyword rows")

    plt.figure(figsize=(8, 4))
    plt.hist(summary["length_of_results"], bins=50, range=(0, 1100))
    plt.xlabel("keywords returned per call")
    plt.savefig(config.out("response_distribution.png"), dpi=100, bbox_inches="tight")
    plt.close()

    df["searches_past_months"] = df["searches_past_months"].map(
        lambda v: list(v) if isinstance(v, (list, tuple)) else [])

    # Drop no-data keywords BEFORE asserting length. They come back with an
    # empty series by design, so an unconditional 48-month assert would fail on
    # them even though nothing is wrong.
    empty = df["searches_past_months"].str.len() == 0
    print(f"dropping {empty.sum()} keywords with no search data (expected)")
    df = df[~empty].copy()

    lengths = df["searches_past_months"].str.len()
    if not (lengths == config.N_MONTHS).all():
        raise SystemExit(
            f"{(lengths != config.N_MONTHS).sum()} rows have a malformed series; "
            f"lengths found: {sorted(lengths.unique())}")
    print(f"all {len(df)} remaining series are {config.N_MONTHS} months")

    # Collapse identical series - near-synonyms such as "ai engineer" and
    # "artificial intelligence engineer" often resolve to one underlying series.
    key = df[IDENTITY].copy()
    key["searches_past_months"] = key["searches_past_months"].map(tuple)
    df["_key"] = list(map(tuple, key.itertuples(index=False, name=None)))

    df["_len"] = df["keyword"].str.len()
    df = df.sort_values(["_key", "_len", "keyword"])
    winners = df.groupby("_key", sort=False).head(1)

    equivalents = (df.groupby("_key")["keyword"].apply(list).rename("equivalents")
                   .reset_index()
                   .merge(winners[["_key", "keyword"]], on="_key")
                   .rename(columns={"keyword": "winner"}))
    equivalents["equivalents"] = equivalents.apply(
        lambda r: [k for k in r["equivalents"] if k != r["winner"]], axis=1)
    equivalents[equivalents["equivalents"].str.len() > 0][["winner", "equivalents"]] \
        .to_parquet(config.out("identicals_db.parquet"))

    dropped = len(df) - len(winners)
    print(f"dropped {dropped} keywords with a series identical to another")
    df = winners.drop(columns=["_key", "_len"])

    zero = df["avg_monthly_searches"] == 0
    print(f"dropping {zero.sum()} keywords with zero average volume")
    df = df[~zero]

    df = df.drop_duplicates(subset="keyword", keep="first")
    df = df[["keyword", "avg_monthly_searches", "searches_past_months"]] \
        .sort_values("avg_monthly_searches", ascending=False).reset_index(drop=True)

    df.to_parquet(config.out("df_clean.parquet"))
    df.to_csv(config.out("df_clean.csv"), index=False)

    print(f"\nclean dataset: {len(df)} keywords")
    print("\ntop 20 by average monthly searches:")
    print(df.head(20)[["keyword", "avg_monthly_searches"]].to_string(index=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
