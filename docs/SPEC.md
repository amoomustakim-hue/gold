**GOLD AI**

*Master Research, Architecture, Strategy & Development Prompt*

**A strict specification for building an automated XAUUSD trading system
on Exness MT5**

This document is the authoritative project brief to give to Claude. It
combines the trading objectives, strategy research requirements,
adaptive strategy design, Anthropic API integration, MQL5 execution
architecture, risk controls, testing standards, deployment rules, and
development process agreed for GOLD AI.

Important: This is a research and engineering specification, not a
promise of profitability. Automated trading can lose some or all of the
capital allocated to it. The system must be developed and validated on
demo before any consideration of live trading.

# PART I — MASTER INSTRUCTIONS TO CLAUDE

## 1. Your role and mandate

Act as a senior quantitative researcher, systematic gold-trading
strategist, MQL5/MetaTrader 5 engineer, Python engineer, financial risk
engineer, test engineer, and software architect. Your job is to
research, design, implement, test, document, and help validate GOLD AI.
Treat it as a serious engineering product, not a quick indicator script
or a promise of easy profits.

Do not begin by generating the entire codebase. First complete the
research, evidence review, architecture, risk specification, testing
plan, and milestone plan. Present the results and wait for explicit
approval before implementation.

## 2. Absolute project facts

| **Item**                      | **Required specification**                                            |
|-------------------------------|-----------------------------------------------------------------------|
| Product                       | GOLD AI                                                               |
| Broker/platform               | Exness / MetaTrader 5                                                 |
| Only permitted instrument     | XAUUSD only                                                           |
| Initial account               | \$20 Exness Standard Demo                                             |
| Execution                     | Fully automated once explicitly enabled in the selected mode          |
| Primary decision timeframe    | M30                                                                   |
| Context timeframes            | H4 and H1                                                             |
| Entry refinement              | M15; M5 optional and never mandatory                                  |
| Target frequency              | Usually 1–3 entries/day, with a hard maximum of 3 new entries/day     |
| Session coverage              | All sessions may be considered, subject to filters                    |
| Daily equity drawdown lockout | 10% hard limit, with persistent baseline and restart-safe enforcement |
| AI provider                   | Anthropic Claude API, optional advisory/research layer                |
| Initial custom model training | Not required; do not train a custom model in the first version        |

## 3. Strict non-negotiable rules

- Trade XAUUSD only. Never trade XAUUSM, another gold symbol, another
  forex pair, an index, a cryptocurrency, or any other instrument.
  Validate the broker's exact symbol name and any configured
  suffix/prefix explicitly. If validation is uncertain, refuse to trade.

- No martingale, grid recovery, averaging down, doubling after losses,
  revenge trading, uncontrolled hedging, unlimited lot escalation, or
  increasing risk to recover losses.

- Every open position must have a valid, verified protective stop-loss.
  If protection cannot be established or verified, safely close the
  exposure where possible, block new entries, log the incident, and
  alert the operator.

- Never widen a stop-loss to increase the original risk. Stop
  adjustments may only reduce risk or follow a tested
  position-management rule.

- The MQL5 Expert Advisor is the final authority for execution and hard
  risk enforcement. Claude, Python, the dashboard, Telegram, and
  external services must never bypass or override it.

- If minimum broker volume would exceed the allowed cash risk, skip the
  trade. Never round volume upward just to place an order.

- Never force trades to meet a daily target. Zero trades is a valid
  outcome.

- Never claim profitability, a guaranteed return, or a verified win
  probability without valid evidence.

- Never use the aspiration of turning \$10–\$20 into \$500+ in seven
  days as a sizing target or justification for excessive risk. It is an
  extremely speculative aspiration, not a forecast or dependable
  objective.

- Never switch to live trading automatically. Live mode requires
  explicit human approval and a separate deliberate configuration
  change.

- If data, execution state, risk state, symbol identity, or
  protective-stop state is uncertain, fail safely and do not open new
  positions.

- Do not silently change approved specifications. Identify conflicts and
  request approval before changing them.

## 4. How to work and communicate

- Research before coding. Distinguish established platform facts,
  empirical findings, hypotheses, and your own engineering
  recommendations.

- Cite primary documentation and credible research for technical and
  empirical claims. State the date, data period, instrument, broker
  assumptions, costs, sample size, and limitations of each study where
  available.

- Do not fabricate citations, test results, market data, broker
  specifications, API capabilities, or performance metrics.

- When current information matters, verify it from current official
  documentation rather than relying on memory.

- Explain important decisions and trade-offs in plain language, then
  provide technical detail.

- Keep modules small, testable, documented, version-controlled, and
  independently verifiable.

- Do not mark a feature complete merely because code was generated or
  compiled. Provide test evidence.

- If you cannot access historical data, MT5, Exness, or an API in your
  environment, say so and provide reproducible steps rather than
  pretending to have tested it.

# PART II — TRADING OBJECTIVE AND MARKET RESEARCH

## 5. Trading objective and realistic expectations

Build a disciplined, research-driven XAUUSD system that seeks positive
expectancy after realistic costs while controlling drawdown. The \$20
Standard Demo is an initial engineering and execution environment, not
proof that a small live account can safely support the desired
strategies. Minimum lot size, tick value, contract size, margin, spread,
commission, stop distance, and slippage can make some setups impossible
to take within a conservative risk budget.

The aspiration of growing a \$10–\$20 account to \$500+ in seven days
must be treated as highly speculative and not as a design requirement.
Do not optimise for that outcome. Do not use dangerous leverage or risk
escalation to chase it.

## 6. Research XAUUSD before choosing a strategy

Produce a properly sourced research report covering gold market
behaviour and the practical realities of trading XAUUSD through Exness
MT5. Investigate:

- Gold's volatility characteristics, intraday behaviour, trend
  persistence, mean reversion, gaps, and event-driven moves.

- How Asian, London, New York, and London–New York overlap periods
  differ. Account for daylight-saving changes and broker-server time.

- The influence of US dollar strength, Treasury yields, real yields,
  inflation releases, employment data, central-bank policy, and
  geopolitical shocks. Explain limitations of any proxy data.

- Spread, commission, swaps, execution, slippage, stop-level,
  freeze-level, volume minimum/step/maximum, tick size, tick value,
  contract size, and margin requirements applicable to the actual Exness
  XAUUSD symbol.

- How demo fills may differ from live execution and how historical data
  quality can distort results.

- The risks of low-liquidity periods, rollover, market closures, sudden
  spread expansion, and abnormal volatility.

Use official Exness and MetaTrader documentation for broker/platform
mechanics. Do not assume symbol specifications or account conditions;
read them from MT5 at runtime and verify the current Exness contract
specifications.

## 7. Candidate strategy families to research

Research each strategy independently before combining them. Do not
assume any candidate is profitable. Use XAUUSD-specific evidence where
possible and test on data that reflects the intended broker, timeframe,
and trading costs.

### 7.1 Trend following with pullback — primary candidate

- Potential inputs: EMA 200, EMA 50, EMA 20, ADX, ATR, RSI, swing
  highs/lows, market structure, support/resistance, and candlestick
  confirmation.

- For longs, establish higher-timeframe bullish context, confirm M30
  trend, wait for a pullback into a meaningful dynamic or structural
  area, confirm that the trend remains valid, and require M15
  continuation evidence.

- For shorts, apply the inverse logic.

- Do not enter merely because price touches an EMA. Avoid excessive
  indicator stacking and correlated confirmations.

- Test trend filters, pullback depth, entry confirmation, stop
  placement, exit logic, and market-regime restrictions independently.

### 7.2 Breakout and retest — secondary candidate

- Identify meaningful consolidation zones and levels such as Asian
  session high/low, previous day high/low, previous close, and
  significant swing levels.

- Require a meaningful close or otherwise precisely defined break,
  evaluate candle strength and volatility expansion, and distinguish
  acceptance beyond a level from a brief wick.

- Where appropriate, wait for a retest and confirmation rather than
  chasing an extended candle.

- Test false-breakout filters, retest tolerance, volume/tick-volume
  limitations, ATR expansion, time-of-day filters, and stop placement.

- Test both bullish and bearish setups.

### 7.3 VWAP plus EMA trend confirmation — research candidate

- Investigate session VWAP, EMA 200, EMA 50, ATR, RSI, and market
  structure.

- Define the VWAP calculation and reset convention precisely. Determine
  whether tick volume is an acceptable proxy in the available XAUUSD
  feed.

- Test whether VWAP pullbacks add incremental value beyond a simpler
  trend-pullback system.

- Do not claim that VWAP/EMA is proven without independent,
  out-of-sample validation.

### 7.4 Range trading / mean reversion — regime-specific candidate

- Only activate in objectively identified consolidation conditions.

- Potential inputs: ADX, Bollinger Band width, ATR contraction, RSI,
  range boundaries, support/resistance, and rejection candles.

- Avoid entries in the middle of a range. Test entries near boundaries
  and exits before the opposite boundary where appropriate.

- Disable range logic during volatility expansion, confirmed breakout,
  major news risk, or unclear structure.

### 7.5 Liquidity sweep plus structure shift — contextual candidate

- Research previous day high/low, equal highs/lows, session highs/lows,
  swing points, sweeps, displacement, break of structure, and change of
  character.

- A sweep alone must never trigger a trade. Require objectively defined
  reversal/continuation confirmation and an invalidation point.

- Treat as a confirmation layer unless robust testing supports a
  standalone implementation.

- Avoid subjective discretionary definitions that cannot be coded and
  tested consistently.

## 8. Strategy comparison and initial priority

| **Candidate**               | **Initial role**                | **Required evidence**                                                  |
|-----------------------------|---------------------------------|------------------------------------------------------------------------|
| Trend pullback              | Primary candidate               | Positive out-of-sample expectancy after costs across multiple regimes  |
| Breakout + retest           | Secondary candidate             | Robust false-breakout control and cost-adjusted results                |
| VWAP + EMA                  | Research/confirmation candidate | Incremental benefit over simpler trend logic                           |
| Range trading               | Regime-specific alternative     | Works in objectively classified ranges and exits when expansion begins |
| Liquidity sweep + structure | Context/confirmation candidate  | Repeatable definitions and independently validated edge                |

These are starting priorities, not a declaration that any strategy is
profitable. If the evidence contradicts the priority, report it and
recommend the simpler or safer alternative.

# PART III — ADAPTIVE MARKET INTELLIGENCE

## 9. Market-regime detection

Build an explicit market-regime classifier. Candidate states include
strong bullish trend, strong bearish trend, weak directional trend,
sideways consolidation, volatility contraction, breakout expansion,
abnormal/high volatility, conflicting/uncertain conditions, and
insufficient data.

Potential features include ADX, ATR and ATR percentile, EMA slope and
alignment, price relative to moving averages, swing structure, Bollinger
Band width, rate of change, candle range, VWAP positioning, and
higher-timeframe alignment. Define feature windows, thresholds, warm-up
requirements, missing-data handling, and update frequency.

Do not let one indicator determine the regime. Use measurable
definitions, avoid look-ahead, and evaluate classifier stability. Use
hysteresis or minimum state duration to avoid rapid strategy switching
around thresholds.

## 10. Regime-to-strategy policy

| **Detected condition**                | **Preferred behaviour**                                                 |
|---------------------------------------|-------------------------------------------------------------------------|
| Strong bullish trend                  | Evaluate bullish trend-pullback setups                                  |
| Strong bearish trend                  | Evaluate bearish trend-pullback setups                                  |
| Clear range                           | Evaluate range trades near validated boundaries                         |
| Confirmed bullish/bearish breakout    | Evaluate breakout-and-retest in breakout direction                      |
| Liquidity sweep                       | Wait for defined structure confirmation; no automatic entry             |
| Conflicting timeframes                | Reduce eligibility or no trade                                          |
| Abnormal volatility                   | No new trade unless a separately validated policy explicitly permits it |
| Poor spread/liquidity                 | No trade                                                                |
| Major scheduled event risk            | Apply configured news restrictions                                      |
| Uncertain regime or insufficient data | No trade                                                                |

The regime engine selects which strategy may be evaluated; it does not
create a trade by itself. Each strategy must produce a standardised
candidate signal. The central risk manager makes the final eligibility
decision.

## 11. Multi-timeframe responsibilities

| **Timeframe** | **Responsibility**                                                   |
|---------------|----------------------------------------------------------------------|
| H4            | Broader direction, major structure, important swing points and zones |
| H1            | Intermediate trend confirmation and structure                        |
| M30           | Primary regime detection, strategy selection and setup decision      |
| M15           | Entry confirmation and local structure                               |
| M5            | Optional execution refinement only                                   |

Use closed-candle confirmation where needed. Explicitly prevent
repainting, future-bar access, and accidental use of incomplete candles
in backtests. Lower-timeframe signals must not casually override
higher-timeframe context.

# PART IV — NEWS, SESSIONS AND EXECUTION CONDITIONS

## 12. Economic-calendar protection

Investigate a reliable economic calendar source and its licensing,
availability, latency, timezone, event-impact labels, and failure modes.
Prioritise US CPI/core CPI, NFP, FOMC rate decisions and statements, Fed
press conferences, PCE inflation, unemployment data, and other major
scheduled US releases.

Make pre-event and post-event restrictions configurable and empirically
evaluated. Do not invent a live calendar feed. If the calendar is
unavailable or stale, follow a documented fail-safe policy. News logic
must never override stop-losses or risk limits.

## 13. Trading sessions

The system may evaluate all sessions, but only trade when its strategy
and execution filters permit. Configure session times using a reliable
timezone approach, handle daylight-saving transitions, and distinguish
broker-server time from UTC and local time. Analyse performance by
session and strategy. Do not force trading at session open.

## 14. Execution quality filters

- Spread ceiling, with optional dynamic spread-to-ATR or
  spread-to-stop-distance checks.

- Maximum permitted slippage/deviation and handling of rejected or
  requoted orders.

- Stale tick detection and market-data freshness checks.

- Margin and free-margin checks based on live account/symbol properties.

- Broker stop-level and freeze-level validation.

- Rollover, market-closed, and abnormal-liquidity restrictions.

- Duplicate-order and duplicate-signal protection.

- Post-order verification of actual fill, volume, SL, and TP.

# PART V — RISK MANAGEMENT: HARD SAFETY CONTRACT

## 15. Risk manager authority

Implement the hard risk manager inside the MQL5 EA. It must operate
locally and independently of Claude, Python, the network, Telegram, or a
dashboard. No external service can grant permission to exceed its
limits. All trade candidates pass through the same risk manager.

## 16. Daily equity drawdown

Hard daily equity drawdown lockout: 10%. Define the baseline precisely
and persist it across terminal/EA restarts. The baseline must not be
reset by restarting the EA, changing charts, reconnecting, or modifying
a file. Specify the trading-day boundary and timezone. Define how
deposits, withdrawals, balance adjustments, and account changes are
handled. Use equity, not just closed balance, for the stated equity
drawdown control.

When the threshold is reached: block new entries, cancel eligible
pending orders, apply the configured open-position policy, persist the
lockout, record the trigger, and notify the operator. The open-position
policy must be explicit and tested; do not assume that closing all open
positions is always the correct response without documenting it. Resume
only after the next defined trading day and successful safety checks.

## 17. Position sizing and small-account constraints

Calculate volume from the permitted monetary risk and the actual stop
distance using the broker's live symbol properties. Account for tick
size, tick value, contract size, account currency, volume
minimum/maximum/step, margin, commission, spread, and expected slippage.
Validate the calculation against MT5's own profit/margin calculation
facilities where appropriate.

Do not assume a fixed pip value or generic gold contract. Do not round
volume up. If minimum volume breaches the configured risk budget, skip
the setup and log the reason. A \$20 demo account may be too small to
take many structurally valid trades under conservative limits; this is
an expected constraint, not a reason to loosen the controls.

## 18. Stops, targets and position management

- Every position must have a broker-side protective stop-loss verified
  after execution.

- Place stops at a technically meaningful invalidation point using
  structure and/or ATR, then check that the resulting monetary risk fits
  the budget.

- Research fixed R-multiple targets, structure-based targets, ATR-based
  exits, partial exits, break-even rules, and trailing stops
  independently.

- Do not assume 1:3 is automatically better than 1:2 or 1:1.5. Compare
  expectancy, drawdown, and costs.

- Never widen the original stop to increase risk. A tested trailing stop
  may move only according to documented rules.

- Account for minimum volume when partial closing. Do not issue invalid
  partial-close requests.

- Define how positions are handled at news, session boundaries,
  rollover, disconnection, and daily lockout.

## 19. Additional hard controls

- Maximum three new entries per configured trading day.

- Maximum simultaneous positions and aggregate open risk.

- Maximum consecutive losses and optional cooling-off period.

- Spread, slippage, margin, stale-data, and abnormal-volatility guards.

- Daily lockout and manual emergency stop.

- No new entries if broker state cannot be reconciled with internal
  state.

- No new entries if any position is missing verified protection.

- No risk increase after a loss or after a losing streak.

All thresholds must have safe defaults, be documented, and be covered by
automated tests. Configuration changes must be logged and versioned.

# PART VI — ANTHROPIC CLAUDE API INTEGRATION

## 20. No custom model training is required initially

Use an existing Claude model through the Anthropic API. Do not train a
custom foundation model for the initial release. API access is separate
from a Claude consumer subscription and is billed according to the
current Anthropic API pricing and usage terms. Verify current model
names, API endpoints, structured-output support, rate limits, and
pricing from official Anthropic documentation before implementation.

A future machine-learning component may be evaluated after a sufficient,
clean, labelled dataset exists. Any trained model must demonstrate
out-of-sample value over simpler deterministic rules. Do not add machine
learning merely for novelty.

## 21. Claude's permitted responsibilities

- Interpret structured market summaries prepared by Python.

- Provide a secondary assessment of regime classification and
  conflicting evidence.

- Review candidate setups against a fixed, documented rubric.

- Summarise trading history and identify possible weaknesses.

- Generate daily/weekly performance reports.

- Assist research and propose testable strategy hypotheses.

- Explain why a setup may be unsuitable or why no trade may be
  preferable.

## 22. Claude's prohibited responsibilities

- Claude must not directly send orders to MT5 or hold broker
  credentials.

- Claude must not set or increase lot size outside the MQL5 risk
  manager's calculation.

- Claude must not disable, alter, or override daily drawdown limits,
  trade limits, stop-loss requirements, or symbol restrictions.

- Claude must not remove or widen a protective stop to increase risk.

- Claude must not autonomously modify live strategy code, production
  configuration, or model parameters.

- Claude must not issue free-form instructions that the execution engine
  interprets as executable commands.

- Claude must not be a single point of failure for account protection.

## 23. Recommended API flow

> MT5 / MQL5  
> -\> supplies market data and candidate signals to local Python
> service  
> Python analysis  
> -\> calculates deterministic features, regime, strategy candidates and
> risk estimates  
> Claude API (optional advisory call)  
> -\> receives a compact, structured, timestamped market snapshot  
> -\> returns a schema-validated advisory assessment  
> Python validation  
> -\> validates JSON schema, timestamp, symbol, freshness and allowed
> enum values  
> MQL5 EA  
> -\> independently rechecks all rules and calculates final
> risk/volume  
> -\> approves or rejects candidate  
> MT5  
> -\> executes only if every local safety check passes

## 24. API key and service security

- Read the secret from an environment variable such as
  ANTHROPIC_API_KEY. Never hardcode it.

- Never expose the key in browser code, Next.js client bundles, mobile
  apps, source control, screenshots, logs, prompts, or user-visible
  error messages.

- Use a server-side Python service. Restrict file permissions and
  deployment secret access.

- Use separate development and production keys where appropriate;
  rotate/revoke exposed keys.

- Set provider-side and application-side spending limits/alerts where
  available.

- Log model identifier, request timestamp, token usage/cost metadata if
  available, latency, status, and schema-validation result, but never
  log the secret.

- Use request timeouts, bounded retries with backoff, rate-limit
  handling, and circuit breakers.

- Cache or deduplicate repeated analysis requests where safe. Do not
  call Claude every tick or every second.

- Send only necessary market data. Do not send broker passwords, account
  credentials, personal information, or unnecessary sensitive data.

- Validate all model output as untrusted input. Never execute code or
  commands returned by Claude.

## 25. Structured output contract

Require Claude to return JSON conforming to a strict schema. Reject
malformed, incomplete, stale, unexpected, or out-of-range values. Use
enumerated values rather than free-form commands. A suggested advisory
schema is:

> {  
> "schema_version": "1.0",  
> "symbol": "XAUUSD",  
> "as_of_utc": "ISO-8601 timestamp",  
> "data_freshness": "FRESH \| STALE \| UNKNOWN",  
> "regime_assessment": "BULL_TREND \| BEAR_TREND \| RANGE \| BREAKOUT \|
> HIGH_VOLATILITY \| UNCERTAIN",  
> "directional_context": "BULLISH \| BEARISH \| NEUTRAL \|
> CONFLICTING",  
> "strategy_assessment": "TREND_PULLBACK \| BREAKOUT_RETEST \| VWAP_EMA
> \| RANGE \| LIQUIDITY_CONTEXT \| NONE",  
> "setup_assessment": "VALIDATE_LOCALLY \| NO_TRADE \|
> INSUFFICIENT_INFORMATION",  
> "supporting_evidence": \["..."\],  
> "conflicting_evidence": \["..."\],  
> "risk_warnings": \["..."\],  
> "reasons_to_avoid": \["..."\],  
> "summary": "Short explanation"  
> }

This output is advisory only. It contains no executable order, lot size,
stop-loss override, take-profit override, or permission to bypass MQL5
checks. MQL5 independently validates all conditions.

## 26. API failure behaviour

If Anthropic is unavailable, times out, rate-limits, returns malformed
output, or returns stale information, do not treat the missing response
as approval. The EA's deterministic local rules and hard risk controls
continue operating. Configure whether deterministic strategy mode may
continue without Claude; default to a conservative policy and make the
mode visible. Never leave open positions unprotected because the API is
offline.

# PART VII — TECHNOLOGY AND SYSTEM ARCHITECTURE

## 27. Recommended stack

| **Component**      | **Technology**                                       | **Responsibility**                                                                             |
|--------------------|------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Trading execution  | MQL5 Expert Advisor in MT5                           | Final signal validation, hard risk, orders, protective stops, position management and recovery |
| Research/analytics | Python 3.12+ (or current compatible stable release)  | Historical analysis, feature engineering, reporting, model experiments                         |
| AI advisory        | Anthropic Claude API                                 | Optional structured analysis and reporting; never execution authority                          |
| Data analysis      | NumPy, pandas, SciPy, scikit-learn                   | Statistical analysis and research                                                              |
| Optional ML        | PyTorch only if justified                            | Later experimental model development                                                           |
| API service        | FastAPI + Pydantic, if needed                        | Local service boundary and strict data contracts                                               |
| Initial storage    | SQLite and/or CSV                                    | Trades, signals, events, configurations and test outputs                                       |
| Later storage      | PostgreSQL if justified                              | Centralised durable records                                                                    |
| Notifications      | Telegram Bot API                                     | Alerts and reports; notification-only initially                                                |
| Future dashboard   | Next.js + TypeScript + Tailwind + Lightweight Charts | Read-only monitoring and analytics                                                             |
| Continuous runtime | Windows VPS                                          | MT5 terminal and EA uptime, with recovery controls                                             |

## 28. Architecture principles

- MQL5 is the only live execution authority.

- Python and Claude are advisory/research components and may be offline
  without disabling hard safety controls.

- The EA must have local access to the data and logic required for stop
  management and account protection.

- Define explicit, versioned interfaces between MQL5 and Python.
  Validate every message, timestamp, symbol and field.

- Avoid unnecessary microservices, message brokers, cloud
  infrastructure, or database complexity in the first release.

- The first dashboard is read-only. Any future control interface
  requires authentication, authorisation, audit logging, and explicit
  safety design.

## 29. Suggested repository layout

> GOLD-AI/  
> ├── MQL5/  
> │ └── Experts/  
> │ └── GOLD_AI/  
> │ ├── GOLD_AI.mq5  
> │ ├── Config.mqh  
> │ ├── SymbolValidator.mqh  
> │ ├── MarketData.mqh  
> │ ├── IndicatorEngine.mqh  
> │ ├── MarketStructure.mqh  
> │ ├── RegimeDetector.mqh  
> │ ├── StrategyManager.mqh  
> │ ├── TrendPullback.mqh  
> │ ├── BreakoutRetest.mqh  
> │ ├── VWAPTrend.mqh  
> │ ├── RangeTrading.mqh  
> │ ├── LiquidityAnalysis.mqh  
> │ ├── TradeScoring.mqh  
> │ ├── RiskManager.mqh  
> │ ├── ExecutionEngine.mqh  
> │ ├── PositionManager.mqh  
> │ ├── NewsFilter.mqh  
> │ ├── TradeJournal.mqh  
> │ ├── Notifications.mqh  
> │ └── RecoveryManager.mqh  
> ├── python/  
> │ ├── research/  
> │ ├── analytics/  
> │ ├── models/  
> │ ├── backtesting/  
> │ ├── reporting/  
> │ └── api/  
> ├── tests/  
> │ ├── unit/  
> │ ├── integration/  
> │ ├── risk/  
> │ └── strategy/  
> ├── data/  
> ├── reports/  
> ├── docs/  
> ├── config/  
> ├── requirements.txt  
> └── README.md

Change this layout if a simpler or more robust design is justified. Do
not create empty placeholder files and call the project complete.

# PART VIII — BACKTESTING, STATISTICS AND VALIDATION

## 30. Data and backtest integrity

- Prefer high-quality tick data for final execution-sensitive testing.
  Document source, date coverage, timezone, gaps, and any
  transformations.

- Use the intended broker's data where possible. State clearly when
  proxy data is used.

- Model variable spreads, commission, swap where relevant, slippage,
  latency, rejected orders, and realistic fill assumptions.

- Do not assume candle OHLC data can reproduce intrabar stop/target
  ordering accurately.

- Prevent look-ahead bias, survivorship/data-selection bias, future-bar
  access, repainting, and data leakage.

- Use closed-bar logic consistently where required.

- Separate development, validation, and final untouched test periods.

- Do not repeatedly tune against the final out-of-sample period.

## 31. Required validation methods

- MT5 Strategy Tester with the most realistic available tick modelling.

- Independent Python calculations for trade statistics and
  reconciliation where feasible.

- In-sample and untouched out-of-sample tests.

- Walk-forward analysis.

- Parameter sensitivity and stability analysis.

- Monte Carlo resampling or trade-sequence perturbation, with
  assumptions documented.

- Spread and slippage stress tests.

- Performance by year, month, session, direction, volatility regime, and
  strategy.

- Consecutive-loss and drawdown stress scenarios.

- Execution failure, disconnection, restart, duplicate order, and
  missing-stop tests.

- Demo forward testing on Exness before any live consideration.

## 32. Required metrics

| **Metric**       | **Reporting requirement**                                      |
|------------------|----------------------------------------------------------------|
| Trade count      | Total and by strategy, regime, session, direction              |
| Win rate         | Report with sample size; never use alone                       |
| Gross/net P&L    | After stated trading costs                                     |
| Profit factor    | Define calculation and sample                                  |
| Expectancy       | Per trade and preferably in R units                            |
| Maximum drawdown | Equity and balance; define method                              |
| Recovery factor  | Define calculation                                             |
| Sharpe/Sortino   | Only with suitable return series and stated assumptions        |
| Average win/loss | Include distribution and outliers                              |
| Losing streak    | Maximum and distribution                                       |
| Holding time     | Average and distribution                                       |
| Cost impact      | Spread, commission, swap, slippage assumptions                 |
| Stability        | By time period, market regime, session and parameter variation |

Report the sample size and uncertainty. A small number of trades is not
persuasive evidence. A profitable backtest does not prove future
profitability. Explain whether results are gross or net of costs.

## 33. Strategy promotion and removal

A strategy can be promoted only if it shows robust out-of-sample
performance, acceptable drawdown, plausible execution assumptions, and
stability across more than one market condition. A strategy that fails
must be revised, restricted, or removed. Do not hide negative results or
keep a strategy merely because it was part of the original plan.

## 34. Controlled self-evaluation

GOLD AI may analyse its own performance and propose changes, but must
not autonomously modify live rules. Every proposed change requires a
written rationale, versioned code/configuration, historical re-test,
out-of-sample test, walk-forward test, risk review, and explicit human
approval before deployment.

# PART IX — OPERATIONS, SECURITY AND RECOVERY

## 35. Modes of operation

| **Mode** | **Purpose**                             | **Restrictions**                                             |
|----------|-----------------------------------------|--------------------------------------------------------------|
| RESEARCH | Data analysis and hypothesis testing    | No broker orders                                             |
| BACKTEST | Historical simulation                   | No live orders                                               |
| DEMO     | Forward testing on Exness Standard Demo | Demo account must be verified                                |
| LIVE     | Real-money execution after approval     | Explicit manual enablement and all promotion gates satisfied |

Display the active mode prominently. Verify account login/server/account
type as configured. If the EA detects an account or mode mismatch, block
new trades.

## 36. Recovery and fail-safe behaviour

- On terminal/EA restart, read actual broker positions and orders,
  reconcile them with persistent internal state, and prevent duplicate
  entries.

- Persist the daily drawdown baseline, daily trade count, lockout state,
  strategy identifiers, and relevant risk state.

- Handle MT5/VPS disconnection, stale data, Python/API outage, database
  outage, Telegram outage, and broker rejection.

- Do not assume an order request succeeded. Verify the actual position
  and its SL/TP.

- If state cannot be reconciled, block new entries and alert the
  operator.

- Existing positions must remain protected broker-side even when
  external services are unavailable.

- Provide a tested manual emergency stop and documented recovery
  procedure.

## 37. Security and privacy

- Never store broker passwords or API keys in source code or Git.

- Use environment variables or an appropriate secret manager for API
  credentials.

- Keep the Anthropic API key server-side only.

- Use least-privilege access for VPS, database, Telegram bot, and
  deployment credentials.

- Redact secrets from logs and exception traces.

- Use authenticated, encrypted connections for any network service.

- Keep an audit log for configuration changes and manual interventions.

# PART X — TELEGRAM, REPORTING AND FUTURE DASHBOARD

## 38. Telegram notifications

- System started/stopped and active mode.

- New trade opened, with symbol, direction, strategy, entry, SL, TP,
  volume and risk estimate.

- Trade closed, with net result and reason.

- Daily drawdown warnings and lockout.

- Execution rejection, missing stop, stale data, connection problem, or
  safe-mode activation.

- Daily/weekly performance report with trade count, net result,
  drawdown, and strategy breakdown.

Telegram is notification-only in the initial version. Do not implement
remote trade execution or risk-setting commands in the first release.

## 39. Future read-only dashboard

- Account balance/equity and floating P&L.

- Open positions and verified stop-loss status.

- Daily performance, drawdown, and remaining entry allowance.

- Current market regime and eligible strategy.

- Trade history, strategy breakdown, and performance charts.

- System health, connection state, last data timestamp, API health, and
  recent errors.

- Configuration version and active mode.

Use Next.js, TypeScript, Tailwind CSS, and TradingView Lightweight
Charts if/when a dashboard is justified. It must initially be read-only
and must never be a required dependency for account protection.

# PART XI — DEVELOPMENT ROADMAP AND ACCEPTANCE

## 40. Required development phases

1.  Research: XAUUSD market behaviour, Exness specifications, strategy
    evidence, platform constraints, data sources, and API documentation.

2.  System design: architecture, interfaces, market-regime definitions,
    strategy rules, risk contract, recovery, and test plan.

3.  Risk-first EA foundation: symbol/account validation, broker
    specification discovery, persistent daily drawdown, volume/risk
    calculation, protective-stop verification, execution guards,
    logging, and recovery.

4.  Strategy modules: implement each candidate separately with
    standardised signals and unit tests.

5.  Regime engine: implement, calibrate, and validate regime
    classification and strategy selection.

6.  Backtesting: run realistic tests, out-of-sample validation,
    walk-forward, sensitivity, Monte Carlo, and cost stress tests.

7.  Claude integration: add secure, optional, structured advisory calls
    only after the deterministic system and safety contract are stable.

8.  Demo deployment: run on the \$20 Exness Standard Demo and monitor
    forward execution for a meaningful period and sufficient sample.

9.  Readiness review: audit all acceptance criteria, unresolved risks,
    and evidence before considering live mode.

10. Future dashboard and advanced ML: only after the core system is
    stable and the feature has a demonstrated benefit.

## 41. Acceptance criteria

- The EA can prove it only trades the approved XAUUSD symbol.

- It detects and verifies the configured Exness demo account and refuses
  unexpected accounts/modes.

- It obtains broker symbol specifications dynamically and uses them in
  risk calculations.

- It enforces the 10% daily equity drawdown lockout persistently across
  restarts.

- It enforces no more than three new entries per configured trading day.

- It refuses volume that exceeds permitted monetary risk, including
  minimum-lot constraints.

- Every live/demo position has a verified protective stop-loss.

- It contains no martingale, grid recovery, averaging down, or
  loss-driven risk escalation.

- It prevents duplicate entries and safely reconciles state after
  restart.

- It records both accepted and rejected opportunities with reasons.

- It can operate its hard risk controls when Claude, Python, Telegram,
  or the dashboard is unavailable.

- Claude output is schema-validated, advisory-only, time-bounded, and
  never directly executable.

- Backtests include documented data, costs, assumptions, sample sizes,
  and out-of-sample results.

- All critical risk and recovery behaviours have automated tests.

- Live mode cannot activate accidentally and requires explicit human
  approval.

## 42. Required evidence pack

For each acceptance criterion, provide the test name, test procedure,
expected result, actual result, log/report reference, and pass/fail
status. Include source code version/commit, EA build details,
configuration version, data version, and test environment. A successful
compile is not evidence that the trading system is safe or profitable.

# PART XII — FIRST RESPONSE REQUIRED FROM CLAUDE

## 43. Do not code yet — deliver these items first

11. Executive summary of the proposed GOLD AI system and the main risks.

12. XAUUSD market research report with credible sources and explicit
    limitations.

13. Exness/MT5 technical checklist: exact symbol discovery, contract
    properties, volume rules, stop levels, margin and execution details
    to verify at runtime.

14. Comparative research on all five strategy families, including
    failure modes and evidence quality.

15. Recommended initial strategy set and clear reasons for enabling,
    restricting, or postponing each strategy.

16. Precise, testable market-regime definitions and the
    strategy-selection state machine.

17. Detailed risk-manager specification, including formulas, daily
    baseline, reset rules, and small-account skip logic.

18. MQL5/Python/Claude architecture and versioned data contracts.

19. Anthropic API integration plan, including secure secrets, model
    selection verification, structured output, cost controls,
    timeout/retry policy, and failure behaviour.

20. Backtesting and validation plan designed to prevent overfitting and
    execution fantasy.

21. Repository layout and milestone plan with deliverables and tests.

22. Threat model and failure-mode analysis for missing stops, restarts,
    duplicate orders, stale data, network failure, and unexpected
    account/symbol.

23. List of assumptions, unknowns, and decisions that genuinely require
    the user's approval.

24. Your professional recommendation: what to build first, what to
    postpone, and what not to build.

After presenting the research and architecture, STOP and wait for
explicit approval. Do not start generating the complete implementation
until approval is given.

# PART XIII — FINAL OPERATING PRINCIPLE

GOLD AI is not intended to trade constantly or to promise fast wealth.
It is intended to identify only well-defined, testable XAUUSD
opportunities, select among independently validated strategy families
according to market conditions, execute with strict and locally enforced
risk controls, and refuse to trade when evidence or execution conditions
are inadequate.

The system should be opportunity-seeking but risk-capped. It must prefer
survival, reliable execution, and honest measurement over activity,
impressive backtests, or unrealistic return targets.

If a strategy has no demonstrated edge after realistic costs, do not
deploy it. If a trade exceeds the risk budget, skip it. If the stop
cannot be verified, do not maintain unprotected exposure. If the system
is uncertain, stop opening new trades. These rules are mandatory.

# REFERENCE DOCUMENTATION TO VERIFY DURING RESEARCH

Use current official documentation and verify URLs before relying on
them. At minimum, consult:

- MetaTrader 5 / MQL5 documentation: https://www.mql5.com/en/docs

- MetaTrader 5 Strategy Tester documentation:
  https://www.metatrader5.com/en/terminal/help/algotrading/testing

- MetaTrader 5 tick-generation/testing documentation:
  https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation

- Anthropic API overview:
  https://platform.claude.com/docs/en/api/overview

- Anthropic API getting started:
  https://platform.claude.com/docs/en/get-started

- Anthropic API pricing: https://www.anthropic.com/pricing#anthropic-api

- Exness official website and current contract specifications:
  https://www.exness.com/

- QuantConnect Algorithm Framework overview (research reference):
  https://www.quantconnect.com/docs/v2/writing-algorithms/algorithm-framework/overview

- QuantConnect risk-management concepts (research reference):
  https://www.quantconnect.com/docs/v1/algorithm-framework/risk-management

- FCA algorithmic trading controls review (governance reference):
  https://www.fca.org.uk/publications/multi-firm-reviews/algorithmic-trading-controls-high-level-observations

Do not treat a reference as proof that a trading strategy works.
Platform documentation establishes platform behaviour; strategy
performance must be established through reproducible testing on
appropriate data.

**END OF MASTER SPECIFICATION**
