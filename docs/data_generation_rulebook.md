# Data Generation Rulebook

This document describes the simulated world the data comes from. The generator (`python/generate_data.py`) follows these rules with a fixed seed, so it always produces the same output files.

Some values are written as a range in square brackets, like [20–40%]. The generator picks the exact value and writes it only to the hidden answer file. The rules of the world are known, but the true size of each effect is not: the analysis has to measure it from the data.

## Context
- The data is modelled on how payment platforms such as Stripe and PayPal work.
- The platform's selling point is fraud protection included in the price. Shops don't pay for stolen-card payments, and they don't have to force the 3D Secure check on every customer, which would make some customers give up at checkout. Instead, the platform pays for fraud on payments made without the check: the amount back to the card owner plus a €20 dispute fee.
- This makes the platform an easy choice for shops, but it puts the fraud risk on the platform's own margin. The data is built to show what that promise costs, which shops make it expensive, and how 3D Secure settings shift money between fraud losses and lost sales.

## Structure
- The year is 2025. All times are in UTC and all amounts in EUR. The data is pulled on 31 Jan 2026.
- There are 24 shops, 6 in each business type: online retail, travel, digital subscriptions and food
  delivery. 8 shops are in the Netherlands, 8 in Germany and 8 in France.
- Shop sizes vary: 3 big shops (11,500–17,000 payments a year), 6 medium (4,000–7,000) and 15 small
  (600–3,500). That is about 100,000 payments in total.
- There are 3 banks: Bank NL, Bank DE and Bank FR. They represent banking options from three countries, with slightly different fees.
- Card payments come from 6 countries: NL, DE, FR, ES, UK and US. A card's local bank is the bank in its own
  country, so only Dutch, German and French cards have one. A local bank approves more cards but
  charges the same fee.
- Payments are quiet at night and busiest between 16:00 and 20:00 UTC. Food delivery is the most
  evening-heavy.

## The four business types

**Online retail.**
- Median payment €55 (€5–1,500).
- Busier in November (×1.5), in Black Friday week, 24–30 Nov (×3), and on 1–23 December (×1.8).
- Cards: 65% from the shop's country, 25% other EU, 6% UK, 4% US; 35% credit.
- First-try decline chance 7%.
- Fraud chance [0.08–0.15%].
- Customers giving up at 3D Secure [6–12%].
- 3D Secure threshold €150.
- Standard price 1.6% + €0.25.

**Travel.**
- Median payment €380 (€40–4,000).
- Busier January–March (×1.3, summer bookings).
- Cards: 40% from the shop's country, 25% other EU, 20% UK, 15% US; 60% credit.
- First-try decline chance 11%.
- Fraud chance [0.15–0.35%].
- Customers giving up at 3D Secure [3–8%].
- 3D Secure threshold €250.
- Standard price 2.4% + €0.25.

**Digital subscriptions.**
- Fixed prices from €4.99 to €29.99.
- No busy periods.
- Cards: 55% from the shop's country, 25% other EU, 12% UK, 8% US; 45% credit.
- First-try decline chance 10%.
- Fraud chance [0.25–0.5%].
- Customers giving up at 3D Secure [8–14%].
- 3D Secure threshold €15.
- Standard price 2.4% + €0.25.

**Food delivery.**
- Median payment €27 (€8–150).
- Busier Friday–Sunday (×1.5) and December–February (×1.2).
- Cards: 85% from the shop's country, 10% other EU, 3% UK, 2% US; 20% credit.
- First-try decline chance 6%.
- Fraud chance [0.04–0.10%].
- Customers giving up at 3D Secure [10–18%].
- 3D Secure threshold €40.
- Standard price 1.4% + €0.25.

"Other EU" cards are split evenly over the other three of NL, DE, FR and ES. UK and US cards are 70%
credit.

## Approvals and declines

A first try's decline chance starts from its business type's chance and is multiplied by:

- ×1.5 for a UK card and ×2 for a US card (banks trust foreign cards less)
- ×1.2 for a debit card (more "not enough money")
- ×1.5 for €500 or more
- ×[0.55–0.80] on the card's local bank
- ×[0.90–1.10] for each bank's own level

60% of declines are "try again" (temporary, such as a busy bank or not enough money right now) and 40% are permanent (a blocked card or wrong details). 
In November and December, "try again" declines are 1.3 times as common. 3D Secure does not change the chance of approval.

## Which bank a shop uses

- Retail and food shops use the bank in their own country.
- All travel and subscription shops use Bank DE, wherever they are. In 2023 Bank DE offered these riskier shops a quick sign-up. It was a sales deal, not a quality choice.
- The 8 biggest shops send 30% of their payments, picked at random, to a second bank as a backup.

So Bank DE carries the riskier shops and most UK and US cards. A simple bank-against-bank comparison makes it look worst on both approvals and fees, even though the cards it gets are harder.

## Retries

- Automatic retries are switched on for 6 shops on 17 Mar 2025, 6 more on 9 Jun and another 6 on 15 Sep. The last 6 shops never switch them on. Each group mixes business types and sizes.
- With retries on, the platform retries a "try again" decline after 5 minutes and, if it is declined again, once more after 1 hour. The first retry is approved [15–30%] of the time, the second [5–15%]. Customers wait and don't retry themselves.
- With retries off, [25–45%] of customers with a "try again" decline press "pay" once more within 10 minutes. That try is approved as often as the platform's first retry. So some sales are saved even without the feature, and counting the approved platform retries overstates what it adds.
- A failed retry, by the platform or by the customer, is recorded as "try again".
- Permanent declines and customers who gave up are never retried. Retries go to the same bank and keep the 3D Secure result. Each retry is its own row, linked to its payment by `payment_id`. `initiated_by` says whether the customer or the platform made the try; the first try is always the customer's.

## Bank fees

Banks charge only on approved payments: a % of the amount plus a fixed fee, rounded to the cent on each payment. The fee depends on the card type, and on where the card comes from compared with the shop's country:

- Debit card from the shop's country: 0.60% + €0.10. From another EU country: 0.90% + €0.10. From the UK or US: 2.20% + €0.15.
- Credit card from the shop's country: 0.80% + €0.10. From another EU country: 1.20% + €0.10. From the UK or US: 2.80% + €0.15.

The fee follows the shop's country, not the bank's, as it does in the EU. So switching banks changes only the bank's own margin. Bank NL charges exactly the fees above. Bank DE adds 0.20 percentage points to every %. Bank FR raises its credit % by 0.15 points from 1 Jul 2025, so its credit rules have an old and a new row with valid-from and valid-to dates. That makes 21 fee rules.

## Shop prices

Each shop pays the platform a % of the amount plus a fixed fee, on approved payments only. Most shops pay their business type's standard price. The 3 biggest shops negotiated discounts (1.1%, 0.9% and 1.8%, each + €0.10), and 2 small shops are still on a 2023 launch price of 1.5% with no fixed fee.

On each approved payment, the platform earns the shop's price minus the bank fee minus any fraud loss. Which shops lose money follows from their prices and costs; the true list is in the answer file.

## 3D Secure

- The platform chooses each shop's 3D Secure setting, because it carries the fraud risk on payments without the check.
- Each shop keeps one setting all year: 8 shops check every payment, 8 check none, and 8 check only payments at or above their type's threshold (2 shops of each setting per business type).
- On a checked payment, some customers give up. That try is recorded as `gave_up` with no bank decision (`bank_id` shows the bank it would have gone to), and the sale is lost. The check cuts the fraud chance by [60–90%]. If a checked payment is still fraud, the card owner's bank pays, not the platform.

## Fraud

- Only approved payments can be fraud. The chance starts from the business type's chance and is multiplied by 2 for a UK card, 3 for a US card and 1.5 for €100 or more, then cut by 3D Secure if the payment was checked.
- Fraud protection is included in every shop's price. When a payment without 3D Secure is reported as fraud, the amount goes back to the card owner and the bank charges a €20 dispute fee. The platform pays both, and the shop pays nothing.
- Reports arrive 2–26 weeks after the payment, half of them within about 6 weeks. Reports that would arrive after 31 Jan 2026 are missing from the data, so late-2025 fraud looks too low.

## Bank payouts

- There is one payout per shop, bank and day with approved payments. It shows the number of payments, the gross amount, the fee the bank took and the net amount. The day is the day of approval, and the money arrives the next working day (Friday–Sunday payments arrive on Monday). Fraud refunds are settled separately and are not in the payouts.
- The bank pays each payout to the platform after keeping its fee. The platform keeps the shop's price minus that fee and pays the rest to the shop; that last transfer is not in the data. Example: on a €50 payment with a shop price of €1.05 and a bank fee of €0.40, the platform receives €49.60, keeps €0.65 and pays the shop €48.95.
- One bank (hidden) takes the wrong fee on [2–5%] of its payouts, and [3–6] payouts never arrive.

## Planted problems

- About 0.3% of payment attempt rows appear twice, as exact copies with the same `attempt_id`.
- Fraud reports arrive late (see Fraud).
- One bank takes wrong fees, and some payouts never arrive (see Bank payouts).

## Output tables

The generator writes six CSV files to `data/raw/`:

- **shops** (24 rows): shop_id, shop_name, country, business_type, fee_pct, fixed_fee_eur, retries_on_date, three_ds_policy, three_ds_threshold_eur
- **banks** (3 rows): bank_id, bank_name, country
- **fee_rules** (21 rows): bank_id, card_type, region (domestic, other_eu or non_eu), fee_pct, fixed_fee_eur, valid_from, valid_to
- **payment_attempts** (one row per try, about 105,000): attempt_id, payment_id, attempt_number, initiated_by, shop_id, attempted_at, amount_eur, card_country, card_type, bank_id, three_ds_used, outcome (approved, declined or gave_up), decline_type (try_again or permanent)
- **bank_payouts** (one row per shop, bank and payment day, about 11,000): payout_id, shop_id, bank_id, payment_date, payout_date, payment_count, gross_eur, fees_eur, net_eur
- **fraud_reports** (one row per reported payment, about 150): fraud_report_id, attempt_id, reported_date, amount_eur

## Hidden answer file

`data/answers/answers.json` holds the true answers. dbt and the dashboard never read it. It was used once, at the end, to check the results, and its SHA-256 fingerprint was committed before the analysis started. It contains:

- the exact value of every range above, and each effect as the average change in approval rate
- every fraudulent payment, its report date, and whether the report made it into the data
- the true money per shop and month: sales, platform revenue, correct bank fees, fraud losses (including unreported ones), dispute fees, margin, and sales lost to declines and give-ups
- the true yearly value of each fix per shop, in platform profit and in shop sales: local routing, the cheapest bank for everything, retries on all year, 3D Secure on every, no or only bigger payments, and each shop's break-even price
- the planted problems: duplicate attempt IDs, payouts with a wrong fee (and the correct fee), and missing payouts
