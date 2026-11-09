# GOLD AI

An automated XAUUSD (gold) trading system for **Exness MetaTrader 5**, with two modes:

- **SCALP**: aggressive scalping on 1–5 minute charts
- **NORMAL**: selective 30-minute trend trading (the original spec)

Both modes share the same hard safety limits: a $5 daily loss limit, a verified
stop-loss on every trade, gold only, and no martingale.

> **Status: M1 (risk engine) written, awaiting first compile and test on Windows.**
> The EA has **no trading strategy yet**. It can't trade on its own.
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
- **Phone:** the MT5 app to watch trades, plus MT5 push alerts. The remote-control channel will be chosen before M5.
- **Claude (optional, later):** pre-session briefings and reports through the Anthropic API.
  Never places or approves trades.

## Repository layout

```
mql5/Include/GOLD_AI/       risk engine modules (Types, Config, Sizing, RiskCore, StateCodec,
                            StateStore, Guards, Execution, Journal)
mql5/Experts/GOLD_AI/       GOLD_AI.mq5, the Expert Advisor
mql5/Scripts/GOLD_AI_Tests/ GOLD_AI_RiskTests.mq5, unit tests (no orders)
docs/                       spec, amendments, plan, runbooks
```

## Setup

Install, compile, test and run on Windows: **[docs/runbooks/M1-install-and-test.md](docs/runbooks/M1-install-and-test.md)**.

Key EA inputs: `InpExpectedLogin` (required, your account number), `InpMode` (SCALP/NORMAL),
`InpVirtualStart` (20 = a $1,000 demo behaves like $20), `InpDailyLossUSD` (5),
`InpEmergencyStop`, `InpSelfTestTrade` (demo-only stop-loss pipeline test).

Files the EA writes: `%APPDATA%\MetaQuotes\Terminal\Common\Files\GOLD_AI\` (journal, state, status, test results).
