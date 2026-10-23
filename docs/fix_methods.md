# How each fix is valued (Stage 4)

Plan decided on 18 Oct 2026, simplified on 20 Oct 2026 so that every method can be explained in two
sentences, and built from 19 to 23 Oct 2026. Each section below ends with its results on the 2025 data.
The results are findings only; the memo interprets them.

The platform loses money in four places. Stage 4 puts a € value per year on one fix for each:
choosing a different bank, retrying declined payments, repricing shops, and changing 3D Secure
settings. A ranking table then orders the fixes for the Head of Payments.

## What each fix's result looks like

Each fix gets a € value per year, measured on 2025, in two ways:

- **Platform profit**: how many more € per year the platform keeps.
- **Shop sales**: how many more € of sales per year the shops get.

The two values differ a lot. When a fix saves a €100 sale, the shop gets the full €100, but the
platform keeps only its margin on that sale (shop price − bank fee − expected fraud cost), for
example €0.70.

Where a value depends on fraud, it comes as three numbers: a **low € value** (the least the fix is
likely to be worth per year), a **best estimate**, and a **high € value** (the most the fix is likely
to be worth per year). Fraud needs a range because each fraud rate rests on few cases. The other rates
(customers giving up at 3D Secure, payments rescued by retries, approvals by bank) rest on thousands of
payments, so they are used as best estimates, with their payment counts and a one-line caveat.
Retries and bank choice depend on fraud only through the platform's margin, where the range moves the
result very little, so they are given as best estimates too.

## Rules for every fix

1. **One fix at a time.** A fix's value is "2025 with this one change" minus "2025 as it happened".
2. **Groups, not single payments.** Nobody can know what would have happened to one particular
   payment. The models compare groups of similar payments and use their rates. Example with made-up
   numbers: if one bank approves 900 of 1,000 first tries and another bank approves 940 of 1,000
   similar first tries, moving 1,000 such payments gives about 40 more approvals on average.
3. **Fixes are never added together.** Some sales could be saved by two fixes: a payment that a
   better bank would approve on the first try might also be saved by a retry. Adding the fixes would
   count those sales twice, so the ranking shows each fix on its own.
4. **No hidden generator values.** The rulebook shows ranges for the generator's hidden settings.
   The models never use them. Every rate is measured from the data, as an analyst at a real company
   would have to do.
5. **Each fix says what it depends on.** A text column names what must change outside the platform
   for the money to arrive. Repricing depends on the shop accepting the new price. Bank choice
   depends on the new bank accepting the shop. Retries depend on nothing outside the platform.
6. **Simple over precise.** Every method must be one that can be explained in a few sentences. When a
   simpler method answers the question, it is used and its assumption is stated.

## How the low and high € values are made

Fraud is rare, so each business type's fraud rate rests on few cases (6 to 62 on January–July
payments). A count of k cases could easily have come out anywhere between k − 2√k and k + 2√k by
chance, so the fraud rate gets a low and a high value in the same proportion. Example with made-up
numbers: 16 cases costing €3,200 on €800,000 of sales give €0.40 per €100; 16 ± 2 × 4 gives 8 to 24
cases, so the rate lies between €0.20 and €0.60 per €100.

The low € value of a fix uses whichever end of the fraud range makes the fix look worse: the high
fraud value for repricing and checking no payment, and the low fraud value for checking every
payment. A fix that still looks good at its low € value is one the platform can rely on.

Alternatives considered (planned 17–18 Oct 2026, dropped on 20 Oct): a range on every rate (each rate
± 2 standard errors) plus ranges for assumptions; re-running the calculation on 200 random re-draws of
the payments ("bootstrap"). Both are more thorough, but harder to explain than the result is worth here.

## Late fraud reports

Fraud reports arrive weeks or months after the payment (up to 26 weeks; the longest delay in the data
is 182 days), and the data was pulled on 31 Jan 2026. So reported fraud for August to December 2025
is too low: the reports on those payments had not all arrived yet.

The fix: every fraud rate is measured on payments from January to July 2025 only, whose reports have
all arrived, and applied to the whole year's sales. The cutoff date is a dbt variable
(`fraud_complete_before: '2025-08-01'` in `dbt/dbt_project.yml`). The money map keeps reported fraud
only, so its last months stay a lower bound.

Example with made-up numbers: if January–July payments without 3D Secure total €2,000,000 and their
fraud cost the platform €10,000, the rate is €0.50 per €100 of sales. A shop with €300,000 of such
sales in 2025 then gets an expected fraud cost of €1,500.

Assumption: fraud per € of sales is the same in August–December as in January–July.

Alternatives considered: reported fraud only (too low for October to December); a late-report factor
per payment month, which uses all 162 reports instead of 104 (ranges about 25% narrower) but needs a
model that is hard to explain (chosen first, dropped on 18 Oct 2026); doubling the reports of 1–15
December (those payments are incomplete too).

## Fraud cost rates (results)

| Business type | Fraud cases (Jan–Jul, without 3D Secure) | Fraud cost | Sales without 3D Secure | Fraud cost per €100: low / best / high |
| --- | ---: | ---: | ---: | --- |
| Digital subscriptions | 62 | €2,004 | €105,345 | €1.42 / €1.90 / €2.39 |
| Travel | 10 | €4,044 | €1,001,357 | €0.15 / €0.40 / €0.66 |
| Online retail | 16 | €1,106 | €617,877 | €0.09 / €0.18 / €0.27 |
| Food delivery | 6 | €377 | €292,395 | €0.02 / €0.13 / €0.23 |

Applied to each shop's 2025 sales without 3D Secure, the expected fraud cost for the year is €12,614
(best estimate), against €11,700 reported; the gap is the August–December reports that had not arrived
by the data pull. Over all 24 shops, the platform's expected margin is €41,680 a year at the best
estimate (`int_shop_margins`). Four shops lose money at the best estimate: S12, S16, S19 and S01.

## Fix 1: Bank choice

**Question:** how much would the platform and the shops gain per year if Dutch, German and French
cards went to the bank of their own country?

- **Why it could help.** A bank approves cards from its own country more often. Today, travel and
  subscription shops send all cards to Bank DE, and retail and food shops send them to the bank of
  their own country, so many cards go to a bank from another country.
- **Approvals.** For Dutch, German and French cards, the approval rate (approved payments ÷ payments
  that reached a bank) is measured on the card's own-country bank and on another bank, per business
  type. A shop's extra sales = its € of such payments that went to another bank × the difference
  between the two rates.
- **Fees.** The fee rules state what each bank charges, so the fee change on the moved sales is exact.
  Moving sales to Bank DE costs more in fees; moving them away from it costs less.
- **Values.** Shop sales = the extra approved sales. Platform profit = extra sales × the shop's margin
  per €100 + the fee change. Depends on: the new bank accepting the shop.

Example with made-up numbers: a shop has €100,000 of German-card payments on Bank NL. If German cards
are approved 94% of the time on Bank DE and 90% on other banks, routing them to Bank DE adds about
€4,000 of sales a year. At a margin of €0.70 per €100, that is €28 of platform profit, minus the extra
fee Bank DE charges on the moved sales.

Caveat: the two rates compare different cards (for example German cards on Bank DE with Dutch cards on
Bank DE), so the method assumes a card's country itself does not change how often it is approved.

Alternatives considered: two routing plans (local routing and the cheapest bank for everything),
compared within groups alike in business type, card country, card type and amount (planned 17 Oct,
dropped 20 Oct as too complex to explain); a simple table per bank (misleading, because Bank DE
carries the riskier shops and most UK and US cards).

Data check: per business type, 4,300–16,300 Dutch, German and French card payments reached their
own-country bank, and 6,200–10,900 reached another bank.

**Results (2025, per year).** The own-country bank approves more in every business type: digital
subscriptions 92.2% against 91.0%, food delivery 95.6% against 93.2%, online retail 94.5% against 92.2%,
travel 91.4% against 87.8%. Routing at all 24 shops would add €152,026 of shop sales, cut bank fees by
€5,141 and add €5,729 of platform profit. Routing pays the platform at 16 shops (+€5,948 of profit,
+€144,378 of shop sales, €5,388 of fees saved). At the other 8 it costs the platform a little, mostly
at retail and food shops whose German cards would move to Bank DE and pay its higher fee. The largest
gain is S07 (travel): +€74,132 of sales and +€2,598 of profit.

## Fix 2: Retries

**Question:** how much do automatic retries add, beyond what customers already save by pressing
"pay" again themselves?

- **Measure.** The rescue rate is the share of payments whose first try was declined with "try again"
  that ended approved. It is measured twice over 2025 for each business type: on payments made while
  the shop had retries on, and on payments made while it had them off. With retries off, some customers retry by themselves,
  so the rate with retries off is not zero.
- **Value per shop.** Shop sales = the shop's € of payments with a first try declined "try again" ×
  (rescue rate with retries on − rescue rate with retries off). Platform profit = that × the shop's
  margin per €100. The action is switching retries on for the 6 shops that never had them; the other
  18 shops show what the feature already earns. Depends on: nothing outside the platform.

Example with made-up numbers: if 40% of such payments end approved with retries on and 25% with
retries off, a shop with €20,000 of first-try "try again" declines gains €20,000 × 15% = €3,000 of
sales a year.

Caveat: "try again" declines are more common in November and December. The method assumes the season
changes how many such declines there are, not the share that ends approved.

Alternatives considered: comparing switched-on and not-yet shops in the same weeks (planned 17 Oct,
dropped 20 Oct as too complex to explain); counting the sales saved by platform retries (overstates
the gain, because customers retry by themselves when retries are off).

Data check: 3,258 payments had a first try declined "try again" while retries were off, and 2,559
while they were on.

**Results (2025, per year).** Rescue rates with retries on / off: digital subscriptions 23.7% / 5.7%,
food delivery 28.0% / 5.1%, online retail 25.2% / 6.2%, travel 22.9% / 7.6%. Switching retries on at
the 6 shops that never had them adds €44,639 of shop sales and €248 of platform profit. S08 (travel)
alone accounts for €32,222 of those sales and €265 of the profit. S12 and S19 lose the platform a few
euros, because each extra sale there is at a loss-making price until they are repriced. The 18 shops
that already have retries get €153,591 of sales a year from the feature.

## Fix 3: Shop repricing

**Question:** which shops pay the platform less than their payments cost it, and what price protects
the platform?

- **Cost per shop per year:** bank fees + expected fraud cost (the business type's fraud cost per €100
  × the shop's sales without 3D Secure). A shop's own reports are too few to price on (about 6 per
  shop).
- **Who moves.** Shops that lose money at the best estimate. A shop that is profitable at the best
  estimate but loses money at the high fraud value is flagged (`is_loss_only_at_high_fraud`), not
  repriced.
- **Safe price.** The % that still breaks even when fraud is at its high value, with the shop's fixed
  fee kept: safe % = (bank fees + high fraud cost − fixed fee income) ÷ sales × 100. Example with
  made-up numbers: sales €1,000,000, bank fees €10,500, high fraud cost €2,500 and fixed fees €2,000
  give (10,500 + 2,500 − 2,000) ÷ 1,000,000 × 100 = 1.1%.
- **Values.** Platform profit = new price income − current price income: one exact number per year
  (low = best = high), equal to the shop's loss at the high fraud value. Shop sales = €0, because the
  shop doesn't sell more; it pays more. Depends on: the shop accepting the new price.
- **Margin after repricing** gets low, best and high values; its low value is €0 by design.
- **Fraud flag** (`has_high_own_fraud`). A shop's own January–July fraud cases are compared with the
  number its business type's rate predicts: expected cases = the shop's share of the type's sales
  without 3D Secure × the type's cases. The shop is flagged when its cases exceed expected + 2√expected.
  Such a shop needs a fraud review, which is a different action from pricing.

Alternatives considered: plain break-even (a small rise in fraud would make the shop lose the
platform money again); the standard price of its business type; repricing every shop below its safe
price (would raise standard-price shops whose risk comes mainly from their 3D Secure setting);
flagging by comparing fraud rates (would flag shops with 1 or 2 cases).

**Results (2025, per year).**

| Shop | Business type | Current price | Safe price | Extra price income | Margin after repricing (best estimate) |
| --- | --- | --- | --- | ---: | ---: |
| S12 | travel | 1.5% + €0 | 2.28% + €0 | €2,572 | €842 |
| S16 | digital subscriptions | 1.5% + €0 | 4.53% + €0 | €1,302 | €207 |
| S01 | online retail | 1.1% + €0.10 | 1.20% + €0.10 | €1,241 | €727 |
| S19 | food delivery | 0.9% + €0.10 | 1.15% + €0.10 | €954 | €398 |
| **Total** | | | | **€6,068** | |

All four are on special prices: S12 and S16 on the 2023 launch price, S01 and S19 on negotiated
discounts. S16's 4.53% looks high because it has no fixed fee; the standard subscription price (2.4% +
€0.25) on its average payment of about €13 comes to about 4.3%. Flags: S14 (digital subscriptions) had
29 fraud cases where its type's rate predicts about 15 (high end 23), so it needs a fraud review; S13 is
profitable at the best estimate (+€220) but loses money at the high fraud value (−€183).

## Fix 4: 3D Secure

**Question:** for each shop, would checking every payment, or checking none, earn more than its
current setting?

- **What the setting changes.** On a checked payment, some customers give up: the shop loses the sale
  and the platform loses its margin on it. An unchecked payment that turns out to be fraud costs the
  platform the amount plus a €20 dispute fee; on a checked payment, the card owner's bank pays.
- **Measure.** The give-up rate is the share of checked payments where the customer gave up, per
  business type. The fraud cost per €100 of sales without 3D Secure comes from `int_fraud_cost_rates`.
- **Check every payment** (applies to the shop's sales that were not checked): platform profit =
  fraud cost saved − give-up rate × (price − bank fee) on those sales; shop sales = − give-up rate ×
  those sales.
- **Check no payment** (applies to the shop's checked payments): the customers who gave up now buy,
  so shop sales = + the shop's € of give-ups; platform profit = (price − bank fee) on those recovered
  sales − the fraud cost the platform now pays on all the formerly checked sales.
- **Best option per shop:** the one with the higher platform profit at the best estimate, if it beats
  the current setting. Shop sales are shown beside it. Depends on: nothing outside the platform.

Example with made-up numbers: a shop has €100,000 of unchecked sales, a fraud cost of €0.50 per €100,
a give-up rate of 10% and a price minus bank fee of €1.20 per €100. Checking every payment saves €500
of fraud cost but loses €10,000 of sales and €120 of margin: +€380 a year for the platform and
−€10,000 for the shop.

Assumptions: fraud costs the same per € on small and large payments within a business type, so the
"only above an amount" setting is not valued; customers who give up at the check would have been
approved without it.

Alternative considered: give-up and fraud rates per business type × amount band, applied to each
shop's payments under all three settings (planned 17 Oct; on January–July payments the bands hold
0–55 fraud cases).

Data check: fraud cases on January–July payments without 3D Secure number 62 for digital
subscriptions, 16 for online retail, 10 for travel and 6 for food delivery. Checked payments number
6,900–17,000 per business type.

**Results (2025, per year).** Give-up rates at the check: digital subscriptions 13.7%, food delivery
10.0%, online retail 6.0%, travel 4.3%.

| Option | Platform profit (low / best / high) | Shop sales |
| --- | --- | ---: |
| Check every payment | €4,984 / €11,494 / €18,002 | −€214,555 |
| Check no payment | −€51,439 / −€31,118 / −€10,797 | +€478,588 |

Checking every payment raises platform profit at each of the 16 shops that do not already check every
payment, but the shops lose about €19 of sales for each €1 the platform gains. Checking no payment
gives the shops back every sale lost to give-ups, at a net cost to the platform of about €31,000 a year.
The largest platform gains from checking every payment are S09 (+€3,853), S01 (+€1,416), S12 (+€1,348)
and S13 (+€1,339).

## Ranking

`fct_fix_ranking` has one row per fix option (5 rows; 3D Secure gets two, so its trade-off stays
visible) and ranks them by the low € value of platform profit, so the money the platform is fairly sure
of comes first. Shop sales sit next to profit, and each option keeps its "depends on" label. Retries
count the 6 shops that never switched on; bank choice counts the 16 shops where routing gains at the best
estimate. Fixes are never added together.

| Rank | Fix option | Platform profit per year (low / best / high) | Shop sales per year | Depends on |
| ---: | --- | --- | ---: | --- |
| 1 | Reprice loss-making shops | €6,068 / €6,068 / €6,068 | €0 | Shops accept the new price |
| 2 | Route Dutch, German and French cards to their own-country bank | €5,948 | +€144,378 | The new bank accepts the shop |
| 3 | 3D Secure on every payment | €4,984 / €11,494 / €18,002 | −€214,555 | Nothing outside the platform |
| 4 | Retries on at the 6 never-on shops | €248 | +€44,639 | Nothing outside the platform |
| 5 | 3D Secure on no payment | −€51,439 / −€31,118 / −€10,797 | +€478,588 | Nothing outside the platform |

Findings across the fixes:
- The platform keeps about €0.37 of every €100 of sales (`fct_money_map`: €42,594 on €11.5M), so a fix
  that saves sales is worth far more to the shops than to the platform.
- The two options with the most certain platform profit both depend on someone outside the platform:
  the shops accepting new prices, and the banks accepting the shops.
- Checking every payment gains the platform €1 for about every €19 of sales the shops lose.

## Models

| # | Model | One row = | What it is for |
| --- | --- | --- | --- |
| 1 | `int_fraud_cost_rates` (view) | one business type (4 rows) | fraud cost per €100 of sales without 3D Secure, measured on January–July payments, with low, best and high values |
| 2 | `int_shop_margins` (view) | one shop (24 rows) | each shop's yearly price, bank fees, expected fraud and margin, in € and per €100, with low, best and high values |
| 3 | `fct_fix_repricing` (table) | one shop (24 rows) | safe %, who moves, extra price income, margin after repricing, two flags |
| 4 | `fct_fix_three_ds` (table) | one shop (24 rows), one column group per option | platform profit and shop sales of checking every payment or no payment, against the current setting |
| 5 | `fct_fix_retries` (table) | one shop (24 rows) | shop sales and platform profit from retries on all year |
| 6 | `fct_fix_bank_choice` (table) | one shop (24 rows) | approval gain and fee change from routing Dutch, German and French cards to their own country's bank |
| 7 | `fct_fix_ranking` (table) | one fix option (5 rows) | totals per fix option, low/best/high values, "depends on", rank |

All seven are built (19–23 Oct 2026), each with a YAML file of tests (36 in all); `dbt build` runs
17 models and 127 tests. Grain, inputs and tests per model: `docs/data_model.md`, "Fix models".

## Decisions made while building

- The fraud cutoff date and the "2" of the chance range are dbt variables in `dbt/dbt_project.yml`
  (`fraud_complete_before`, `standard_errors_in_range`).
- Late fraud reports: January–July fraud rates applied to the whole year (see "Late fraud reports").
- Fraud rates per business type only, not split by payment size.
- Repricing: only shops losing money at the best estimate move; fraud flag via expected cases
  + 2√expected; extra price income = new price income − current price income, which equals minus the
  low margin to the cent (the current price income is rounded to the cent on each payment).
- 20 Oct 2026: plan simplified as described above. Smaller choices are settled at each model with a
  short recommendation.
- 21 Oct 2026: `fct_fix_three_ds` has one row per shop with a column group per option, instead of one
  row per shop and option.
- 21 Oct 2026: retries use one rescue rate per business type (travel's difference is 15.3 points
  against 18.0 for all shops together, and travel shop S08 carries most of the value).
- 21 Oct 2026: retries and bank choice give the best estimate of platform profit only (the fraud range
  moved the retries value by about ±€40). Money columns are rounded to the cent, so values that should
  be equal compare as equal.
- 22 Oct 2026: the ranking has 5 rows (3D Secure every payment and no payment), and bank choice counts
  only the shops where routing gains at the best estimate, because routing can be set per shop.
