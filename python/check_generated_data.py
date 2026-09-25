"""Sanity checks on the generated source tables in data/raw/.

Run from the repo root after generate_data.py:

    python python/check_generated_data.py

Reads only data/raw/ (never the answer file). Checks row counts, keys, links between
tables, allowed values, dates, amounts, gaps and the rulebook's logic. Prints PASS/FAIL
per check plus a few totals. Planted mess (duplicates, payout errors, missing payouts,
late fraud reports) is expected and is NOT reported as a failure here; finding it is
the job of the dbt models and the exception list.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

RAW = Path(__file__).resolve().parents[1] / "data" / "raw"
results: list[tuple[bool, str]] = []


def check(ok, label: str) -> None:
    results.append((bool(ok), label))


def load() -> dict[str, pd.DataFrame]:
    return {n: pd.read_csv(RAW / f"{n}.csv", keep_default_na=True) for n in
            ["shops", "banks", "fee_rules", "payment_attempts", "bank_payouts", "fraud_reports"]}


def main() -> None:
    t = load()
    shops, banks, rules, att, po, fr = (t[k] for k in ["shops", "banks", "fee_rules", "payment_attempts",
                                                        "bank_payouts", "fraud_reports"])

    # --- columns and row counts
    expected_cols = {
        "shops": ["shop_id", "shop_name", "country", "business_type", "fee_pct", "fixed_fee_eur", "retries_on_date",
                  "three_ds_policy", "three_ds_threshold_eur"],
        "banks": ["bank_id", "bank_name", "country"],
        "fee_rules": ["bank_id", "card_type", "region", "fee_pct", "fixed_fee_eur", "valid_from", "valid_to"],
        "payment_attempts": ["attempt_id", "payment_id", "attempt_number", "initiated_by", "shop_id", "attempted_at",
                             "amount_eur", "card_country", "card_type", "bank_id", "three_ds_used", "outcome",
                             "decline_type"],
        "bank_payouts": ["payout_id", "shop_id", "bank_id", "payment_date", "payout_date", "payment_count",
                         "gross_eur", "fees_eur", "net_eur"],
        "fraud_reports": ["fraud_report_id", "attempt_id", "reported_date", "amount_eur"],
    }
    for name, cols in expected_cols.items():
        check(list(t[name].columns) == cols, f"{name}: columns as in the rulebook")
    check(len(shops) == 24 and len(banks) == 3 and len(rules) == 21, "shops 24, banks 3, fee_rules 21 rows")

    # --- keys and duplicates
    check(shops.shop_id.is_unique and banks.bank_id.is_unique, "shop_id and bank_id unique")
    exact_dups = int(att.duplicated().sum())
    id_dups = int(att.attempt_id.duplicated().sum())
    check(exact_dups == id_dups, "every repeated attempt_id is an exact copy (no conflicting rows)")
    a = att.drop_duplicates().copy()
    check(a.attempt_id.is_unique, "attempt_id unique after removing exact copies")
    check(po.payout_id.is_unique and not po.duplicated(["shop_id", "bank_id", "payment_date"]).any(),
          "payouts: one row per shop x bank x payment day")
    check(fr.fraud_report_id.is_unique and fr.attempt_id.is_unique, "fraud reports: ids unique, one report per payment")

    # --- links between tables
    check(set(a.shop_id) <= set(shops.shop_id) and set(po.shop_id) <= set(shops.shop_id), "all shop_ids exist in shops")
    check(set(a.bank_id) <= set(banks.bank_id) and set(po.bank_id) <= set(banks.bank_id)
          and set(rules.bank_id) <= set(banks.bank_id), "all bank_ids exist in banks")
    approved_ids = set(a.loc[a.outcome == "approved", "attempt_id"])
    check(set(fr.attempt_id) <= approved_ids, "every fraud report points to an approved attempt")

    # --- allowed values and nulls
    check(a[["attempt_id", "payment_id", "shop_id", "attempted_at", "amount_eur", "card_country", "card_type",
             "bank_id", "outcome"]].notna().all().all(), "payment_attempts: no missing required values")
    check(set(a.outcome) == {"approved", "declined", "gave_up"}, "outcome values: approved / declined / gave_up")
    dt = a.decline_type.fillna("")
    check(((a.outcome == "declined") == dt.isin(["try_again", "permanent"])).all(),
          "decline_type filled exactly when outcome = declined")
    check(set(a.initiated_by) == {"customer", "platform"} and set(a.card_type) == {"debit", "credit"}
          and set(a.card_country) == {"NL", "DE", "FR", "ES", "UK", "US"}, "initiated_by / card_type / card_country values")
    check(set(rules.region) == {"domestic", "other_eu", "non_eu"}, "fee_rules regions")
    check((a.amount_eur > 0).all() and (fr.amount_eur > 0).all(), "amounts are positive")

    # --- dates
    a["ts"] = pd.to_datetime(a.attempted_at)
    first = a[a.attempt_number == 1]
    check(first.ts.min() >= pd.Timestamp("2025-01-01") and first.ts.max() < pd.Timestamp("2026-01-01"),
          "all payments start in calendar year 2025")
    check(a.ts.max() < pd.Timestamp("2026-01-01 02:00"), "retries spill past New Year by at most ~1 hour")
    days_with_payments = first.ts.dt.normalize().nunique()
    check(days_with_payments == 365, "no calendar day without payments")
    po_pd, po_out = pd.to_datetime(po.payment_date), pd.to_datetime(po.payout_date)
    check(((po_out - po_pd).dt.days.between(1, 3)).all() and (po_out.dt.dayofweek < 5).all(),
          "payouts arrive 1-3 days later, always on a working day")
    fr_d = pd.to_datetime(fr.reported_date)
    appr_day = a.set_index("attempt_id").loc[fr.attempt_id, "ts"].dt.normalize().values
    delay = (fr_d.values - appr_day) / np.timedelta64(1, "D")
    check((delay >= 14).all() and (delay <= 182).all() and (fr_d <= pd.Timestamp("2026-01-31")).all(),
          "fraud reports arrive 2-26 weeks after approval, none after 31 Jan 2026")

    # --- rulebook logic per payment
    g = a.groupby("payment_id")
    check((g.attempt_number.min() == 1).all() and (g.attempt_number.max() == g.size()).all(),
          "each payment: attempt numbers 1, 2, 3 without gaps")
    check((g.outcome.apply(lambda s: (s == "approved").sum()) <= 1).all(), "at most one approved attempt per payment")
    check((g[["amount_eur", "card_country", "card_type", "bank_id", "three_ds_used", "shop_id"]].nunique() == 1).all().all(),
          "retries keep amount, card, bank and 3D Secure result")
    later = a[a.attempt_number > 1].merge(a[["payment_id", "attempt_number", "outcome", "decline_type"]],
                                          on="payment_id", suffixes=("", "_prev"))
    later = later[later.attempt_number_prev == later.attempt_number - 1]
    check(((later.outcome_prev == "declined") & (later.decline_type_prev == "try_again")).all(),
          "retries only follow a 'try again' decline")
    s = shops.set_index("shop_id")
    later["on_date"] = pd.to_datetime(later.shop_id.map(s.retries_on_date))
    first_ts = first.set_index("payment_id").ts
    later["start"] = later.payment_id.map(first_ts)
    on = later.on_date.notna() & (later.start.dt.normalize() >= later.on_date)
    check((on == (later.initiated_by == "platform")).all(),
          "platform retries only after the shop's switch-on date; customer retries only before / never-shops")
    pol = first.shop_id.map(s.three_ds_policy)
    thr = first.shop_id.map(s.three_ds_threshold_eur)
    want = np.where(pol == "always", True, np.where(pol == "never", False, first.amount_eur >= thr))
    check((first.three_ds_used.astype(str).str.lower().eq("true") == want).all(), "3D Secure use matches each shop's setting")
    check((first.loc[first.outcome == "gave_up", "three_ds_used"].astype(str).str.lower() == "true").all(),
          "customers only give up on checked payments")

    # --- fee_rules: exactly one rule per bank x card type x region on every 2025 day
    r = rules.copy()
    r["vf"], r["vt"] = pd.to_datetime(r.valid_from), pd.to_datetime(r.valid_to).fillna(pd.Timestamp("2099-12-31"))
    days = pd.date_range("2025-01-01", "2025-12-31")
    cover = [((r.bank_id == b) & (r.card_type == c) & (r.region == g_) & (r.vf <= d) & (r.vt >= d)).sum()
             for b in banks.bank_id for c in ["debit", "credit"] for g_ in ["domestic", "other_eu", "non_eu"]
             for d in days[::7]]
    check(set(cover) == {1}, "fee_rules: exactly one valid rule per bank x card type x region on every date")

    # --- payouts arithmetic and plausibility
    check((po.net_eur.round(2) == (po.gross_eur - po.fees_eur).round(2)).all(), "payouts: net = gross - fees")
    fee_share = po.fees_eur / po.gross_eur
    check(fee_share.between(0.003, 0.08).all(), "payout fees between 0.3% and 8% of gross (fixed fees weigh more on tiny payments)")
    appr = a[a.outcome == "approved"]
    check(po.gross_eur.sum() <= appr.amount_eur.sum() + 0.01, "payouts never exceed approved amounts")

    # --- print
    n_pay = a.payment_id.nunique()
    print("CHECKS")
    for ok, label in results:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}")
    print(f"\n{sum(ok for ok, _ in results)}/{len(results)} checks passed\n")
    print("TOTALS")
    print(f"  payments            {n_pay:>9,}")
    print(f"  attempt rows        {len(att):>9,}  (incl. {exact_dups} exact duplicate rows = {exact_dups / len(att):.2%})")
    print(f"  platform retries    {(a.initiated_by == 'platform').sum():>9,}")
    print(f"  customer retries    {((a.initiated_by == 'customer') & (a.attempt_number > 1)).sum():>9,}")
    print(f"  approved payments   {len(appr):>9,}  ({len(appr) / n_pay:.1%} of payments)")
    print(f"  gave up at 3DS      {(a.outcome == 'gave_up').sum():>9,}")
    print(f"  approved amount     EUR {appr.amount_eur.sum():>12,.0f}")
    print(f"  bank payouts        {len(po):>9,}")
    print(f"  fraud reports       {len(fr):>9,}")
    months = first.ts.dt.month.value_counts().sort_index()
    print("  payments by month   " + " ".join(f"{m}:{v / 1000:.1f}k" for m, v in months.items()))


if __name__ == "__main__":
    main()
