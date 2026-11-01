"""Payments Optimization: data generator.

Follows docs/data_generation_rulebook.md (v4) exactly. Run from the repo root:

    python python/generate_data.py

Writes:
  data/raw/*.csv              six source tables (what the pipeline reads)
  data/answers/answers.json   hidden answer file (dbt and the dashboard must never read it)

The seed is fixed, so the same code, the same package versions (python/requirements.txt)
and the same machine give identical files.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 20250925
RULEBOOK_VERSION = "v4"

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
ANSWER_FILE = ROOT / "data" / "answers" / "answers.json"

DAYS = pd.date_range("2025-01-01", "2025-12-31", freq="D")
PULL_DATE = pd.Timestamp("2026-01-31")  # data "pulled" on this day
DISPUTE_FEE_EUR = 20.0
EU_CARDS = ["NL", "DE", "FR", "ES"]
BANK_IDS = {"NL": "BNK_NL", "DE": "BNK_DE", "FR": "BNK_FR"}

# ---------------------------------------------------------------------------
# Rulebook section 1: business types
# ---------------------------------------------------------------------------
TYPES = {
    "online_retail": dict(
        label="Online Retail", amount=("lognormal", 55, 0.8, 5, 1500),
        card_mix=(0.65, 0.25, 0.06, 0.04), credit_share=0.35, base_decline=0.07,
        three_ds_threshold=150, price=(1.6, 0.25), hours="general"),
    "travel": dict(
        label="Travel", amount=("lognormal", 380, 0.7, 40, 4000),
        card_mix=(0.40, 0.25, 0.20, 0.15), credit_share=0.60, base_decline=0.11,
        three_ds_threshold=250, price=(2.4, 0.25), hours="general"),
    "digital_subscriptions": dict(
        label="Digital Subscriptions", amount=("prices", [4.99, 9.99, 14.99, 19.99, 29.99],
                                               [0.20, 0.35, 0.25, 0.10, 0.10]),
        card_mix=(0.55, 0.25, 0.12, 0.08), credit_share=0.45, base_decline=0.10,
        three_ds_threshold=15, price=(2.4, 0.25), hours="general"),
    "food_delivery": dict(
        label="Food Delivery", amount=("lognormal", 27, 0.45, 8, 150),
        card_mix=(0.85, 0.10, 0.03, 0.02), credit_share=0.20, base_decline=0.06,
        three_ds_threshold=40, price=(1.4, 0.25), hours="food"),
}

# Share of payments per UTC hour: quiet at night, busiest 16:00-20:00; food is evening-heavy.
HOUR_WEIGHTS = {
    "general": [0.3, 0.2, 0.15, 0.1, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0, 2.2, 2.3,
                2.4, 2.3, 2.2, 2.3, 2.7, 3.0, 3.2, 3.1, 2.6, 2.0, 1.3, 0.7],
    "food": [0.2, 0.1, 0.05, 0.05, 0.05, 0.05, 0.1, 0.2, 0.3, 0.4, 0.8, 1.8,
             2.2, 1.2, 0.8, 1.2, 3.0, 4.5, 5.0, 4.0, 2.2, 1.0, 0.5, 0.3],
}

# ---------------------------------------------------------------------------
# The 24 shops (rulebook sections 1, 3, 4, 6, 7)
# business type, country, payments per year, retry group, 3DS policy, main bank,
# backup bank (8 biggest shops only), negotiated price (% , fixed EUR) or None
# ---------------------------------------------------------------------------
SHOPS = [
    ("online_retail", "NL", 17000, "A", "above_threshold", "NL", "DE", (1.1, 0.10)),
    ("online_retail", "DE", 5000, "C", "always", "DE", "FR", None),
    ("online_retail", "FR", 3000, "B", "never", "FR", None, None),
    ("online_retail", "NL", 2000, "D", "above_threshold", "NL", None, None),
    ("online_retail", "DE", 1200, "A", "always", "DE", None, None),
    ("online_retail", "FR", 700, "C", "never", "FR", None, None),
    ("travel", "FR", 11500, "B", "always", "DE", "FR", (1.8, 0.10)),
    ("travel", "NL", 4500, "D", "above_threshold", "DE", "NL", None),
    ("travel", "DE", 2500, "A", "never", "DE", None, None),
    ("travel", "FR", 1600, "C", "always", "DE", None, None),
    ("travel", "NL", 900, "A", "above_threshold", "DE", None, None),
    ("travel", "DE", 800, "D", "never", "DE", None, (1.5, 0.0)),
    ("digital_subscriptions", "NL", 7000, "D", "never", "DE", "NL", None),
    ("digital_subscriptions", "DE", 6000, "B", "above_threshold", "DE", "FR", None),
    ("digital_subscriptions", "FR", 4000, "C", "always", "DE", None, None),
    ("digital_subscriptions", "NL", 3500, "A", "never", "DE", None, (1.5, 0.0)),
    ("digital_subscriptions", "DE", 2200, "B", "always", "DE", None, None),
    ("digital_subscriptions", "FR", 1400, "D", "above_threshold", "DE", None, None),
    ("food_delivery", "DE", 13500, "D", "never", "DE", "NL", (0.9, 0.10)),
    ("food_delivery", "FR", 5500, "C", "always", "FR", "DE", None),
    ("food_delivery", "NL", 2800, "B", "above_threshold", "NL", None, None),
    ("food_delivery", "DE", 1800, "A", "never", "DE", None, None),
    ("food_delivery", "NL", 1000, "C", "above_threshold", "NL", None, None),
    ("food_delivery", "FR", 600, "B", "always", "FR", None, None),
]
RETRY_DATES = {"A": "2025-03-17", "B": "2025-06-09", "C": "2025-09-15", "D": None}
BACKUP_SHARE = 0.30

# Rulebook section 2
DECLINE_FACTORS = dict(UK=1.5, US=2.0, debit=1.2, amount_500=1.5)
TRY_AGAIN_SHARE = 0.60
BUSY_SEASON_TRY_AGAIN = 1.3  # Nov-Dec

# Rulebook section 5: bank fees by region = card country vs SHOP country
FEE_BASE = {  # (card_type, region): (pct, fixed EUR)
    ("debit", "domestic"): (0.60, 0.10), ("credit", "domestic"): (0.80, 0.10),
    ("debit", "other_eu"): (0.90, 0.10), ("credit", "other_eu"): (1.20, 0.10),
    ("debit", "non_eu"): (2.20, 0.15), ("credit", "non_eu"): (2.80, 0.15),
}
BANK_DE_SURCHARGE = 0.20
BANK_FR_CREDIT_RISE = 0.15
BANK_FR_RISE_DATE = pd.Timestamp("2025-07-01")
BANK_START = {"NL": "2019-06-01", "DE": "2023-02-01", "FR": "2021-03-01"}  # contract start

# Rulebook section 8
FRAUD_FACTORS = dict(UK=2.0, US=3.0, amount_100=1.5)

# Hidden ranges (square brackets in the rulebook). Exact values go only to the answer file.
HIDDEN_RANGES = {
    "local_bank_decline_multiplier": (0.55, 0.80),
    "bank_level_BNK_NL": (0.90, 1.10),
    "bank_level_BNK_DE": (0.90, 1.10),
    "bank_level_BNK_FR": (0.90, 1.10),
    "platform_retry_1_success": (0.15, 0.30),
    "platform_retry_2_success": (0.05, 0.15),
    "customer_retry_share": (0.25, 0.45),
    "fraud_base_online_retail": (0.0008, 0.0015),
    "fraud_base_travel": (0.0015, 0.0035),
    "fraud_base_digital_subscriptions": (0.0025, 0.005),
    "fraud_base_food_delivery": (0.0004, 0.0010),
    "give_up_online_retail": (0.06, 0.12),
    "give_up_travel": (0.03, 0.08),
    "give_up_digital_subscriptions": (0.08, 0.14),
    "give_up_food_delivery": (0.10, 0.18),
    "three_ds_fraud_cut": (0.60, 0.90),
    "payout_error_share": (0.02, 0.05),
}
MISSING_PAYOUTS_RANGE = (3, 6)
DUPLICATE_SHARE = 0.003


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def draw_hidden(rng: np.random.Generator) -> dict:
    h = {k: float(rng.uniform(lo, hi)) for k, (lo, hi) in HIDDEN_RANGES.items()}
    h["payout_error_bank"] = str(rng.choice(sorted(BANK_IDS.values())))
    h["missing_payouts_count"] = int(rng.integers(MISSING_PAYOUTS_RANGE[0], MISSING_PAYOUTS_RANGE[1] + 1))
    return h


def day_weights(btype: str) -> np.ndarray:
    w = np.ones(len(DAYS))
    m, d, dow = DAYS.month.values, DAYS.day.values, DAYS.dayofweek.values
    if btype == "online_retail":
        w[m == 11] = 1.5
        w[(m == 11) & (d >= 24)] = 3.0  # Black Friday week 24-30 Nov
        w[(m == 12) & (d <= 23)] = 1.8
    elif btype == "travel":
        w[m <= 3] = 1.3
    elif btype == "food_delivery":
        w[(m == 12) | (m <= 2)] = 1.2
        w[dow >= 4] *= 1.5  # Fri-Sun
    return w / w.sum()


def draw_amounts(btype: str, n: int, rng: np.random.Generator) -> np.ndarray:
    spec = TYPES[btype]["amount"]
    if spec[0] == "prices":
        return rng.choice(np.array(spec[1]), n, p=spec[2])
    _, median, sigma, lo, hi = spec
    return np.round(np.clip(median * np.exp(sigma * rng.standard_normal(n)), lo, hi), 2)


def fee_region(card_country, shop_country):
    card_country = np.asarray(card_country)
    return np.where(card_country == shop_country, "domestic",
                    np.where(np.isin(card_country, EU_CARDS), "other_eu", "non_eu"))


def fee_terms(bank_id, card_type, region, day):
    """Correct bank fee terms (pct, fixed) per payment, vectorised."""
    bank_id, card_type, region = map(np.asarray, (bank_id, card_type, region))
    day = pd.DatetimeIndex(day)
    pct = np.zeros(len(bank_id))
    fixed = np.zeros(len(bank_id))
    for (ct, rg), (p, f) in FEE_BASE.items():
        mask = (card_type == ct) & (region == rg)
        pct[mask], fixed[mask] = p, f
    pct = pct + np.where(bank_id == "BNK_DE", BANK_DE_SURCHARGE, 0.0)
    fr_rise = (bank_id == "BNK_FR") & (card_type == "credit") & (day >= BANK_FR_RISE_DATE)
    pct = pct + np.where(fr_rise, BANK_FR_CREDIT_RISE, 0.0)
    return pct, fixed


def bank_fee(amount, bank_id, card_type, region, day):
    pct, fixed = fee_terms(bank_id, card_type, region, day)
    return np.round(pct / 100 * np.asarray(amount) + fixed, 2)


def r2(x) -> float:
    return float(round(float(x), 2))


def r6(x) -> float:
    return float(round(float(x), 6))


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------
def build_shops_table() -> pd.DataFrame:
    rows, counters = [], {}
    for i, (bt, ctry, _size, grp, tds, _mb, _sb, special) in enumerate(SHOPS):
        counters[(bt, ctry)] = counters.get((bt, ctry), 0) + 1
        pct, fixed = special if special else TYPES[bt]["price"]
        rows.append(dict(
            shop_id=f"S{i + 1:02d}",
            shop_name=f"{TYPES[bt]['label']} {ctry} {counters[(bt, ctry)]}",
            country=ctry, business_type=bt, fee_pct=pct, fixed_fee_eur=fixed,
            retries_on_date=RETRY_DATES[grp] or "",
            three_ds_policy=tds,
            three_ds_threshold_eur=TYPES[bt]["three_ds_threshold"] if tds == "above_threshold" else "",
        ))
    return pd.DataFrame(rows)


def build_banks_table() -> pd.DataFrame:
    return pd.DataFrame([dict(bank_id=BANK_IDS[c], bank_name=f"Bank {c}", country=c) for c in ["NL", "DE", "FR"]])


def build_fee_rules_table() -> pd.DataFrame:
    rows = []
    for c in ["NL", "DE", "FR"]:
        bid = BANK_IDS[c]
        for ct in ["debit", "credit"]:
            for rg in ["domestic", "other_eu", "non_eu"]:
                p, f = FEE_BASE[(ct, rg)]
                if c == "DE":
                    p += BANK_DE_SURCHARGE
                if c == "FR" and ct == "credit":
                    rows.append(dict(bank_id=bid, card_type=ct, region=rg, fee_pct=round(p, 2), fixed_fee_eur=f,
                                     valid_from=BANK_START[c], valid_to="2025-06-30"))
                    rows.append(dict(bank_id=bid, card_type=ct, region=rg,
                                     fee_pct=round(p + BANK_FR_CREDIT_RISE, 2), fixed_fee_eur=f,
                                     valid_from="2025-07-01", valid_to=""))
                else:
                    rows.append(dict(bank_id=bid, card_type=ct, region=rg, fee_pct=round(p, 2), fixed_fee_eur=f,
                                     valid_from=BANK_START[c], valid_to=""))
    return pd.DataFrame(rows)


def simulate_payments(h: dict, rng: np.random.Generator) -> pd.DataFrame:
    """One row per payment (checkout) with everything that happened to it."""
    rec_platform = 1 - (1 - h["platform_retry_1_success"]) * (1 - h["platform_retry_2_success"])
    parts = []
    for i, (bt, ctry, size, grp, tds, mb, sb, _special) in enumerate(SHOPS):
        t = TYPES[bt]
        counts = rng.poisson(size * day_weights(bt))
        day = np.repeat(DAYS.values, counts)
        n = len(day)
        hour_w = np.array(HOUR_WEIGHTS[t["hours"]]); hour_w = hour_w / hour_w.sum()
        started = (pd.DatetimeIndex(day) + pd.to_timedelta(rng.choice(24, n, p=hour_w), "h")
                   + pd.to_timedelta(rng.integers(0, 3600, n), "s"))
        amount = draw_amounts(bt, n, rng)

        # cards
        others = [c for c in EU_CARDS if c != ctry]
        origin = rng.choice(4, n, p=t["card_mix"])
        other_pick = rng.choice(others, n)
        card_country = np.where(origin == 0, ctry, np.where(origin == 1, other_pick,
                                np.where(origin == 2, "UK", "US")))
        credit_p = np.where(np.isin(card_country, ["UK", "US"]), 0.70, t["credit_share"])
        card_type = np.where(rng.random(n) < credit_p, "credit", "debit")

        # bank: main bank, 30% to backup bank for the 8 biggest shops
        to_backup = rng.random(n) < BACKUP_SHARE
        bank_c = np.where(to_backup & (sb is not None), sb or mb, mb)
        bank_id = np.array([BANK_IDS[c] for c in bank_c])

        # 3D Secure and give-ups
        if tds == "always":
            three_ds = np.ones(n, bool)
        elif tds == "never":
            three_ds = np.zeros(n, bool)
        else:
            three_ds = amount >= t["three_ds_threshold"]
        gave_up = three_ds & (rng.random(n) < h[f"give_up_{bt}"])

        # first-try decline chance
        p = (t["base_decline"]
             * np.where(card_country == "UK", DECLINE_FACTORS["UK"], np.where(card_country == "US", DECLINE_FACTORS["US"], 1.0))
             * np.where(card_type == "debit", DECLINE_FACTORS["debit"], 1.0)
             * np.where(amount >= 500, DECLINE_FACTORS["amount_500"], 1.0)
             * np.where(card_country == bank_c, h["local_bank_decline_multiplier"], 1.0)
             * np.array([h[f"bank_level_{b}"] for b in bank_id]))
        busy = pd.DatetimeIndex(day).month.values >= 11
        p_try = np.minimum(p * TRY_AGAIN_SHARE * np.where(busy, BUSY_SEASON_TRY_AGAIN, 1.0), 0.9)
        p_perm = np.minimum(p * (1 - TRY_AGAIN_SHARE), 0.9 - p_try)
        u = rng.random(n)
        try_again = (u < p_try) & ~gave_up
        permanent = (u >= p_try) & (u < p_try + p_perm) & ~gave_up

        # retries
        on_date = RETRY_DATES[grp]
        retries_on = np.zeros(n, bool) if on_date is None else (pd.DatetimeIndex(day) >= pd.Timestamp(on_date))
        u1, u2, uc, uc2 = rng.random(n), rng.random(n), rng.random(n), rng.random(n)
        plat1 = try_again & retries_on
        plat1_ok = plat1 & (u1 < h["platform_retry_1_success"])
        plat2 = plat1 & ~plat1_ok
        plat2_ok = plat2 & (u2 < h["platform_retry_2_success"])
        cust = try_again & ~retries_on & (uc < h["customer_retry_share"])
        cust_ok = cust & (uc2 < h["platform_retry_1_success"])
        gap1 = pd.to_timedelta(300 + rng.integers(0, 21, n), "s")
        gap2 = pd.to_timedelta(3600 + rng.integers(0, 21, n), "s")
        gapc = pd.to_timedelta(rng.integers(60, 601, n), "s")

        first_ok = ~gave_up & ~try_again & ~permanent
        approved = first_ok | plat1_ok | plat2_ok | cust_ok
        s0, g1, g2, gc = started.values, gap1.values, gap2.values, gapc.values
        approved_at = np.where(first_ok, s0, np.where(plat1_ok, s0 + g1, np.where(
            plat2_ok, s0 + g1 + g2, np.where(cust_ok, s0 + gc, np.datetime64("NaT", "ns")))))
        approved_attempt = np.where(first_ok, 1, np.where(plat1_ok | cust_ok, 2, np.where(plat2_ok, 3, 0)))

        # fraud (approved payments only) and report delay
        pf = (h[f"fraud_base_{bt}"]
              * np.where(card_country == "UK", FRAUD_FACTORS["UK"], np.where(card_country == "US", FRAUD_FACTORS["US"], 1.0))
              * np.where(amount >= 100, FRAUD_FACTORS["amount_100"], 1.0)
              * np.where(three_ds, 1 - h["three_ds_fraud_cut"], 1.0))
        fraud = approved & (rng.random(n) < pf)
        delay_days = np.clip(np.round(np.exp(np.log(45) + 0.6 * rng.standard_normal(n))), 14, 182).astype(int)

        parts.append(pd.DataFrame(dict(
            shop_idx=i, business_type=bt, shop_country=ctry, started_at=started, amount=amount,
            card_country=card_country, card_type=card_type, bank_id=bank_id, three_ds=three_ds,
            gave_up=gave_up, try_again=try_again, permanent=permanent, retries_on=retries_on,
            plat1=plat1, plat1_ok=plat1_ok, plat2=plat2, plat2_ok=plat2_ok, cust=cust, cust_ok=cust_ok,
            gap1=gap1, gap2=gap2, gapc=gapc, approved=approved, approved_at=pd.to_datetime(approved_at),
            approved_attempt=approved_attempt, fraud=fraud, fraud_p=pf, decline_p=p,
            report_delay_days=np.where(fraud, delay_days, 0),
        )))
    pay = pd.concat(parts, ignore_index=True)
    pay = pay.sort_values(["started_at", "shop_idx"], kind="stable").reset_index(drop=True)
    pay["payment_id"] = [f"P{k + 1:06d}" for k in range(len(pay))]
    pay["shop_id"] = [f"S{k + 1:02d}" for k in pay.shop_idx]
    pay["rec_platform"] = rec_platform
    return pay


def build_attempts(pay: pd.DataFrame) -> pd.DataFrame:
    base_cols = ["payment_id", "shop_id", "amount", "card_country", "card_type", "bank_id", "three_ds"]
    first = pay[base_cols].copy()
    first["attempt_number"], first["initiated_by"], first["attempted_at"] = 1, "customer", pay.started_at
    first["outcome"] = np.where(pay.gave_up, "gave_up", np.where(pay.try_again | pay.permanent, "declined", "approved"))
    first["decline_type"] = np.where(pay.try_again, "try_again", np.where(pay.permanent, "permanent", ""))

    def retry(mask, number, who, at, ok):
        r = pay.loc[mask, base_cols].copy()
        r["attempt_number"], r["initiated_by"], r["attempted_at"] = number, who, at[mask]
        r["outcome"] = np.where(ok[mask], "approved", "declined")
        r["decline_type"] = np.where(ok[mask], "", "try_again")
        return r

    p1 = retry(pay.plat1, 2, "platform", pay.started_at + pay.gap1, pay.plat1_ok)
    p2 = retry(pay.plat2, 3, "platform", pay.started_at + pay.gap1 + pay.gap2, pay.plat2_ok)
    cu = retry(pay.cust, 2, "customer", pay.started_at + pay.gapc, pay.cust_ok)
    att = pd.concat([first, p1, p2, cu], ignore_index=True)
    att = att.sort_values(["attempted_at", "payment_id", "attempt_number"], kind="stable").reset_index(drop=True)
    att["attempt_id"] = [f"A{k + 1:06d}" for k in range(len(att))]
    return att


def main() -> None:
    ss = np.random.SeedSequence(SEED)
    rng_hidden, rng_sim, rng_mess = (np.random.default_rng(s) for s in ss.spawn(3))
    h = draw_hidden(rng_hidden)

    shops = build_shops_table()
    banks = build_banks_table()
    fee_rules = build_fee_rules_table()
    pay = simulate_payments(h, rng_sim)
    att = build_attempts(pay)

    # link each approved payment to its approving attempt
    appr_att = att[att.outcome == "approved"][["payment_id", "attempt_id", "attempted_at"]]
    pay = pay.merge(appr_att.rename(columns={"attempt_id": "approved_attempt_id"})[["payment_id", "approved_attempt_id"]],
                    on="payment_id", how="left")

    # correct bank fee per approved payment (fee type = card country vs shop country; FR rise by approval day)
    pay["region"] = fee_region(pay.card_country.values, pay.shop_country.values)
    pay["approved_day"] = pay.approved_at.dt.normalize()
    fee_day = pay.approved_day.fillna(pay.started_at.dt.normalize())
    pay["bank_fee"] = np.where(pay.approved, bank_fee(pay.amount, pay.bank_id, pay.card_type, pay.region, fee_day), 0.0)
    shop_price = shops.set_index("shop_id")[["fee_pct", "fixed_fee_eur"]]
    pay["price_pct"] = pay.shop_id.map(shop_price.fee_pct).astype(float)
    pay["price_fixed"] = pay.shop_id.map(shop_price.fixed_fee_eur).astype(float)
    pay["platform_income"] = np.where(pay.approved, np.round(pay.price_pct / 100 * pay.amount + pay.price_fixed, 2), 0.0)
    pay["fraud_loss"] = np.where(pay.fraud & ~pay.three_ds, pay.amount, 0.0)
    pay["dispute_fee"] = np.where(pay.fraud & ~pay.three_ds, DISPUTE_FEE_EUR, 0.0)
    pay["reported_date"] = pay.approved_day + pd.to_timedelta(pay.report_delay_days, "D")
    pay["report_in_data"] = pay.fraud & (pay.reported_date <= PULL_DATE)

    # ---------------- fraud_reports ----------------
    fr = pay[pay.report_in_data].sort_values(["reported_date", "approved_attempt_id"])
    fraud_reports = pd.DataFrame(dict(
        fraud_report_id=[f"FR{k + 1:05d}" for k in range(len(fr))],
        attempt_id=fr.approved_attempt_id.values,
        reported_date=fr.reported_date.dt.strftime("%Y-%m-%d").values,
        amount_eur=fr.amount.values))

    # ---------------- bank_payouts ----------------
    ap = pay[pay.approved].copy()
    ap["is_debit"] = ap.card_type == "debit"
    credit_pct, _ = fee_terms(ap.bank_id, np.full(len(ap), "credit"), ap.region, ap.approved_day)
    _, fixed_part = fee_terms(ap.bank_id, ap.card_type, ap.region, ap.approved_day)
    ap["fee_if_credit_rate"] = np.where(ap.is_debit, np.round(credit_pct / 100 * ap.amount + fixed_part, 2), ap.bank_fee)
    ap["fixed_part"] = fixed_part
    grp = ap.groupby(["shop_id", "bank_id", "approved_day"], sort=True)
    po = grp.agg(payment_count=("amount", "size"), gross_eur=("amount", "sum"), fees_correct=("bank_fee", "sum"),
                 fees_if_credit_rate=("fee_if_credit_rate", "sum"), fixed_sum=("fixed_part", "sum"),
                 debit_count=("is_debit", "sum")).reset_index()
    po["gross_eur"] = po.gross_eur.round(2)
    po["fees_correct"] = po.fees_correct.round(2)
    po["fees_eur"] = po.fees_correct

    # planted errors: one bank takes the wrong fee on a share of its rows
    err_bank = h["payout_error_bank"]
    err_candidates = np.flatnonzero((po.bank_id == err_bank).values)
    n_err = int(round(h["payout_error_share"] * len(err_candidates)))
    err_rows = np.sort(rng_mess.choice(err_candidates, n_err, replace=False))
    kinds = rng_mess.choice(["fixed_fee_charged_twice", "debit_charged_at_credit_rate"], n_err)
    error_list = []
    for r, kind in zip(err_rows, kinds):
        if kind == "debit_charged_at_credit_rate" and po.at[r, "debit_count"] == 0:
            kind = "fixed_fee_charged_twice"
        extra = po.at[r, "fixed_sum"] if kind == "fixed_fee_charged_twice" else po.at[r, "fees_if_credit_rate"] - po.at[r, "fees_correct"]
        po.at[r, "fees_eur"] = round(po.at[r, "fees_correct"] + extra, 2)
        error_list.append((r, kind))

    # planted missing payouts (never arrive), chosen among rows without fee errors
    ok_rows = np.setdiff1d(np.arange(len(po)), err_rows)
    missing_rows = np.sort(rng_mess.choice(ok_rows, h["missing_payouts_count"], replace=False))
    missing = po.loc[missing_rows].copy()
    po["is_error"] = False
    po.loc[err_rows, "is_error"] = True
    po["error_kind"] = ""
    for r, kind in error_list:
        po.at[r, "error_kind"] = kind
    po = po.drop(index=missing_rows).reset_index(drop=True)

    pd_idx = pd.DatetimeIndex(po.approved_day)
    shift = np.select([pd_idx.dayofweek == 4, pd_idx.dayofweek == 5], [3, 2], default=1)  # Fri->Mon, Sat->Mon, Sun->Mon
    po["payout_date"] = pd_idx + pd.to_timedelta(shift, "D")
    po = po.sort_values(["payout_date", "shop_id", "bank_id", "approved_day"], kind="stable").reset_index(drop=True)
    po["payout_id"] = [f"PO{k + 1:05d}" for k in range(len(po))]
    po["net_eur"] = (po.gross_eur - po.fees_eur).round(2)
    bank_payouts = pd.DataFrame(dict(
        payout_id=po.payout_id, shop_id=po.shop_id, bank_id=po.bank_id,
        payment_date=po.approved_day.dt.strftime("%Y-%m-%d"), payout_date=po.payout_date.dt.strftime("%Y-%m-%d"),
        payment_count=po.payment_count, gross_eur=po.gross_eur, fees_eur=po.fees_eur, net_eur=po.net_eur))

    # ---------------- payment_attempts (with planted duplicates) ----------------
    n_dup = int(round(DUPLICATE_SHARE * len(att)))
    dup_idx = np.sort(rng_mess.choice(len(att), n_dup, replace=False))
    att_out = pd.concat([att, att.loc[dup_idx]], ignore_index=False).sort_index(kind="stable").reset_index(drop=True)
    payment_attempts = pd.DataFrame(dict(
        attempt_id=att_out.attempt_id, payment_id=att_out.payment_id, attempt_number=att_out.attempt_number,
        initiated_by=att_out.initiated_by, shop_id=att_out.shop_id,
        attempted_at=att_out.attempted_at.dt.strftime("%Y-%m-%d %H:%M:%S"),
        amount_eur=att_out.amount, card_country=att_out.card_country, card_type=att_out.card_type,
        bank_id=att_out.bank_id, three_ds_used=np.where(att_out.three_ds, "true", "false"),
        outcome=att_out.outcome, decline_type=att_out.decline_type))

    # ---------------- write CSVs ----------------
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    tables = dict(shops=shops, banks=banks, fee_rules=fee_rules, payment_attempts=payment_attempts,
                  bank_payouts=bank_payouts, fraud_reports=fraud_reports)
    for name, df in tables.items():
        df.to_csv(RAW_DIR / f"{name}.csv", index=False, float_format="%.2f", lineterminator="\n")

    # ---------------- answers ----------------
    answers = build_answers(h, pay, shops, att, dup_idx, po, missing, error_list)
    ANSWER_FILE.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(answers, indent=1, sort_keys=True, ensure_ascii=True) + "\n"
    ANSWER_FILE.write_text(text, encoding="utf-8", newline="\n")

    print("Rows written to data/raw/:")
    for name, df in tables.items():
        print(f"  {name:<17} {len(df):>7,}")
    print("Answer file: data/answers/answers.json (do not open until the analysis is done)")
    print("SHA-256:", hashlib.sha256(ANSWER_FILE.read_bytes()).hexdigest())


# ---------------------------------------------------------------------------
# Answer file (true effects, true fraud, true money, true fix values, planted mess)
# ---------------------------------------------------------------------------
def expected_margin_and_sales(pay: pd.DataFrame, h: dict, bank_id=None, three_ds=None, retries_on=None):
    """Expected platform profit and shop sales per payment under a scenario (rulebook rules, no random draws)."""
    bank_id = pay.bank_id.values if bank_id is None else np.asarray(bank_id)
    three_ds = pay.three_ds.values if three_ds is None else np.asarray(three_ds, bool)
    retries_on = pay.retries_on.values if retries_on is None else np.asarray(retries_on, bool)
    bank_c = np.array([b[-2:] for b in bank_id])
    btype = pay.business_type.values
    cc, ct, amt = pay.card_country.values, pay.card_type.values, pay.amount.values
    base = np.array([TYPES[b]["base_decline"] for b in btype])
    p = (base * np.where(cc == "UK", 1.5, np.where(cc == "US", 2.0, 1.0)) * np.where(ct == "debit", 1.2, 1.0)
         * np.where(amt >= 500, 1.5, 1.0) * np.where(cc == bank_c, h["local_bank_decline_multiplier"], 1.0)
         * np.array([h[f"bank_level_{b}"] for b in bank_id]))
    busy = pay.started_at.dt.month.values >= 11
    p_try = np.minimum(p * TRY_AGAIN_SHARE * np.where(busy, BUSY_SEASON_TRY_AGAIN, 1.0), 0.9)
    p_perm = np.minimum(p * (1 - TRY_AGAIN_SHARE), 0.9 - p_try)
    rec = np.where(retries_on, 1 - (1 - h["platform_retry_1_success"]) * (1 - h["platform_retry_2_success"]),
                   h["customer_retry_share"] * h["platform_retry_1_success"])
    give_up = np.array([h[f"give_up_{b}"] for b in btype]) * three_ds
    p_appr = (1 - give_up) * ((1 - p_try - p_perm) + p_try * rec)
    fee = bank_fee(amt, bank_id, ct, pay.region.values, pay.started_at.dt.normalize())
    price = np.round(pay.price_pct.values / 100 * amt + pay.price_fixed.values, 2)
    pf = (np.array([h[f"fraud_base_{b}"] for b in btype]) * np.where(cc == "UK", 2.0, np.where(cc == "US", 3.0, 1.0))
          * np.where(amt >= 100, 1.5, 1.0) * np.where(three_ds, 1 - h["three_ds_fraud_cut"], 1.0))
    fraud_cost = np.where(three_ds, 0.0, pf * (amt + DISPUTE_FEE_EUR))
    margin = p_appr * (price - fee - fraud_cost)
    return margin, p_appr * amt, p_appr, p_try, p


def build_answers(h, pay, shops, att, dup_idx, po_kept, missing, error_list) -> dict:
    ans = {"about": {
        "rulebook_version": RULEBOOK_VERSION, "seed": SEED,
        "note": ("Hidden answers. dbt and Power BI must never read this file. Money in EUR. "
                 "true_money_per_shop_month uses what actually happened in the simulation (including fraud not yet "
                 "reported); months are the month of the payment's first try. true_fix_values_per_year are expected "
                 "values computed from the rules (no random noise), as the change versus the actual 2025 setup."),
    }}

    # 1. true effects
    params = {k: (r6(v) if isinstance(v, float) else v) for k, v in h.items()}
    rec_platform = 1 - (1 - h["platform_retry_1_success"]) * (1 - h["platform_retry_2_success"])
    rec_customer = h["customer_retry_share"] * h["platform_retry_1_success"]
    live = pay[~pay.gave_up]
    eu_foreign = live[live.card_country.isin(["NL", "DE", "FR"]) & (live.card_country != live.bank_id.str[-2:])]
    local_pp = (eu_foreign.decline_p * (1 - h["local_bank_decline_multiplier"])).mean() * 100
    on = live[live.retries_on]
    busy_on = on.started_at.dt.month >= 11
    p_try_on = np.minimum(on.decline_p * TRY_AGAIN_SHARE * np.where(busy_on, BUSY_SEASON_TRY_AGAIN, 1.0), 0.9)
    retry_pp = (p_try_on * (rec_platform - rec_customer)).mean() * 100
    chk = pay[pay.three_ds & pay.approved]
    fraud_pp_checked = (chk.fraud_p / (1 - h["three_ds_fraud_cut"]) * h["three_ds_fraud_cut"]).mean() * 100
    ans["true_effects"] = {
        "hidden_values": params,
        "local_bank_first_try_approval_gain_pp": r6(local_pp),
        "local_bank_note": "average gain in first-try approval rate for NL/DE/FR cards now at a foreign bank, if sent to their local bank",
        "retries_final_approval_gain_pp": r6(retry_pp),
        "retries_note": "average gain in final approval rate for payments with retries switched on, versus the same payments with retries off (customers retrying themselves)",
        "retries_share_of_try_again_payments_saved_platform": r6(rec_platform),
        "retries_share_of_try_again_payments_saved_customers_alone": r6(rec_customer),
        "retries_true_gain_share_of_try_again_payments": r6(rec_platform - rec_customer),
        "three_ds_give_up_pp_by_type": {bt: r6(h[f"give_up_{bt}"] * 100) for bt in TYPES},
        "three_ds_fraud_rate_cut_pp_on_checked_approved_payments": r6(fraud_pp_checked),
    }

    # 2. true fraud
    fr = pay[pay.fraud].sort_values("approved_attempt_id")
    ans["true_fraud"] = [dict(attempt_id=a, shop_id=s, approved_date=d.strftime("%Y-%m-%d"),
                              reported_date=rd.strftime("%Y-%m-%d"), report_in_data=bool(ind), amount_eur=r2(amt),
                              three_ds_used=bool(t), platform_loss_eur=r2(amt + DISPUTE_FEE_EUR) if not t else 0.0)
                         for a, s, d, rd, ind, amt, t in zip(fr.approved_attempt_id, fr.shop_id, fr.approved_day,
                                                             fr.reported_date, fr.report_in_data, fr.amount, fr.three_ds)]

    # 3. true money per shop-month
    pay["month"] = pay.started_at.dt.strftime("%Y-%m")
    pay["declined_sales"] = np.where(~pay.approved & ~pay.gave_up, pay.amount, 0.0)
    pay["gave_up_sales"] = np.where(pay.gave_up, pay.amount, 0.0)
    pay["approved_eur"] = np.where(pay.approved, pay.amount, 0.0)
    g = pay.groupby(["shop_id", "month"]).agg(
        payments=("payment_id", "size"), approved_payments=("approved", "sum"), approved_eur=("approved_eur", "sum"),
        platform_fee_income_eur=("platform_income", "sum"), bank_fees_correct_eur=("bank_fee", "sum"),
        fraud_payments=("fraud", "sum"), fraud_loss_eur=("fraud_loss", "sum"), dispute_fees_eur=("dispute_fee", "sum"),
        sales_lost_to_declines_eur=("declined_sales", "sum"), sales_lost_to_give_ups_eur=("gave_up_sales", "sum"),
    ).reset_index()
    g["margin_eur"] = g.platform_fee_income_eur - g.bank_fees_correct_eur - g.fraud_loss_eur - g.dispute_fees_eur
    money_cols = [c for c in g.columns if c.endswith("_eur")]
    ans["true_money_per_shop_month"] = [
        {**{"shop_id": r.shop_id, "month": r.month, "payments": int(r.payments),
            "approved_payments": int(r.approved_payments), "fraud_payments": int(r.fraud_payments)},
         **{c: r2(getattr(r, c)) for c in money_cols}} for r in g.itertuples()]

    # per shop year: true margin, loss-making flag, break-even price
    y = g.groupby("shop_id")[["approved_payments", "approved_eur", "platform_fee_income_eur", "bank_fees_correct_eur",
                              "fraud_loss_eur", "dispute_fees_eur", "margin_eur"]].sum()
    sp = shops.set_index("shop_id")
    y["break_even_fee_pct_at_current_fixed_fee"] = (
        (y.bank_fees_correct_eur + y.fraud_loss_eur + y.dispute_fees_eur - sp.fixed_fee_eur * y.approved_payments)
        / y.approved_eur * 100)
    ans["true_shop_year"] = {s: {"approved_eur": r2(r.approved_eur), "margin_eur": r2(r.margin_eur),
                                 "margin_pct_of_approved": r6(r.margin_eur / r.approved_eur * 100),
                                 "loss_making": bool(r.margin_eur < 0),
                                 "current_fee_pct": float(sp.at[s, "fee_pct"]),
                                 "current_fixed_fee_eur": float(sp.at[s, "fixed_fee_eur"]),
                                 "break_even_fee_pct_at_current_fixed_fee": r6(r.break_even_fee_pct_at_current_fixed_fee)}
                             for s, r in y.iterrows()}
    ans["loss_making_shops"] = sorted(y.index[y.margin_eur < 0].tolist())

    # 4. true value of each fix per shop per year (expected, vs actual setup)
    base_m, base_s, *_ = expected_margin_and_sales(pay, h)
    cc = pay.card_country.values
    local_bank = np.array(["BNK_" + c if c in ("NL", "DE", "FR") else "BNK_NL" for c in cc])
    thr = np.array([TYPES[b]["three_ds_threshold"] for b in pay.business_type])
    scenarios = {
        "local_routing": dict(bank_id=local_bank),
        "cheapest_bank_for_everything": dict(bank_id=np.full(len(pay), "BNK_NL")),
        "retries_on_all_year": dict(retries_on=np.ones(len(pay), bool)),
        "three_ds_always": dict(three_ds=np.ones(len(pay), bool)),
        "three_ds_never": dict(three_ds=np.zeros(len(pay), bool)),
        "three_ds_above_threshold": dict(three_ds=pay.amount.values >= thr),
    }
    fixes = {}
    for name, kw in scenarios.items():
        m, s, *_ = expected_margin_and_sales(pay, h, **kw)
        d = pd.DataFrame(dict(shop_id=pay.shop_id, dm=m - base_m, ds=s - base_s)).groupby("shop_id").sum()
        fixes[name] = {"total": {"platform_profit_eur": r2(d.dm.sum()), "shop_sales_eur": r2(d.ds.sum())},
                       "per_shop": {sid: {"platform_profit_eur": r2(r.dm), "shop_sales_eur": r2(r.ds)}
                                    for sid, r in d.iterrows()}}
    fixes["note"] = ("Change in expected platform profit and shop sales per year versus the actual 2025 setup. "
                     "local_routing: NL/DE/FR cards to their own country's bank, other cards to Bank NL (cheapest). "
                     "Repricing: see true_shop_year break-even price.")
    ans["true_fix_values_per_year"] = fixes

    # 5. planted mess
    dups = att.loc[dup_idx, "attempt_id"].tolist()
    kept = po_kept[po_kept.is_error]
    ans["planted_mess"] = {
        "duplicate_attempt_ids": dups,
        "payout_fee_errors": [dict(payout_id=r.payout_id, shop_id=r.shop_id, bank_id=r.bank_id,
                                   payment_date=r.approved_day.strftime("%Y-%m-%d"), kind=r.error_kind,
                                   fees_taken_eur=r2(r.fees_eur), fees_correct_eur=r2(r.fees_correct))
                              for r in kept.sort_values("payout_id").itertuples()],
        "missing_payouts": [dict(shop_id=r.shop_id, bank_id=r.bank_id, payment_date=r.approved_day.strftime("%Y-%m-%d"),
                                 payment_count=int(r.payment_count), gross_eur=r2(r.gross_eur),
                                 fees_correct_eur=r2(r.fees_correct)) for r in missing.itertuples()],
        "late_fraud_reports_missing_from_data": int((pay.fraud & ~pay.report_in_data).sum()),
    }
    return ans


if __name__ == "__main__":
    main()
