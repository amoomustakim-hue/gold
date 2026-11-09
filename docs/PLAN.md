# GOLD AI: Research and Architecture Plan (v0.1, for approval)

> **Status: APPROVED by owner 2026-11-09.** Decisions from §13 are recorded in `AMENDMENTS.md` (A4, A7b, A8–A10).
> Required by `SPEC.md` Part XII. Includes the owner's changes in `AMENDMENTS.md`
> (SCALP mode, $5 daily limit, mode switch, phone control).
>
> **Evidence labels used below:** **[FACT]** = platform/broker documentation;
> **[3P]** = third-party source, must be verified at runtime;
> **[HYP]** = hypothesis to be tested; **[REC]** = my engineering recommendation.
>
> **What I could and could not do:** I wrote this in a Linux cloud environment with
> no MetaTrader 5, no Exness account and no historical tick data. Nothing here has
> been backtested. Every number about strategy performance is a hypothesis.
> Every broker figure must be read live from MT5 at runtime. That is a design
> requirement anyway (§3).

---

## 1. Executive summary

GOLD AI is an automated gold (XAUUSD) trading bot for Exness MetaTrader 5, with two modes:

- **SCALP**: fast entries and exits on 1–5 minute charts, small targets, up to ~15 trades a day.
- **NORMAL**: the original spec. 30-minute decisions, selective, at most 3 trades a day.

A single MQL5 Expert Advisor (EA) runs on Windows (your PC or a Windows VPS).
It places every order and enforces every hard rule. Your phone sees everything
through the MT5 app and alerts, and controls the bot through a locked-down
Telegram bot. Claude (Anthropic API) is optional and **out of the per-trade loop**:
an API call takes seconds, which is too slow for a 1-minute scalp. Claude is used
for pre-session briefings, daily and weekly reports, and research.

### The main risks, in plain language

1. **Costs may eat the edge.** The spread on Exness's Standard account is reported
   at around **$0.20 per ounce** **[3P]**. On a scalp that risks $2 to make $2, that cost means
   you need to win **about 55%** of trades just to break even (worked example in §4.3).
   Most retail scalping strategies fail exactly here. If backtests show no edge after
   realistic costs, the honest result is "don't run SCALP mode", and I'll report it.
2. **A $20 account cannot size down.** The smallest trade is 0.01 lot ≈ 1 oz, where
   each $1 gold moves ≈ $1 of profit or loss **[3P, verify]**. A sensible M1/M5 stop is ~$1.50–$3, so each
   scalp risks **8–15% of the account** with no way to risk less. The $5 daily limit
   means about two losing trades end the day. About ten net losses would wipe the account out.
3. **Execution matters more for scalping.** Slippage, requotes, spread spikes and
   latency hurt a $2-target trade far more than a $20-target trade. Demo fills are
   usually kinder than real fills (§6).
4. **"Mad money" is not something any design can promise.** The fastest *legitimate*
   growth path is: a tested positive edge, fixed-fraction sizing that grows with
   the account, and hard limits that stop the bad days. That is what this plan builds.
   Raising risk to chase returns is what the spec forbids, and what usually ends small accounts.

---

## 2. XAUUSD market research summary

| Topic | What we know | Source quality |
|---|---|---|
| Price level | Gold traded roughly **$3,900–$4,200** in early Nov 2026, after an all-time high of ~$5,600 in Jan 2026 | [3P] news and Trading Economics |
| Contract | 1 standard lot = 100 oz. Min 0.01 lot = 1 oz. So $1 price move × 0.01 lot ≈ $1 P&L | [3P]; **read `SYMBOL_TRADE_CONTRACT_SIZE`, `SYMBOL_VOLUME_MIN/STEP`, `SYMBOL_TRADE_TICK_VALUE/SIZE` at runtime** |
| Spread (Standard acct) | Third-party reports ~$0.18–$0.25 per oz typical, wider at rollover and on news | [3P]; Exness publishes previous-day averages on its contract-spec page. **Measure live.** |
| Intraday pattern | Gold volatility, volume and spreads follow repeating intraday patterns (Batten et al. 2017, 15+ yrs of 5-min data). Activity is concentrated around the main market opens and closes. | Peer-reviewed; COMEX/spot data, not Exness CFD |
| Sessions | Studies split trading into Tokyo / London / New York sessions. The New York day session shows more "informed" trading (Iwatsubo et al. 2018). The popular "London–NY overlap is best" claim comes mostly from **retail surveys, not volatility studies**. | Mixed; we'll **measure by session on Exness ticks** |
| Macro drivers | USD, real yields, CPI, NFP, FOMC and geopolitical shocks move gold hard and fast. Spreads widen around releases. | Well established; specifics measured in backtest |
| Daily break / rollover | Spreads widen sharply around the daily rollover, and gold CFDs typically have a short daily trading break | [3P]; **read session times from `SymbolInfoSessionTrade` at runtime** |

**Limitations:** the academic studies use exchange futures data, not Exness CFD
quotes. Broker spreads, the daily break and fill behaviour must come from Exness
data itself. Everything in this table will be re-measured in Phase 1 from Exness tick history.

---

## 3. Exness / MT5 runtime checklist

The EA reads all of these on start-up and refuses to trade if any are missing or inconsistent:

| Check | MQL5 source | Fail-safe |
|---|---|---|
| Exact symbol name (`XAUUSD`, or with a suffix like `XAUUSDm`) | `SymbolInfoString`, configured allow-list | Mismatch or ambiguity → refuse to trade |
| Not a different gold product (e.g. `XAUUSDc`, `XAUEUR`) | Exact string match against the allow-list | Refuse |
| Account login / server / demo vs real | `AccountInfoInteger(ACCOUNT_LOGIN / ACCOUNT_TRADE_MODE)`, `AccountInfoString(ACCOUNT_SERVER)` | Mode mismatch → block new trades |
| Contract size, tick size, tick value | `SYMBOL_TRADE_CONTRACT_SIZE`, `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_TRADE_TICK_VALUE_LOSS` | Zero or unexpected → refuse |
| Volume min / step / max | `SYMBOL_VOLUME_MIN/STEP/MAX` | Used in sizing. Never rounded up. |
| Stop level and freeze level | `SYMBOL_TRADE_STOPS_LEVEL`, `SYMBOL_TRADE_FREEZE_LEVEL` | Stop closer than allowed → skip the trade |
| Filling mode | `SYMBOL_FILLING_MODE` | Pick a supported fill type, or refuse |
| Margin needed | `OrderCalcMargin` | Free margin too low → skip |
| Profit check | `OrderCalcProfit` cross-checks our risk maths | Disagreement > tolerance → refuse and alert |
| Trading sessions | `SymbolInfoSessionTrade` | Outside the session or near the daily break → no new trades |
| Live spread, tick freshness | `SymbolInfoTick`, time of last tick | Stale or wide → no new trades |
| Connection and latency | `TerminalInfoInteger(TERMINAL_CONNECTED / TERMINAL_PING_LAST)` | Disconnected or ping too high → no new SCALP trades |
| Algo trading allowed | `TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)`, `MQLInfoInteger(MQL_TRADE_ALLOWED)` | Off → idle, alert |

---

## 4. Strategy research and recommendation

### 4.1 SCALP mode candidates (new)

| ID | Idea | Timeframes | Initial role |
|---|---|---|---|
| **S1 Trend micro-pullback** | Trade only in the direction the H1 and M15 trend agree on. Wait for M1 to pull back into EMA20 / session VWAP, then enter when M1 breaks the pullback's micro high (micro low for shorts). Stop beyond the pullback extreme. | H1 + M15 context, M5 trend, M1 trigger | **Primary [HYP]** |
| **S2 Session-open breakout** | Mark the first 15 minutes of the London or New York open as a range. Enter on an M1 *close* outside it that holds, with volatility rising. Optional retest entry. Skip when a major release is due nearby. | M1/M5 | **Secondary [HYP]** |
| **S3 VWAP reversion in ranges** | Only when the market is objectively flat (low ADX, narrow bands): fade the edges back toward VWAP. | M5 | **Postponed.** Fade strategies are hurt most by costs. Revisit if S1/S2 data supports it. |
| **S4 Liquidity sweep + reclaim** | Price runs a prior high or low, then quickly reclaims it. | M1/M5 | **Confirmation filter only**, as the spec says (§7.5) |

Rules shared by all scalp strategies **[REC]**:
- **Target:** 1.0–1.5× the risk, or a fixed $ target. Both are tested, with no assumption that bigger targets are better.
- **Time stop:** exit if the trade hasn't moved +0.5× risk within N minutes (e.g. 10–15). Scalps that stall usually turn into losers.
- **Break-even move:** tested, not assumed.
- **One open position at a time** in SCALP mode. This keeps margin and risk simple on $20.
- **5-minute cool-down after any loss** (anti-revenge), and pause after 3 losses in a row.

### 4.2 NORMAL mode (from the original spec)

The spec's priority order is kept: trend pullback (primary), breakout + retest
(secondary), VWAP+EMA (research), range (regime-specific), liquidity sweep
(confirmation only). See `SPEC.md` §7–8. Note that on $20, NORMAL mode will skip
most trades because M30 stops are wider than $5. That is expected behaviour, not a bug (§17 of the spec).

### 4.3 Why costs decide everything: a worked example

With a $2 stop, a $2 target and a $0.20 spread on 0.01 lot:
- Effective win ≈ $2.00 − $0.20 = **$1.80**. Effective loss ≈ $2.00 + $0.20 = **$2.20**.
- Break-even win rate = 2.20 / (1.80 + 2.20) = **55%** (it would be 50% with no costs).
- With a $0.40 news-time spread it becomes 60%.

So the backtest must show a win rate clearly above these numbers **after** realistic
spread and slippage, across different months and sessions, before SCALP mode is allowed near real money.

### 4.4 Recommendation

- **Build first:** the risk engine, then S1 (SCALP) and the spec's trend pullback (NORMAL).
- **Build second, if data supports it:** S2 session-open breakout.
- **Postpone:** S3 range reversion, standalone liquidity-sweep entries, ML models.
- **Don't build:** martingale, grid, recovery lot sizing, averaging down,
  "make up the loss" logic. These are forbidden, and they are the usual way small accounts blow up.

---

## 5. Market regimes and the strategy selector

The regime is classified on **closed bars only**, with a minimum time in each state (hysteresis) so the bot doesn't flip constantly.

| Regime | Measured by (initial definition, to be calibrated) | SCALP allowed | NORMAL allowed |
|---|---|---|---|
| `TREND_UP` / `TREND_DOWN` | H1 & M15 EMA50 > EMA200 (or <), EMA slope beyond a threshold, ADX(14) on M15 ≥ 20 | S1 in trend direction, S2 in trend direction | Trend pullback |
| `RANGE` | ADX(14) M15 < 18 and Bollinger width percentile < 30 | None initially (S3 postponed) | Range (if validated) |
| `EXPANSION` | ATR(14) M5 percentile > 80 after a contraction, with a range break | S2 | Breakout + retest |
| `ABNORMAL_VOL` | ATR M1 percentile > 98, or spread > cap | **No trades** | **No trades** |
| `NEWS_WINDOW` | High-impact USD event within the configured window | **No trades** | **No trades** |
| `UNCERTAIN` / `NO_DATA` | Timeframes disagree, warm-up incomplete, stale ticks | **No trades** | **No trades** |

State machine:

```
            ┌──────────── safety checks fail ────────────┐
            ▼                                             │
 [IDLE] ──start──▶ [WARMUP] ──data ok──▶ [READY] ──regime allows──▶ [EVALUATE]
   ▲                                       ▲   │                         │
   │                                       │   └─ news/abnormal ─▶ [STAND_DOWN]
   │                                       │                             │ candidate
   │                                       └──── done/rejected ──── [RISK_CHECK]
   │                                                                     │ pass
   └── daily limit / emergency stop ◀── [LOCKED] ◀── limit hit ── [IN_TRADE]
```

The regime picks which strategies may *look* for trades. It never places a trade
itself. Every candidate passes the same risk manager (§6).

---

## 6. Risk manager specification (MQL5, the final authority)

### 6.1 Virtual balance (the $1,000 demo behaves like $20)

- Setting `VirtualStartBalance = 20.00`.
  Virtual equity = 20 + (account equity now − account equity when the test started).
- All sizing and all percentage limits use **virtual equity**. Dollar limits ($5/day) are absolute.
- If virtual equity drops to ≤ the minimum needed for one trade, the EA declares
  **"virtual account blown"**, stops, and alerts. That is exactly what would happen on a real $20 account.
- On a real account `VirtualStartBalance = 0` (off), and real equity is used.

### 6.2 Position size

```
risk_budget_$   = min( RiskPerTradePct × virtual_equity , MaxRiskPerTrade_$ )
loss_per_lot_$  = (stop_distance / tick_size) × tick_value_loss  + commission_per_lot
                  + expected_slippage_$ per lot
raw_volume      = risk_budget_$ / loss_per_lot_$
volume          = floor(raw_volume / volume_step) × volume_step      ← always round DOWN
if volume < volume_min → SKIP ("min lot exceeds risk budget"), log it, never round up
```

- Cross-checked with `OrderCalcProfit` at the stop price.
- **SCALP default:** `RiskPerTradePct = 12%` of virtual equity, capped at `$2.50`. On
  $20 this allows a stop of up to ~$2.30 at 0.01 lot after costs. **[REC, owner may change]**
  As the account grows, the dollar risk grows with it (fixed-fraction compounding,
  the legitimate growth path). After losses it **shrinks automatically**. Risk never rises because of a loss.
- **NORMAL default:** 5% of virtual equity, which in practice skips most M30 setups on $20.

### 6.3 Daily loss limit ($5)

- **Trading day:** 00:00 to 24:00 **broker server time** (Exness server time; offset
  from UTC read at runtime and logged).
- **Baseline:** equity at the first tick of the trading day, written to a file
  (`GOLD_AI\state_<login>.txt` in the terminal's Common Files folder) together with the date and
  a checksum. On restart the stored baseline is reused if the date matches. Restarting,
  switching charts or reconnecting cannot reset it. A missing or corrupt file means
  **lockout until the next day** (fail safe), not a fresh baseline.
- **Trigger:** `baseline − current equity ≥ $5` (or the % limit if that is stricter).
  Floating losses count, because it uses equity, not balance.
- **On trigger:** block new entries, delete pending orders, **close any open position**
  (scalps are short-lived, so holding a loser past the limit isn't worth it; owner can
  change this), save the lockout, send a push/Telegram alert. Unlock at the next trading day, after start-up checks pass.
- **Deposits/withdrawals:** detected via `HistoryDeals` (`DEAL_TYPE_BALANCE`). The
  baseline is adjusted by the deposit amount so a deposit doesn't hide a loss and a withdrawal doesn't trigger the lock.

### 6.4 Other hard limits (defaults, all configurable, all tested)

| Limit | SCALP | NORMAL |
|---|---|---|
| New entries per day | 15 | 3 |
| Open positions at once | 1 | 2 |
| Losses in a row → pause | 3 → 60 min | 3 → rest of day |
| Cool-down after a loss | 5 min | 30 min |
| Max spread | min($0.35, 15% of stop distance) | min($0.50, 10% of stop) |
| Max slippage (deviation) | $0.10 | $0.20 |
| News blackout (CPI, NFP, FOMC, PCE) | 15 min before → 15 min after | 30 → 30 |
| Daily break / rollover | No new trades 30 min before → 30 min after | same |
| Friday close / Monday open | No new trades last 60 min Fri / first 30 min Mon | same |

### 6.5 Stop-loss rules

- The order is sent **with** its SL and TP. After the fill, the EA re-reads the position
  and checks the SL is present and correct. If it isn't, it retries setting it once
  (bounded). If it still isn't, it **closes the position**, blocks new trades, and alerts.
- A stop may only move toward profit, per a tested rule. It is never widened.
- Every 5 seconds a watchdog checks every GOLD AI position for a valid stop.

---

## 7. Architecture

```
 ┌───────────────────────── Windows PC / Windows VPS ─────────────────────────┐
 │                                                                            │
 │  MT5 terminal (Exness)                                                     │
 │  ┌──────────────────────────────┐    files in Common\Files\GOLD_AI\       │
 │  │ GOLD_AI.mq5  (trading EA)    │◀── commands.json (validated, signed) ─┐ │
 │  │  risk · strategies · orders  │─── status.json / events.jsonl ──────┐ │ │
 │  │  FINAL AUTHORITY             │─── SendNotification ──▶ MT5 phone app│ │ │
 │  └──────────────────────────────┘                                     │ │ │
 │  ┌──────────────────────────────┐                                     │ │ │
 │  │ GOLD_AI_Remote.mq5 (2nd EA)  │◀─────────── reads status ───────────┘ │ │
 │  │  Telegram I/O via WebRequest │──────────── writes commands ──────────┘ │
 │  │  never trades                │◀──▶ api.telegram.org ◀──▶ your phone    │
 │  └──────────────────────────────┘                                         │
 │                                                                            │
 │  Python service (optional, later phases)                                   │
 │   research · backtest reports · Claude API briefings/reports ──▶ Telegram  │
 └────────────────────────────────────────────────────────────────────────────┘
```

**Why a second EA for Telegram [REC]:** `WebRequest` blocks the thread that calls it. If
the trading EA called Telegram itself, a slow network could freeze it mid-scalp. Each
EA runs on its own chart and thread, so the trading EA never waits on the network.
They talk through small files, and the trading EA validates every command.

**Python and Claude are not required for trading.** If they are off, the EA trades and protects the account on its own.

### 7.1 Versioned data contracts

`commands.json`, written by the Remote EA and read by the trading EA:
```json
{ "schema": "cmd/1", "id": "uuid", "issued_utc": "2026-11-09T10:15:00Z",
  "from": "telegram:<chat_id>", "cmd": "PAUSE" }
```
Allowed `cmd` values: `STATUS`, `PAUSE`, `RESUME`, `MODE_NORMAL`, `MODE_SCALP`, `EMERGENCY_STOP`.
The trading EA rejects unknown commands, commands older than 60 seconds,
and repeated IDs. `RESUME` and `MODE_SCALP` only count when a second confirmation
code arrives within 60 seconds.

`status.json`, written by the trading EA every 5 seconds: mode, virtual equity, today's
P&L vs the $5 limit, entries used, lock state, open position and its verified SL, regime, spread, ping, last tick time, config version.

`events.jsonl`: one line per event (signal, accepted, rejected + reason, filled, SL verified, closed, lockout, error). This is the trade journal the spec requires.

Claude advisory schema: as `SPEC.md` §25, with `"mode": "SCALP|NORMAL"` added. It is used only for
**pre-session briefings** (e.g. "CPI at 13:30 UTC, high event risk until 14:00") and reports, never per trade.

---

## 8. Your phone

| Need | How |
|---|---|
| See trades live | **MT5 app** (iOS/Android), logged into the same account. Note: the mobile app **cannot run EAs** **[FACT: MQL5 / broker docs]**, so it's the window, not the engine. |
| Instant alerts | MT5 push notifications (`SendNotification`) to your MetaQuotes ID. Limits: ≤255 chars, ≤2/s and ≤10/min **[FACT: MQL5 docs]**, so the EA queues and merges messages. |
| Richer alerts + daily report | Telegram bot |
| Control | Telegram commands: `/status` `/pause` `/stop` `/normal` (instant), `/scalp` `/resume` (need confirmation). Only your Telegram chat ID is accepted. |
| Full access | Remote Desktop app → the VPS |

**What the phone can never do:** raise the $5 limit, raise risk %, remove stops, switch demo → live.
Those need a config change on the VPS itself, which is logged.

### Where it runs

| Option | Cost | Notes |
|---|---|---|
| Your own Windows PC | $0 | Fine for the demo phase, but the bot stops when the PC sleeps or loses internet |
| MQL5 built-in VPS | ~$10–15/mo **[FACT: mql5.com]** | One click from MT5. **Cannot run Python**, so no Claude layer there. The EAs and Telegram via WebRequest should work (to verify) |
| Regular Windows VPS | ~$10–30/mo | Runs everything, including Python and Claude |
| Exness free VPS | $0 if eligible | Eligibility is reported as ~$500+ deposit / balance conditions **[3P]**. A $20 account almost certainly won't qualify. Check your Personal Area. |

---

## 9. Claude / Anthropic API plan

- **Use:** pre-session briefing (2–4 calls/day), end-of-day report, weekly review, research help.
  **Not** per trade: API latency (seconds) is incompatible with M1 scalping.
- **Model:** a small, fast Claude model for briefings and a larger one for weekly reviews. Verify
  the current model IDs and pricing from Anthropic's docs at implementation time (§20 of the spec).
- **Secrets:** `ANTHROPIC_API_KEY` as a Windows environment variable on the VPS only. Never in
  the repo, MQL5 code, logs or Telegram.
- **Cost control:** a hard monthly spend limit in the Anthropic console, plus an app-side daily call cap
  (e.g. 10 calls). Responses cached per session.
- **Reliability:** 20-second timeout, 2 retries with backoff, and a circuit breaker after 3 failures.
  A missing or invalid response is **never** read as approval. The deterministic EA keeps working.
- **Output:** strict JSON schema validation (Pydantic). Anything invalid is discarded and logged.

---

## 10. Backtesting and validation plan

| Step | Detail |
|---|---|
| Data | Exness XAUUSD **real tick** history via the MT5 terminal (`CopyTicksRange` / MetaTrader5 Python package, Windows). M1 OHLC is **not enough** for scalps, because it can't show whether the stop or target was hit first. |
| Tester mode | MT5 Strategy Tester, **"Every tick based on real ticks"** |
| Split | 2024-01 → 2025-06 develop · 2025-07 → 2026-03 validate · 2026-04 → present **untouched final test** |
| Walk-forward | Rolling 6-month optimise / 2-month test |
| Cost stress | Spread ×1.5 and ×2. Slippage $0.05 and $0.10 per trade. Must stay profitable at ×1.5. |
| Sensitivity | ±20% on every parameter. Reject strategies where results only work at one exact setting. |
| News | Calendar functions don't return history inside the Strategy Tester **[3P: MQL5 forum/book]**, so we export the calendar to a CSV the EA loads in tester mode |
| **Ruin test** | Monte Carlo on trade sequences: **probability a $20 account is blown** within 1/4/12 weeks under the $5/day rule. This is the key number for your decision. |
| Metrics | Everything in spec §32, plus trades/day, time in trade, cost as a share of gross profit, P(ruin). |

**Promotion gates [REC]:**
- **To demo forward test:** at least 300 out-of-sample trades, profit factor ≥ 1.2 after ×1.5 costs, and P(ruin in 4 weeks) < 25%.
- **To real money ($20):** at least 4 weeks and 150+ trades on demo, results within the backtest's expected range, zero missed-stop incidents, and your explicit written go-ahead.

---

## 11. Repository layout and milestones

```
gold/
├── docs/            SPEC.md · AMENDMENTS.md · PLAN.md · runbooks
├── mql5/
│   ├── Experts/GOLD_AI/        GOLD_AI.mq5, GOLD_AI_Remote.mq5
│   └── Include/GOLD_AI/        Config, SymbolGuard, AccountGuard, State, RiskManager,
│                               Sizing, Execution, StopWatchdog, Regime, Strat_S1, Strat_S2,
│                               Strat_TrendPullback, NewsFilter, Journal, Notify, Commands
├── mql5/Scripts/GOLD_AI_Tests/ test scripts (RiskManager, Sizing, State, Commands)
├── python/          research/, backtest_reports/, briefing/ (Claude), tests/
├── config/          scalp.set, normal.set, demo-virtual20.set (versioned)
└── reports/         backtest + evidence pack outputs
```

| # | Milestone | Deliverable | Proof of done |
|---|---|---|---|
| M0 | This plan | `PLAN.md` approved | Your approval |
| M1 | Risk-first EA skeleton | Symbol/account guards, state file, $5 lock, sizing, SL verification, journal, push alerts. **No strategy, trades nothing.** | MQL5 unit-test scripts pass. Restart test shows the lock persists. You compile it in MetaEditor (I can't here). |
| M2 | Data study | Exness tick export, session/spread/volatility report | Report in `reports/` |
| M3 | S1 scalp + regime | Strategy S1 + regime detector, SCALP mode | Backtest per §10 |
| M4 | NORMAL mode | Spec's trend pullback, mode switch | Backtest per §10 |
| M5 | Phone control | Remote EA + Telegram commands | Command tests, incl. rejected/stale/duplicate |
| M6 | Demo forward test | $1,000 demo with $20 virtual balance, 4+ weeks | Weekly reports, evidence pack |
| M7 | S2, Claude briefings | Only if M3–M6 justify them | Same gates |
| M8 | Readiness review | Evidence pack (spec §42) | Your decision on $20 live |

**Important:** I can write and unit-test the Python here. MQL5 must be **compiled and run on your
Windows machine** (MetaEditor + MT5 Strategy Tester). Each milestone gives you exact steps, and you
send me back the compile log and test output.

---

## 12. Threat model and failure modes

| Failure | Detection | Response |
|---|---|---|
| Stop missing after fill | Post-fill check + 5 s watchdog | Retry once → close position → block + alert |
| EA/terminal restart mid-trade | `OnInit` reconciles positions (by magic number) with the state file | Adopt known positions, verify stops. Unknown position on XAUUSD → alert, don't trade |
| Duplicate order | Signal ID + bar time stored. Only one in-flight order at a time | Second signal ignored |
| Stale data | Last tick age > 10 s (SCALP) / 60 s (NORMAL) | No new trades |
| Disconnection | `TERMINAL_CONNECTED`, ping | No new trades. Existing stops are broker-side, so they still protect |
| Spread spike / news | Spread cap, calendar | No new trades |
| Wrong symbol or account | Guards at start and every minute | Block, alert |
| State file deleted/corrupt | Checksum, date | Lock for the day (fail safe) |
| Telegram account hijacked | Chat-ID allow-list, risk-raising commands need confirmation, no limit changes possible | Worst case: someone pauses your bot |
| Claude returns bad output | Schema validation | Ignored. EA unaffected |
| Fat-finger config | Config version hash in every log line and status. Limits have hard maximums compiled into the EA (e.g. risk ≤ 20%, daily limit ≤ 50% of equity) | Out-of-range config → EA refuses to start |

---

## 13. Assumptions, unknowns, and decisions needed from you

**Decisions:**
1. **Max SCALP trades/day:** 15 OK?
2. **Risk per scalp:** 12% of (virtual) equity, capped at $2.50. OK? (On $20 this is effectively "always 0.01 lot".)
3. **At the $5 limit:** close the open trade immediately (my default), or let its own stop/target finish it?
4. **Where it runs:** do you have a Windows PC for the demo phase? (Mac users can run MT5, but the Strategy Tester and VPS route are simplest on Windows.)
5. **Telegram:** OK to use it for control? You'd create a bot with @BotFather (2 minutes; I'll give steps).
6. **Exness account type:** please confirm the exact symbol name shown in your MT5 Market Watch (e.g. `XAUUSD` or `XAUUSDm`).

**Unknowns to measure in M2:** actual Exness spreads by hour, the daily break times, typical M1/M5 ATR, slippage on demo.

---

## 14. My recommendation

1. **Build first:** M1, the risk engine with no strategy. It's the part that keeps a $20 account alive, and everything else plugs into it.
2. **Then:** M2 data study + S1 scalp backtest. This answers the only question that matters: *does a scalp edge survive Exness costs?*
3. **Postpone:** Claude integration, dashboard, ML, S3.
4. **Don't build:** anything that raises size after losses, or anything that lets the phone or Claude override limits.

If the S1 backtest fails the gates, I'll tell you plainly, and we'll either revise it or rely on NORMAL mode, rather than run a losing scalper with real money.

---

### Sources

- MQL5 `SendNotification` limits: <https://www.mql5.com/en/docs/common/SendNotification>, <https://docs.mql4.com/common/SendNotification>
- MT5 mobile can't run EAs: <https://www.mql5.com/en/blogs/post/777309>, <https://help.axi.com/en-GB/axiv2--axicorp-prod/article/2h1Bj94Q-can-i-use-indicators-and-expert-advisors-on-the-android-mt5-app>
- MQL5 VPS pricing and limits: <https://www.mql5.com/en/vps/free-forex-vps>, <https://MQL5.com/en/vps/forex-plans>
- Calendar in Strategy Tester: <https://www.mql5.com/en/articles/22231>, <https://www.mql5.com/ja/book/advanced/calendar/calendar_cache_tester>
- Exness XAUUSD conditions (third-party, verify): <https://www.brokerxplorer.com/amp/article/exness-metals-trading-conditions-what-traders-need-to-know-3377>, <https://tradersunion.com/brokers/forex/view/exness/xauusd-spread/>
- Exness free VPS (third-party, verify): <https://tradingbeasts.com/exness-vps/>
- Gold price context: <https://tradingeconomics.com/commodity/gold>, <https://www.fxstreet.com/analysis/gold-weekly-forecast-post-midterm-elections-relief-rally-loses-momentum-202611061544>
- Intraday gold patterns: Batten, Lucey, McGroarty, Peat, Urquhart (2017) <https://reading-clone.eprints-hosting.org/79175/1/BattenLuceyMcGroartyPeatUrquhart2017.pdf>; Iwatsubo, Watkins, Xu (2018) <https://www.econ.kobe-u.ac.jp/wp/wp-content/uploads/2023/06/1715.pdf>
