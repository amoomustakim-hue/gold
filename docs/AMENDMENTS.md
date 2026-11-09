# Spec amendments

`docs/SPEC.md` is the original master specification (v1). The spec says approved
specifications must not be changed silently, so every change the owner makes is
recorded here with its date and reason. When this file conflicts with `SPEC.md`,
**this file wins** for the items it lists. Everything not listed still follows `SPEC.md`.

| # | Date | Spec section | Original | Amended to | Decided by |
|---|------|--------------|----------|------------|------------|
| A1 | 2026-11-09 | §2, §11 | One trading style: M30 decisions, H4/H1 context, M15 entry | **Two modes.** `NORMAL` = the original spec unchanged. `SCALP` = new aggressive scalping mode (A2–A4). A switch selects the mode. | Owner |
| A2 | 2026-11-09 | §2, §11 | Timeframes M30/H4/H1/M15 | `SCALP` mode: entries and exits on **M1–M5**, with M15 and H1 for trend context only | Owner |
| A3 | 2026-11-09 | §2, §16 | Daily lockout at 10% equity drawdown | **$5 daily loss limit** (equity-based, persistent, restart-safe). This is 25% of a $20 account. It applies in both modes. If a percentage limit is also set, whichever is **stricter** applies. | Owner |
| A4 | 2026-11-09 | §2, §19 | Maximum 3 new entries per day | `SCALP`: maximum **15** per day (proposed default, owner may change). `NORMAL`: 3, unchanged. | Proposed, awaiting confirmation |
| A5 | 2026-11-09 | §2 | Initial account: $20 Standard Demo | Demo balance **$1,000**, but the EA sizes trades and applies limits **as if the account held $20** (a "virtual balance"), so demo results reflect what a real $20 account would face. Real-money start, if ever approved: **$20**. | Owner (virtual balance proposed) |
| A6 | 2026-11-09 | §5 | Don't optimise for fast growth | Owner wants aggressive scalping ("make mad money"). Recorded as the owner's **aspiration**, not a design target or a promise. Everything from the original spec still applies: hard limits, the no-martingale rule, a verified stop on every trade, and no live trading without explicit approval. | Owner, with risk acknowledged |
| A7 | 2026-11-09 | §38 | Telegram notification-only in v1 | Phone control is allowed, limited to **risk-reducing** commands that work instantly (status, pause, emergency stop, switch to NORMAL). Switching to `SCALP` or resuming needs an extra confirmation. No phone command can raise limits or remove stops. | Owner asked for phone control; restriction proposed |

## Unchanged and non-negotiable (restated for clarity)

- XAUUSD only. No martingale, grid, averaging down, or raising risk after a loss.
- Every position has a broker-side stop-loss, verified after the fill.
- The MQL5 EA is the only execution authority. Claude, Python, Telegram and the
  dashboard cannot override it.
- If the minimum lot would exceed the allowed risk, the trade is skipped. Volume is never rounded up.
- Live mode never switches on automatically.
