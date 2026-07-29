"""Rolling average, trend model and growth metrics per keyword."""

import re
import sys

import numpy as np
import pandas as pd
from scipy import stats

import config

sys.path.append(config.ADS_API_DIR)
from pyevangelion_powerfuncs_ai import get_final_res_df  # noqa: E402


def resolve_start():
    """First month of the 48-month window, as a Timestamp.

    kwideas_funcs encodes past_months as f"{month-1}-{year}", so "5-2022" means
    June 2022, not May. A naive parse silently lands a month early, so the +1
    correction here is load-bearing.
    """
    df = get_final_res_df(pd.read_pickle(config.out("full_results.pkl")))
    df.columns = [c.lower().replace(" ", "_") for c in df.columns]
    full = df[df["past_months"].map(lambda v: len(v) if hasattr(v, "__len__") else 0)
              == config.N_MONTHS]
    if full.empty:
        raise SystemExit("no row with a full past_months series to derive the start date")
    first = list(full.iloc[0]["past_months"])[0]
    month, year = re.match(r"(\d+)-(\d+)", str(first)).groups()
    return pd.Timestamp(int(year), int(month) + 1, 1)   # +1: see docstring


def main():
    df = pd.read_parquet(config.out("df_clean.parquet"))
    start = resolve_start()
    months = pd.date_range(start, periods=config.N_MONTHS, freq="MS")
    print(f"window: {months[0]:%Y-%m} to {months[-1]:%Y-%m} ({len(months)} months)")
    assert len(months) == config.N_MONTHS

    long = df.explode("searches_past_months").rename(
        columns={"searches_past_months": "searches"})
    long["searches"] = pd.to_numeric(long["searches"])
    long["month_counter"] = long.groupby("keyword").cumcount() + 1
    long["month"] = months[long["month_counter"] - 1]

    n0 = long["keyword"].nunique()

    # Drop leading zero months: a keyword that only starts existing part-way
    # through the window should be modelled from its first real month, not from
    # a run of structural zeros that would flatten its slope.
    long["seen"] = long.groupby("keyword")["searches"].transform(
        lambda s: (s > 0).cummax())
    long = long[long["seen"]].drop(columns="seen")

    agg = long.groupby("keyword")["searches"].agg(["max", lambda s: (s == 0).sum()])
    agg.columns = ["peak", "zero_months"]
    keep = agg[(agg["peak"] > config.MIN_PEAK_SEARCHES)
               & (agg["zero_months"] < config.MAX_ZERO_MONTHS)].index
    long = long[long["keyword"].isin(keep) & long["keyword"].notna()
                & (long["keyword"] != "")]
    print(f"modelable keywords: {long['keyword'].nunique()} of {n0} "
          f"(dropped peak<={config.MIN_PEAK_SEARCHES} or near-all-zero)")

    long = long.sort_values(["keyword", "month_counter"])
    long["roll_avg"] = (long.groupby("keyword")["searches"]
                        .transform(lambda s: s.rolling(config.ROLL_WINDOW,
                                                       min_periods=1).mean())
                        .round().astype(int))
    long.to_parquet(config.out("rolling.parquet"))

    rows, spikes = [], []
    w = config.GROWTH_WINDOW
    for kw, g in long.groupby("keyword"):
        g = g.sort_values("month_counter")
        res = stats.linregress(g["month_counter"], g["roll_avg"])

        s = g["searches"].to_numpy()
        first, last = s[:w].mean(), s[-w:].mean()
        # Guard the ratio: a keyword whose first window is all zeros would
        # otherwise produce an infinite growth rate.
        pct = (last - first) / first if first > 0 else np.nan
        rows.append({
            "keyword": kw,
            "avg_monthly_searches": g["avg_monthly_searches"].iloc[0],
            "slope": res.slope,
            "r_squared": res.rvalue ** 2,
            "first_window": first,
            "last_window": last,
            "pct_change": pct,
            "net_change": last - first,
            "n_months": len(g),
        })

        med = np.median(s[s > 0]) if (s > 0).any() else 0
        if med > 0 and s.max() / med >= config.SPIKE_RATIO:
            peak_month = g.iloc[int(s.argmax())]["month"]
            same_month = g[(g["month"].dt.month == peak_month.month)
                           & (g["month"] != peak_month)]["searches"]
            # Seasonal if the same calendar month spikes in other years too.
            if same_month.empty or (same_month.max() < 0.5 * s.max()):
                spikes.append({"keyword": kw, "spike_month": peak_month,
                               "spike_ratio": s.max() / med,
                               "avg_monthly_searches": g["avg_monthly_searches"].iloc[0]})

    st = pd.DataFrame(rows)
    st = st[np.isfinite(st["slope"]) & np.isfinite(st["r_squared"])]

    # Percentile ranks put a fast-growing niche term and a big steady one on the
    # same scale; averaging them is the growth-rate vs net-volume balance.
    st["pct_rank"] = st["pct_change"].rank(pct=True)
    st["net_rank"] = st["net_change"].rank(pct=True)
    st["momentum"] = st[["pct_rank", "net_rank"]].mean(axis=1)

    st["slope"] = st["slope"].round().astype(int)
    st["r_squared"] = st["r_squared"].round(2)
    st.sort_values("momentum", ascending=False).to_parquet(
        config.out("kw_trend_stats.parquet"))

    sp = pd.DataFrame(spikes)
    if not sp.empty:
        sp["pct_of_total_volume"] = (sp["avg_monthly_searches"]
                                     / st["avg_monthly_searches"].sum())
        sp = sp.sort_values("spike_ratio", ascending=False)
    sp.to_parquet(config.out("spikes_flagged.parquet"))

    print(f"\ntrend stats for {len(st)} keywords; {len(sp)} non-seasonal spikes flagged")
    print("\ntop 15 by momentum (growth rate + net volume balanced):")
    cols = ["keyword", "avg_monthly_searches", "pct_change", "net_change", "r_squared"]
    print(st.sort_values("momentum", ascending=False).head(15)[cols]
          .to_string(index=False, float_format=lambda v: f"{v:,.2f}"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
