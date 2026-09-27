# Rulebook: how the simulated world behaves

v4, approved by Sam on 25 Sep 2026 and used for the committed data. The generator in `python/` follows these rules
exactly. To change the data, change this file first, then the code.

**Hidden numbers.** A value in square brackets, like [20–40%], is a range. The generator picks the
exact value (fixed seed) and writes it only to the answer file. You know how the world works, but
not the true size of each effect.

## 1. The world

- Calendar year 2025. All times UTC, all amounts EUR. The data is "pulled" on 31 Jan 2026.
- 24 shops, 6 per business type. 8 shops each in NL, DE and FR (2 per type per country).
- Sizes (payments per year): 3 big (11,500–17,000), 6 medium (4,000–7,000), 15 small (600–3,500).
  Total about 100,000 payments.
- 3 banks: Bank NL, Bank DE, Bank FR. 6 card countries: NL, DE, FR, ES, UK, US.
  A **local bank** is one in the card's country (only NL, DE, FR cards can have one). A local bank
  approves more, but it does not change the fee (section 5).
- Daily rhythm: quiet at night, busiest 16:00–20:00 UTC. Food delivery is the most evening-heavy.

| | Online retail | Travel | Digital subscriptions | Food delivery |
|---|---|---|---|---|
| Amount | median €55 (€5–1,500) | median €380 (€40–4,000) | fixed prices €4.99–29.99 | median €27 (€8–150) |
| Busy periods | Nov ×1.5, Black Friday week (24–30 Nov) ×3, 1–23 Dec ×1.8 | Jan–Mar ×1.3 (summer bookings) | flat | Fri–Sun ×1.5, Dec–Feb ×1.2 |
| Cards: home country / other EU / UK / US | 65 / 25 / 6 / 4% | 40 / 25 / 20 / 15% | 55 / 25 / 12 / 8% | 85 / 10 / 3 / 2% |
| Credit card share | 35% | 60% | 45% | 20% |
| Decline chance, first try (base) | 7% | 11% | 10% | 6% |
| Fraud chance, approved payment (base) | [0.08–0.15%] | [0.15–0.35%] | [0.25–0.5%] | [0.04–0.10%] |
| Customers giving up at 3D Secure | [6–12%] | [3–8%] | [8–14%] | [10–18%] |
| 3D Secure threshold ("bigger payments" shops) | €150 | €250 | €15 | €40 |
| Standard price paid to the platform | 1.6% + €0.25 | 2.4% + €0.25 | 2.4% + €0.25 | 1.4% + €0.25 |

"Other EU" cards are split evenly over the other three of NL/DE/FR/ES. UK and US cards are 70% credit.

## 2. Approvals and declines

Decline chance on the first try = base (table) × these factors:
UK card ×1.5, US card ×2 (banks trust foreign cards less) · debit ×1.2 (more "not enough money") ·
amount €500+ ×1.5 · local bank ×[0.55–0.80] · each bank's own level ×[0.90–1.10].

60% of declines are **"try again"** (temporary: bank busy, not enough money right now), 40% are
**permanent** (card blocked, wrong details). In Nov–Dec, "try again" declines are 1.3× more common
(busy season). 3D Secure does not change the approval chance.

## 3. Bank choice (not random)

- Retail and food shops use the bank of their own country.
- All travel and subscription shops use Bank DE, whatever their country. In 2023 Bank DE offered
  fast sign-up for these riskier shop types. It was a sales deal, not a quality choice.
- The 8 biggest shops send 30% of their payments (picked at random) to a second bank, as a backup.

Effect: Bank DE carries the riskier shops and most UK/US cards, so it looks worst in a simple
bank-vs-bank table, on both approvals and fees. A fair comparison holds business type, card country,
card type and amount equal.

## 4. Retries

- Automatic retries switch on for 6 shops on 17 Mar 2025, 6 on 9 Jun, 6 on 15 Sep. 6 shops never.
  Each group mixes business types and sizes.
- With retries on, a "try again" decline is retried by the platform after 5 minutes and, if still
  declined, again after 1 hour. Chance the 1st retry is approved: [15–30%]; the 2nd: [5–15%].
  Customers wait and do not retry themselves.
- With retries off, [25–45%] of customers with a "try again" decline press "pay" once more within
  10 minutes. That try is approved as often as the platform's 1st retry. So some sales are saved even
  without the feature, and simply counting approved platform retries overstates what it adds.
- A failed retry, by the platform or the customer, is recorded as "try again".
- Permanent declines and customers who gave up are never retried. All retries go to the same bank and
  keep the 3D Secure result. Each retry is its own row, linked to its payment by `payment_id`, with
  `initiated_by` = customer or platform (the first try is always customer).

## 5. Bank fees (`fee_rules`)

Banks charge only on approved payments: a % of the amount plus a fixed fee, rounded to the cent per
payment (so sums can differ from a fee computed on a daily total by a few cents).

| Card | Card from the shop's country | Other EU card | UK or US card |
|---|---|---|---|
| Debit | 0.60% + €0.10 | 0.90% + €0.10 | 2.20% + €0.15 |
| Credit | 0.80% + €0.10 | 1.20% + €0.10 | 2.80% + €0.15 |

The column depends on the card's country vs the **shop's** country, not the bank's. That matches the
real EU: the card bank's share is capped the same for all EU cards, and Visa/Mastercard decide
"cross-border" by the shop's country. So switching bank changes only the bank's own margin:
Bank NL charges exactly this. Bank DE adds 0.20 percentage points to every % (the price of its
sales deal). Bank FR raises its credit % by 0.15 points from 1 Jul 2025; old and new rows carry
valid-from / valid-to dates. 18 rows + 3 new Bank FR rows = 21 rows.

## 6. Shop pricing

Each shop pays the platform a % of the amount plus a fixed fee, on approved payments only (standard
price in the table). Exceptions: the 3 biggest shops negotiated discounts (1.1%, 0.9% and 1.8%, each
+ €0.10), and 2 small shops are still on a 2023 launch price of 1.5% with no fixed fee.
The platform's money on an approved payment = shop price − bank fee − fraud loss.
Which shops lose money follows from these prices and their costs; the true list is in the answer file.

## 7. 3D Secure (extra security check)

- Each shop has one setting all year: 8 shops **always**, 8 **never**, 8 only at or above their
  type's threshold (2 of each per business type).
- On a checked payment: some customers give up (table), recorded as `gave_up` with no bank decision
  (`bank_id` shows the bank it would have gone to); the sale is lost. Fraud chance drops by [60–90%].
  If a checked payment is still fraud, the card's bank pays for it, not the platform.

## 8. Fraud

- Only approved payments can be fraud. Chance = base (table) × UK ×2, US ×3 × amount €100+ ×1.5,
  then the 3D Secure cut.
- The platform guarantees its shops against fraud on payments without 3D Secure. So unchecked fraud
  costs the platform the full amount + a €20 dispute fee.
- Reports arrive 2–26 weeks after the payment (half within about 6 weeks). Reports that would arrive
  after 31 Jan 2026 are missing from the data, so late-2025 fraud looks too low.

## 9. Bank payouts

- One row per shop × bank × day with approved payments: payment count, gross amount, fees taken,
  net amount. The day is the day of approval (a retry approved after midnight counts on the new day). Paid the next working day (Fri–Sun payments are paid on Monday). Fraud refunds are
  settled elsewhere and are not in payouts.
- Errors: one bank (hidden) takes the wrong fee on [2–5%] of its rows. [3–6] payouts never arrive.

## 10. Built-in mess

- About 0.3% of attempt rows appear twice (exact copies, same `attempt_id`).
- Late fraud reports (section 8). Wrong fees and missing payouts (section 9).

## 11. Output tables (`data/raw/`, CSV)

| Table | One row = | Rows | Columns |
|---|---|---|---|
| shops | shop | 24 | shop_id, shop_name, country, business_type, fee_pct, fixed_fee_eur, retries_on_date, three_ds_policy, three_ds_threshold_eur |
| banks | bank | 3 | bank_id, bank_name, country |
| fee_rules | bank × card type × region × period | 21 | bank_id, card_type, region (domestic / other_eu / non_eu), fee_pct, fixed_fee_eur, valid_from, valid_to |
| payment_attempts | one try | ~105k (~100k payments) | attempt_id, payment_id, attempt_number, initiated_by, shop_id, attempted_at, amount_eur, card_country, card_type, bank_id, three_ds_used, outcome (approved / declined / gave_up), decline_type (try_again / permanent) |
| bank_payouts | shop × bank × payment day | ~11k | payout_id, shop_id, bank_id, payment_date, payout_date, payment_count, gross_eur, fees_eur, net_eur |
| fraud_reports | reported payment | ~150 | fraud_report_id, attempt_id, reported_date, amount_eur |

## 12. Hidden answer file (`data/answers/answers.json`)

dbt and Power BI never read it. It is used once, at the end, to score the results. Its SHA-256
fingerprint is committed before analysis starts. It holds:

1. **True effects:** the exact value of every [range] above, plus each effect as the average change in
   approval rate (percentage points) on the payments it affects.
2. **True fraud:** every fraudulent attempt, its report date, and whether the report made it into the data.
3. **True money per shop-month:** approved €, platform fee income, correct bank fees, fraud losses
   (including unreported), dispute fees, margin, and sales lost to declines and to give-ups.
4. **True value of each fix per shop per year** (expected €, from the rules), each in two numbers:
   platform profit and sales recovered for shops. Fixes: local routing (every NL/DE/FR card to its own
   country's bank, other cards to the cheapest bank), cheapest bank for everything, retries on all
   year, 3D Secure always / never / threshold, and each shop's break-even price.
5. **The planted mess:** duplicate attempt ids, payout rows with wrong fees (and the correct fee),
   missing payouts.

## Change log

- v2: fraud and retry ranges lowered to real-world levels; dispute fee €20; shop prices % + fixed fee.
- v3: fee type follows the shop's country, not the bank's; Bank DE surcharge 0.20 points; fixes valued
  in platform profit and in shop sales.
- v4: customers retry by themselves when automatic retries are off; 60% of declines are "try again";
  retail 3D Secure threshold €150; clarified fraud guarantee, fee rounding and `bank_id` on give-ups.
