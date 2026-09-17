# Super Pixel — Take-Home Assignment

This repository is a **take-home coding assignment** for a mid-to-senior
full-stack Ruby on Rails engineer. It contains the brief, the mock data you'll
build against, and a demoable landing page + pixel snippet. It does **not**
contain a solution — building the Rails app is the assignment.

> Inspired by the "catching consent" super-pixel concept: one pixel that runs a
> lead through many fraud/consent detection layers at once and issues a verdict
> plus a consent certificate.

## Changes since submission

Shortly after submitting, I made updates to the credit accounting model and how credits would get charged when **more than one lead from the same account is being processed at the same time**. 
Neither was a scored gap in the original submission. I found them by reasoning through what could go wrong under real concurrent traffic, not from a bug report. 
Full detail is also mentioned in `SOLUTION.md` §5; this is the plain-language version.

**1. Two leads charging credits at the exact same moment could overspend the account's balance.**
*Before:* if two leads from the same account were being verified at the same instant, both could check "does this account have enough credits left?" *before either one had
actually spent anything yet.* Since neither had spent yet, both checks could come back "yes, there's enough" — and both would go ahead and charge.
*After:* before charging, the app now locks that specific account in the database for a brief moment. Account is charged only after a successful layer run so another request won't have to keep waiting for this lock to unlock and only due credits will be charged. If a second lead tries to charge credits for the same account at the
same time, it's forced to wait until the first charge is fully saved before it's even allowed to check the balance so the two charges can never "sneak past" each other.
Other accounts are completely unaffected; only two things touching the *same* account at the *same* moment ever wait on each other.

**2. A related, problem: an account could be told "yes, you can afford this" twice — even though it could really only afford it once.**
*Before:* when a new lead came in, the app checked "does this account have enough credit to run its most critical layers?" — but that check was just a snapshot in time, not a promise. If two leads arrived moments apart, both checks could happen before either lead had actually spent anything, so **both leads would get approved.**
Later, when they actually ran, there wasn't really enough credit for both — so one or even both leads could end up running out of credit *partway through*, meaning some of
their most important fraud/consent checks never got to run at all, and got skipped instead.
*After:* the moment a lead is approved to start, the app immediately **sets aside** ("reserves") the credit its most important checks will need (if the credit is available) — not just a check, an
actual claim on that credit, made in the same locked step described above. So if a second lead comes in moments later and there isn't enough credit left over (because
the first lead's reservation already claimed it), that second lead is honestly and immediately turned away up front — instead of being approved and quietly starving
partway through its most important checks later.

**One trade-off I made on purpose:** the app only reserves credit for a lead's most important checks (critical layers), not every possible layer it might run. In practice this means that, under very low credit, it's possible for two leads to each get their most important
checks completed, rather than one lead getting everything completed. I chose this deliberately — reserving credit for checks that might never even run would waste
capacity for no reason. It also rarely matters in practice because an account running this low on credit already shows up flagged "at risk" on the super-admin dashboard well before it gets anywhere near this point, so it's a visible, known situation.

## Start here
1. Read **[`ASSIGNMENT.md`](ASSIGNMENT.md)** — the full brief and deliverables.
2. Read **[`docs/DESIGN_QUESTIONS.md`](docs/DESIGN_QUESTIONS.md)** — the
   judgement calls we care about, before you write code.
3. Skim **[`docs/provider-modules.md`](docs/provider-modules.md)** and
   **[`docs/data-contracts.md`](docs/data-contracts.md)** to understand the data.
4. Open **[`docs/pixel-spec.md`](docs/pixel-spec.md)** for the pixel + real-time
   requirements.
5. Grading is transparent — see **[`EVALUATION.md`](EVALUATION.md)**.

## Try the live demo right now (no backend needed)
Open `examples/landing-page.html` in a browser, fill in the form, and submit.
The embedded `super-pixel.js` runs in **simulation mode** and streams fake
layer-by-layer results into the live activity panel so you can see the target
experience. Your task is to make that panel reflect **real** results from the
Rails app you build.

```
examples/
├── super-pixel.js     # the embeddable snippet (like a TrustedForm tag)
└── landing-page.html  # a funnel page with a real-time activity panel
```

## What's in this repo
```
ASSIGNMENT.md          # the brief (read first)
EVALUATION.md          # how we grade (open on purpose)
README.md              # this file
docs/                  # provider specs, data contracts, pixel spec, design Qs
mock-data/             # leads, accounts, users, CRM, and 8 provider fixtures
examples/              # pixel snippet + demoable landing page
```

## Timebox
**3–5 business days.** Please don't exceed it. Depth over breadth — a crisp core
with a clear `SOLUTION.md` beats a sprawling half-built system.

## What we're really looking for
How **you** think. Use AI tools if you like, but the follow-up interview digs
into your architecture, and the parts that matter — the data model, the
consensus engine, multi-tenant isolation, credit accounting, and a genuinely
real-time pixel — are the parts you have to drive yourself. Show us your
reasoning.

## Submitting
Push to a Git repo (this zip is structured to become one — see below) and share
the link, or send a zip of your finished app. Include your `SOLUTION.md`.

### Turning this into a GitHub repo
```bash
cd catching-consent-assignment
git init
git add .
git commit -m "Assignment starter kit"
git branch -M main
git remote add origin git@github.com:YOUR-ORG/super-pixel-assignment.git
git push -u origin main
```
