"""
Divvy e-bike analysis: generate all three figures.

Run from the project root:
    python make_charts.py

Requires:
    - divvy.duckdb with table trips_raw
    - sql/04_reversal_ranking.sql (the reversal ranking query)
"""

import os
import re

import duckdb
import matplotlib.pyplot as plt


# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

con = duckdb.connect("divvy.duckdb")
os.makedirs("outputs", exist_ok=True)

BLUE = "#1f77b4"     # morning peak
ORANGE = "#ff7f0e"   # evening peak / e-bike highlight
GRAY = "#b0b0b0"     # de-emphasized category
SOURCE_NOTE = "Data: Divvy trips, August 2026."


def finish(fig, ax, path, note=SOURCE_NOTE):
    """Shared styling: hide top/right spines, add source note, save."""
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.text(0.01, 0.01, note, fontsize=8, color="gray")
    plt.tight_layout(rect=[0, 0.03, 1, 1])
    plt.savefig(path, dpi=200, bbox_inches="tight")
    plt.close(fig)


# ============================================================
# FIGURE 1: Station coverage by bike type
# ============================================================

coverage_by_bike = con.execute("""
SELECT
    rideable_type,
    COUNT(*) AS total_rides,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN start_station_id IS NOT NULL
                 AND end_station_id IS NOT NULL
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS station_coverage_pct
FROM trips_raw
WHERE rideable_type IN ('classic_bike', 'electric_bike')
GROUP BY rideable_type;
""").fetchdf()

labels = {"classic_bike": "Classic bike", "electric_bike": "Electric bike"}
order = {"classic_bike": 1, "electric_bike": 2}   # classic at bottom, e-bike on top
colors = {"classic_bike": GRAY, "electric_bike": ORANGE}

coverage_by_bike["bike_label"] = coverage_by_bike["rideable_type"].map(labels)
coverage_by_bike["sort_order"] = coverage_by_bike["rideable_type"].map(order)
coverage_by_bike = coverage_by_bike.sort_values("sort_order")

fig, ax = plt.subplots(figsize=(8, 4.5))

bars = ax.barh(
    coverage_by_bike["bike_label"],
    coverage_by_bike["station_coverage_pct"],
    color=coverage_by_bike["rideable_type"].map(colors),
)

for bar, pct, n in zip(
    bars,
    coverage_by_bike["station_coverage_pct"],
    coverage_by_bike["total_rides"],
):
    ax.text(
        pct + 1,
        bar.get_y() + bar.get_height() / 2,
        f"{pct:.1f}%  ({n:,} trips)",
        va="center",
    )

ax.set_xlim(0, 130)
ax.set_xlabel("Trips with identifiable stations at both ends (%)")
ax.set_ylabel("")
ax.set_title(
    "Station Coverage Is Nearly Complete for Classic Bikes,\n"
    "but Much Lower for Electric Bikes"
)

finish(fig, ax, "outputs/01_station_coverage_by_bike.png")


# ============================================================
# FIGURE 2: Electric-bike station coverage by hour
# ============================================================

hourly_coverage = con.execute("""
SELECT
    EXTRACT(HOUR FROM started_at) AS start_hour,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN start_station_id IS NOT NULL
                 AND end_station_id IS NOT NULL
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS station_coverage_pct
FROM trips_raw
WHERE rideable_type = 'electric_bike'
GROUP BY start_hour
ORDER BY start_hour;
""").fetchdf()

# Overall e-bike coverage, computed from the data (not hard-coded)
ebike_avg = con.execute("""
SELECT
    ROUND(
        100.0 * SUM(
            CASE
                WHEN start_station_id IS NOT NULL
                 AND end_station_id IS NOT NULL
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        1
    )
FROM trips_raw
WHERE rideable_type = 'electric_bike';
""").fetchone()[0]

fig, ax = plt.subplots(figsize=(10, 5))

# Peak-period shading, matching the windows used in Figure 3
ax.axvspan(6, 9.99, color=BLUE, alpha=0.08)
ax.axvspan(16, 19.99, color=ORANGE, alpha=0.08)

ax.plot(
    hourly_coverage["start_hour"],
    hourly_coverage["station_coverage_pct"],
    marker="o",
    linewidth=2,
    color=BLUE,
)

# Overall e-bike average
ax.axhline(ebike_avg, color="gray", linestyle="--", linewidth=1)
ax.text(23.3, ebike_avg + 0.4, f"E-bike avg {ebike_avg:.1f}%",
        fontsize=8, color="gray", ha="right")

ax.set_xticks(range(0, 24, 2))
ax.set_ylim(40, 63)
ax.grid(axis="y", alpha=0.25)

ax.text(8, 62.2, "Morning peak", fontsize=8, ha="center", color=BLUE)
ax.text(18, 62.2, "Evening peak", fontsize=8, ha="center", color=ORANGE)

highest = hourly_coverage.loc[hourly_coverage["station_coverage_pct"].idxmax()]
lowest = hourly_coverage.loc[hourly_coverage["station_coverage_pct"].idxmin()]

ax.annotate(
    f"{int(highest['start_hour'])}:00 | {highest['station_coverage_pct']:.1f}%",
    xy=(highest["start_hour"], highest["station_coverage_pct"]),
    xytext=(highest["start_hour"] + 2.5, highest["station_coverage_pct"] - 1.5),
    arrowprops={"arrowstyle": "->"},
)
ax.annotate(
    f"{int(lowest['start_hour'])}:00 | {lowest['station_coverage_pct']:.1f}%",
    xy=(lowest["start_hour"], lowest["station_coverage_pct"]),
    xytext=(lowest["start_hour"] + 1.5, lowest["station_coverage_pct"] + 0.5),
    arrowprops={"arrowstyle": "->"},
)

ax.set_xlabel("Trip start hour")
ax.set_ylabel("Station-to-station coverage (%)")
ax.set_title(
    "Electric-Bike Station Coverage Peaks in the Morning\n"
    "and Declines Late at Night"
)

finish(
    fig, ax,
    "outputs/02_ebike_station_coverage_by_hour.png",
    note=SOURCE_NOTE + " Y-axis starts at 40% to show variation across hours.",
)


# ============================================================
# FIGURE 3: Top stations by morning-evening reversal
# ============================================================

with open("sql/04_station_reversal.sql", encoding="utf-8") as f:
    reversal = con.execute(f.read()).fetchdf()

TOP_N = 8
top = reversal.head(TOP_N).copy()


def short_name(name):
    """'Franklin St & Monroe St' -> 'Franklin & Monroe'."""
    name = re.sub(r"\s(St|Ave|Blvd|Dr|Rd|Plaza)\b", "", name)
    name = re.sub(r"\s\d+$", "", name)   # drop trailing '1', '2'
    return name


top["label"] = top["station_name"].apply(short_name)

pivot = (
    top.set_index("label")[["morning_net_flow", "evening_net_flow"]]
    .rename(columns={
        "morning_net_flow": "Morning peak (6–10 AM)",
        "evening_net_flow": "Evening peak (4–8 PM)",
    })
)

fig, ax = plt.subplots(figsize=(9, 7))

pivot.plot(kind="barh", ax=ax, color=[BLUE, ORANGE], width=0.75)

ax.axvline(0, color="black", linewidth=0.8)   # no label -> not in legend

for container in ax.containers:
    ax.bar_label(container, fmt="%+d", padding=3, fontsize=9)

ax.invert_yaxis()   # rank 1 at the top

left = pivot.min().min() * 1.3
right = pivot.max().max() * 1.35
ax.set_xlim(left, right)

ax.set_xlabel("Net flow (arrivals − departures)")
ax.set_ylabel("")
ax.set_title(
    f"Top {TOP_N} Stations by Morning–Evening Reversal\n"
    "(morning net inflow minus evening net outflow)"
)
ax.legend(title="", loc="lower right")

finish(
    fig, ax,
    "outputs/03_morning_evening_reversal.png",
    note=SOURCE_NOTE + " Positive = more arrivals than departures.",
)


# ------------------------------------------------------------
# Done
# ------------------------------------------------------------

con.close()
print("All three figures saved to outputs/")