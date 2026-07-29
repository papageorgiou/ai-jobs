"""Shared constants for the AI job-title search-volume pipeline.

All paths go through os.environ.get(NAME, fallback) so the same scripts run
unchanged on macOS, Codespaces or CI by setting env vars. The fallbacks are
cwd-relative, so run every script from the project root.
"""

import os

# --- Google Ads query scope ---------------------------------------------------
# get_volumes takes location_ids as a single string, not a list.
LOCATION_ID = "2840"      # United States
LANGUAGE_ID = "1000"      # English
N_MONTHS = 48             # four years; the API clamps its baked 2016-2030 range to this

# --- Paths --------------------------------------------------------------------
ADS_YAML_PATH = os.environ.get("ADS_YAML_PATH", "../ads-api/ads.yaml")
ADS_API_DIR = os.environ.get("ADS_API_DIR", "../ads-api/")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "output/")

# --- Input --------------------------------------------------------------------
MASTER_CSV = os.environ.get("MASTER_CSV", "ai_job_titles_master.csv")

# get_volumes accepts up to 10,000 keywords per request.
KW_BATCH_SIZE = 10_000

# --- Preflight ----------------------------------------------------------------
# "weather" ground-truthed from a real Keyword Planner export (US/English,
# 2026-06-18). Keyword Planner reports rounded buckets, so never expect an exact
# figure - accept anything within 0.25x-4x.
TEST_KEYWORDS = ["weather"]
TEST_LOCATION_ID = "2840"
TEST_LANGUAGE_ID = "1000"
TEST_REFERENCE_VOLUME = 124_000_000

# --- Analysis thresholds ------------------------------------------------------
# Standard filters from the get-search-data skill. Series whose biggest month is
# <= 20 are mostly Keyword Planner rounding noise, so trends fitted to them are
# not meaningful.
MIN_PEAK_SEARCHES = 20
MAX_ZERO_MONTHS = 47
ROLL_WINDOW = 3
SPIKE_RATIO = 5.0

# Growth is measured by comparing the mean of the last GROWTH_WINDOW months with
# the mean of the first GROWTH_WINDOW months. A 12-month window makes the
# comparison robust to seasonality.
GROWTH_WINDOW = 12


def out(name: str) -> str:
    """Path inside OUTPUT_DIR, creating the directory on first use."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    return os.path.join(OUTPUT_DIR, name)
