# M1: install and test the risk engine (Windows)

M1 is the safety layer with **no trading strategy**. It can't trade on its own. The only
order it can ever place is the optional **demo-only self-test** (step 6), which opens the
smallest trade with a stop-loss, checks the stop is really there, and closes it 10 seconds later.

The code was written in a Linux cloud session with **no MetaTrader compiler**, so it has
**not been compiled yet**. Step 3 is the first real compile. Send me any errors exactly as MetaEditor shows them.

## 1. Prepare the demo account
1. In the Exness Personal Area, open (or reset) an **MT5 Standard demo** and set the balance to **$1,000**.
2. Log in to it in MetaTrader 5 for Windows.
3. Write down the **account number**. You'll need it in step 5.
4. Make sure **XAUUSD** is in Market Watch (right-click → Symbols → search XAUUSD → Show).

## 2. Copy the files into MT5
1. MT5 → **File → Open Data Folder**. A folder opens. Go into `MQL5`.
2. From this repo, copy:
   - `mql5/Include/GOLD_AI/` → `MQL5\Include\GOLD_AI\`
   - `mql5/Experts/GOLD_AI/` → `MQL5\Experts\GOLD_AI\`
   - `mql5/Scripts/GOLD_AI_Tests/` → `MQL5\Scripts\GOLD_AI_Tests\`

   (On GitHub: green **Code** button → **Download ZIP**, unzip, then copy those folders.)

## 3. Compile
1. MT5 → **Tools → MetaQuotes Language Editor** (F4).
2. In the Navigator, open `Scripts\GOLD_AI_Tests\GOLD_AI_RiskTests.mq5` → press **F7** (Compile).
3. Open `Experts\GOLD_AI\GOLD_AI.mq5` → **F7**.
4. Look at the **Errors** tab at the bottom. It should say `0 errors`. **If there are errors, copy
   the whole Errors tab and send it to me.** Warnings are fine to send too.

## 4. Run the unit tests (no orders, no account changes)
1. Back in MT5, Navigator → **Scripts → GOLD_AI_Tests → GOLD_AI_RiskTests** → drag it onto any chart.
2. A pop-up shows `GOLD AI 0.1.0-M1 risk tests: N passed, 0 failed`.
3. The full result is saved to `%APPDATA%\MetaQuotes\Terminal\Common\Files\GOLD_AI\test_results.txt`.
   **Send me that file's contents**, especially if anything failed.

## 5. Attach the EA (no self-test yet)
1. Turn on **Algo Trading** (toolbar button, should be green).
2. Open an **XAUUSD** chart (any timeframe; M1 recommended for later).
3. Navigator → **Expert Advisors → GOLD_AI → GOLD_AI** → drag onto the XAUUSD chart.
4. **Common** tab: tick *Allow Algo Trading*.
5. **Inputs** tab: set **InpExpectedLogin** = your demo account number. Leave everything else at its default:
   - `InpMode = SCALP`, `InpVirtualStart = 20` (the $1,000 demo behaves like $20), `InpDailyLossUSD = 5`.
6. Click OK. The chart's top-left corner should show:
   ```
   GOLD AI 0.1.0-M1   MODE: SCALP   [DEMO]
   Strategy: NONE (M1 risk engine only)
   Lock: NONE
   Today: -$0.00 of $5.00   Entries 0/15
   Virtual equity: $20.00
   New entry allowed: yes
   ```
   If it says *New entry allowed: no - …*, the reason is shown, e.g. spread too wide or market closed.
   That's the gate working. Note what it says.

## 6. Run the self-test trade (demo only)
1. During market hours (not weekends, not right at the daily rollover), right-click the chart → Expert list → GOLD_AI → Properties.
2. Inputs → **InpSelfTestTrade = true** → OK.
3. Within a few seconds: a BUY of **0.01** XAUUSD opens **with a stop-loss ~$2 below and a target ~$2 above**,
   then closes about 10 seconds later. The Experts tab should show `selftest_open_verified` then `selftest_pass`.
4. Set **InpSelfTestTrade = false** again.

## 7. Phone alerts (optional, free)
1. Install **MetaTrader 5** on your phone → Settings → Messages → copy your **MetaQuotes ID**.
2. Desktop MT5 → **Tools → Options → Notifications** → tick *Enable Push Notifications* → paste the ID → Test.
3. The EA's alerts (start, self-test, locks, closed trades) now arrive on your phone.

## 8. Acceptance checks (please run and report)

| # | Check | How | Expected |
|---|---|---|---|
| A1 | Unit tests | Step 4 | 0 failed |
| A2 | Only XAUUSD | Drag the EA onto a EURUSD chart | Refuses: "attach to an XAUUSD chart only" |
| A3 | Wrong account | Set `InpExpectedLogin` to a wrong number | Refuses with the account message |
| A4 | Stop verified | Step 6 | `selftest_pass` in the log, and the stop was visible on the chart |
| A5 | Restart-safe state | After step 6, close MT5 completely and reopen it | `Entries 1/15` still shown (not reset to 0) |
| A6 | Tamper-proof state | Close MT5, edit `Common\Files\GOLD_AI\state_<login>.txt` (change any number), reopen | `Lock: STATE_CORRUPT`, alert sent |
| A7 | Emergency stop | Set `InpEmergencyStop = true` | `Lock: EMERGENCY`. It stays locked after a restart until you set `InpClearManualLock = true` (and EmergencyStop false) |
| A8 | Manual trade without stop | Open a manual XAUUSD trade with **no** SL from the trade panel | Within 5 s: "New entry allowed: no - a position has no stop-loss". The EA does **not** touch your manual trade. Close it yourself. |
| A9 | Real account refused | (Only if you have one) attach with defaults | Refuses: live trading not enabled |

For **A6**, after the test either wait for the next trading day, or delete both
`state_<login>.txt` and the terminal global variable `GOLD_AI_INIT_<login>` (MT5 → Tools →
Global Variables, F3) to start fresh. Deleting only the file keeps it locked. That's deliberate.

## Where things are written
`%APPDATA%\MetaQuotes\Terminal\Common\Files\GOLD_AI\`
- `events_<login>.jsonl`: every decision and event (the trade journal)
- `state_<login>.txt`: persistent risk state (checksummed)
- `status_<login>.txt`: live status, refreshed every 5 s
- `test_results.txt`: unit test output

**Send me back:** the compile result, `test_results.txt`, and `events_<login>.jsonl` after the acceptance checks.
