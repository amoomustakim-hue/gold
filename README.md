# GOLD AI

An automated XAUUSD (gold) trading system for **Exness MetaTrader 5**, with two modes:

- **SCALP**: aggressive scalping on 1–5 minute charts
- **NORMAL**: selective 30-minute trend trading (the original spec)

Both modes share the same hard safety limits: a $5 daily loss limit, a verified
stop-loss on every trade, gold only, and no martingale.

> **Status: planning (M0).** No trading code exists yet. Read `docs/PLAN.md` and approve
> it before implementation starts.
>
> Automated trading can lose some or all of the money allocated to it. Nothing in this
> repository is a promise of profit. The system runs on demo until it passes the
> promotion gates in `docs/PLAN.md` §10, and live trading needs explicit owner approval.

## Documents

| File | What it is |
|---|---|
| [`docs/PLAN.md`](docs/PLAN.md) | Research, architecture, risk spec and milestones (**for approval**) |
| [`docs/AMENDMENTS.md`](docs/AMENDMENTS.md) | Owner's changes to the original spec (SCALP mode, $5 daily limit, phone control) |
| [`docs/SPEC.md`](docs/SPEC.md) | Original master specification (v1), Markdown |
| `docs/GOLD_AI_Master_Spec_v1.docx` | Original master specification, Word |

## How it will run

- **Engine:** an MQL5 Expert Advisor inside MT5 on a Windows PC or Windows VPS.
  The MT5 phone app cannot run Expert Advisors.
- **Phone:** the MT5 app to watch trades, push alerts, and a Telegram bot for status / pause /
  emergency stop / mode switch.
- **Claude (optional, later):** pre-session briefings and reports through the Anthropic API.
  Never places or approves trades.

## Setup

Not applicable yet. Setup steps (MetaEditor compile, MT5 config, Telegram bot, VPS)
will be added here as each milestone lands.
