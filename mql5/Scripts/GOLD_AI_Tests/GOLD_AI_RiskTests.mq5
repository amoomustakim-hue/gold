//+------------------------------------------------------------------+
//| GOLD AI - unit tests for the pure risk modules                   |
//| Run: drag onto any chart in MT5. Results go to the Experts log   |
//| and to Common\Files\GOLD_AI\test_results.txt                     |
//| These tests place NO orders and touch NO account state.          |
//+------------------------------------------------------------------+
#property version "0.10"

#include <GOLD_AI/Types.mqh>
#include <GOLD_AI/Config.mqh>
#include <GOLD_AI/Sizing.mqh>
#include <GOLD_AI/StateCodec.mqh>
#include <GOLD_AI/RiskCore.mqh>

int    g_pass = 0;
int    g_fail = 0;
string g_failures = "";

void Check(const bool cond, const string name)
  {
   if(cond) { g_pass++; return; }
   g_fail++;
   g_failures += "FAIL: " + name + "\n";
   Print("FAIL: ", name);
  }

void CheckNear(const double got, const double want, const string name, const double tol = 1e-6)
  {
   Check(MathAbs(got - want) <= tol, name + " (got " + DoubleToString(got, 6) + ", want " + DoubleToString(want, 6) + ")");
  }

//--- Gold-like spec: 1 lot = 100 oz, tick 0.001 -> $0.10 per tick per lot
void GoldSizing(GASizingInput &in, const double budget, const double stop)
  {
   in.risk_budget        = budget;
   in.stop_distance      = stop;
   in.tick_size          = 0.001;
   in.tick_value_loss    = 0.1;
   in.vol_min            = 0.01;
   in.vol_step           = 0.01;
   in.vol_max            = 200.0;
   in.commission_per_lot = 0.0;
   in.slippage_price     = 0.0;
  }

void TestSizing()
  {
   GASizingInput in; GASizingResult r;

   GoldSizing(in, 2.40, 2.0); in.slippage_price = 0.10;
   GA_CalcVolume(in, r);
   Check(r.code == GA_SIZE_OK, "sizing: $20 scalp is OK");
   CheckNear(r.volume, 0.01, "sizing: $20 scalp -> 0.01 lot");
   CheckNear(r.risk_at_volume, 2.10, "sizing: $20 scalp risk incl. slippage");

   GoldSizing(in, 1.00, 2.0); GA_CalcVolume(in, r);
   Check(r.code == GA_SIZE_MIN_LOT_EXCEEDS_RISK, "sizing: min lot above budget is SKIPPED, not rounded up");
   CheckNear(r.volume, 0.0, "sizing: skipped trade has zero volume");

   GoldSizing(in, 10.0, 2.0); GA_CalcVolume(in, r);
   CheckNear(r.volume, 0.05, "sizing: exact budget gives exact steps (no float under-count)");

   GoldSizing(in, 10.99, 2.0); GA_CalcVolume(in, r);
   CheckNear(r.volume, 0.05, "sizing: rounds DOWN (10.99 budget -> 0.05, not 0.06)");

   GoldSizing(in, 1e9, 2.0); GA_CalcVolume(in, r);
   CheckNear(r.volume, 200.0, "sizing: capped at volume max");

   GoldSizing(in, 2.0, 0.0); GA_CalcVolume(in, r);
   Check(r.code == GA_SIZE_BAD_INPUT, "sizing: zero stop distance rejected");

   GoldSizing(in, 2.0, 2.0); in.tick_value_loss = 0; GA_CalcVolume(in, r);
   Check(r.code == GA_SIZE_BAD_INPUT, "sizing: zero tick value rejected");

   GoldSizing(in, 0.0, 2.0); GA_CalcVolume(in, r);
   Check(r.code == GA_SIZE_NO_BUDGET, "sizing: zero budget -> NO_BUDGET");

   GoldSizing(in, 2.07, 2.0); in.commission_per_lot = 7.0; GA_CalcVolume(in, r);
   CheckNear(r.volume, 0.01, "sizing: commission included, exactly fits");
   GoldSizing(in, 2.06, 2.0); in.commission_per_lot = 7.0; GA_CalcVolume(in, r);
   Check(r.code == GA_SIZE_MIN_LOT_EXCEEDS_RISK, "sizing: commission pushes min lot over budget -> skip");

   // Property: an OK result never risks more than the budget.
   MathSrand(12345);
   bool never_over = true, never_below_min = true;
   for(int i = 0; i < 5000; i++)
     {
      GoldSizing(in, 0.5 + MathRand() / 32767.0 * 200.0, 0.2 + MathRand() / 32767.0 * 30.0);
      in.slippage_price = MathRand() / 32767.0 * 0.3;
      GA_CalcVolume(in, r);
      if(r.code == GA_SIZE_OK && r.risk_at_volume > in.risk_budget * (1.0 + 1e-9)) never_over = false;
      if(r.code == GA_SIZE_OK && r.volume < in.vol_min - 1e-12) never_below_min = false;
     }
   Check(never_over, "sizing property: never risks more than the budget (5000 random cases)");
   Check(never_below_min, "sizing property: never returns a volume below the minimum");

   CheckNear(GA_RiskBudget(20, 12, 2.5, 5), 2.40, "budget: 12% of $20");
   CheckNear(GA_RiskBudget(100, 12, 2.5, 5), 2.50, "budget: capped at $2.50");
   CheckNear(GA_RiskBudget(20, 12, 2.5, 1.0), 1.00, "budget: limited by remaining daily room");
   CheckNear(GA_RiskBudget(20, 12, 2.5, 0.0), 0.00, "budget: no room left -> zero");
   CheckNear(GA_RiskBudget(-5, 12, 2.5, 5), 0.00, "budget: negative equity -> zero");
   Check(GA_VolumeDigits(0.01) == 2 && GA_VolumeDigits(0.1) == 1 && GA_VolumeDigits(1.0) == 0, "volume digits");
  }

void TestConfig()
  {
   GAConfig c; string err;
   GA_FillDefaults(GA_MODE_SCALP, c);
   Check(GA_ValidateConfig(c, err), "config: SCALP defaults valid " + err);
   Check(c.max_entries_per_day == 15 && c.daily_loss_usd == 5.0, "config: SCALP = 15 entries, $5 daily");
   GA_FillDefaults(GA_MODE_NORMAL, c);
   Check(GA_ValidateConfig(c, err), "config: NORMAL defaults valid " + err);
   Check(c.max_entries_per_day == 3, "config: NORMAL = 3 entries");

   GA_FillDefaults(GA_MODE_SCALP, c); c.risk_pct = 25;           Check(!GA_ValidateConfig(c, err), "config: risk above hard max rejected");
   GA_FillDefaults(GA_MODE_SCALP, c); c.max_entries_per_day = 0; Check(!GA_ValidateConfig(c, err), "config: zero entries rejected");
   GA_FillDefaults(GA_MODE_SCALP, c); c.max_entries_per_day = 99; Check(!GA_ValidateConfig(c, err), "config: entries above hard max rejected");
   GA_FillDefaults(GA_MODE_SCALP, c); c.daily_loss_usd = 0; c.daily_loss_pct = 0; Check(!GA_ValidateConfig(c, err), "config: no daily limit rejected");
   GA_FillDefaults(GA_MODE_SCALP, c); c.daily_loss_pct = 80;     Check(!GA_ValidateConfig(c, err), "config: daily % above hard max rejected");
   GA_FillDefaults(GA_MODE_SCALP, c); c.virtual_start = 20; c.virtual_blown_at = 25; Check(!GA_ValidateConfig(c, err), "config: blown-at above virtual start rejected");
   GA_FillDefaults(GA_MODE_SCALP, c); c.max_slippage_usd = 5;    Check(!GA_ValidateConfig(c, err), "config: slippage above hard max rejected");
  }

void FreshState(GAState &s, const double equity, const double virtual_start)
  {
   GA_StateInit(s, 123456, 20261109, equity, virtual_start);
  }

void TestRiskCore()
  {
   GAConfig c; GA_FillDefaults(GA_MODE_SCALP, c);
   GAState s;

   // Daily limit: stricter of $ and %
   FreshState(s, 1000, 0);
   CheckNear(GA_DailyLossLimit(c, s), 5.0, "limit: $5 only");
   c.daily_loss_pct = 0.1;  CheckNear(GA_DailyLossLimit(c, s), 1.0, "limit: 0.1% of $1000 is stricter");
   c.daily_loss_pct = 10;   CheckNear(GA_DailyLossLimit(c, s), 5.0, "limit: $5 stricter than 10%");
   c.daily_loss_pct = 0;

   Check(!GA_DailyLimitHit(c, s, 995.01), "limit: $4.99 loss not hit");
   Check(GA_DailyLimitHit(c, s, 995.00),  "limit: exactly $5 loss is hit");
   Check(GA_DailyLimitHit(c, s, 990.00),  "limit: $10 loss is hit");
   Check(!GA_DailyLimitHit(c, s, 1010.0), "limit: profit not hit");
   CheckNear(GA_RemainingDailyRoom(c, s, 997.0), 2.0, "room: $3 lost leaves $2");

   // Virtual $20 account on a $1000 demo
   FreshState(s, 1000, 20);
   CheckNear(GA_SizingEquity(s, 1000), 20.0, "virtual: starts at $20");
   CheckNear(GA_SizingEquity(s, 997), 17.0, "virtual: -$3 -> $17");
   c.daily_loss_pct = 25; CheckNear(GA_DailyLossLimit(c, s), 5.0, "virtual: 25% of virtual $20 = $5"); c.daily_loss_pct = 0;
   Check(GA_VirtualBlown(c, s, 982.0), "virtual: $2 left is blown");
   Check(!GA_VirtualBlown(c, s, 983.0), "virtual: $3 left not blown");
   GAState real; FreshState(real, 20, 0);
   Check(!GA_VirtualBlown(c, real, 1.0), "virtual: off on real accounts");

   // Deposits/withdrawals don't hide losses or trigger the lock
   FreshState(s, 1000, 20);
   GA_ApplyExternalFlow(s, 500);
   Check(!GA_DailyLimitHit(c, s, 1500), "flow: deposit does not count as profit/loss");
   CheckNear(GA_SizingEquity(s, 1500), 20.0, "flow: deposit does not inflate virtual equity");
   Check(GA_DailyLimitHit(c, s, 1495), "flow: loss after deposit still caught");
   FreshState(s, 1000, 0);
   GA_ApplyExternalFlow(s, -300);
   Check(!GA_DailyLimitHit(c, s, 700), "flow: withdrawal does not trigger lock");

   // New day
   FreshState(s, 1000, 0);
   s.entries_today = 7; s.consecutive_losses = 2; s.pause_rest_of_day = true;
   GA_SetLock(s, GA_LOCK_DAILY_LOSS, s.day_key, "test");
   Check(!GA_ApplyNewDay(s, 20261109, 990), "day: same day does nothing");
   Check(s.lock == GA_LOCK_DAILY_LOSS && s.entries_today == 7, "day: same day keeps lock and count");
   Check(GA_ApplyNewDay(s, 20261110, 990), "day: next day detected");
   Check(s.lock == GA_LOCK_NONE, "day: daily lock clears next day");
   Check(s.entries_today == 0 && s.consecutive_losses == 0 && !s.pause_rest_of_day, "day: counters reset");
   CheckNear(s.baseline_equity, 990, "day: new baseline = equity at day start");
   GA_SetLock(s, GA_LOCK_EMERGENCY, s.day_key, "manual");
   GA_ApplyNewDay(s, 20261111, 990);
   Check(s.lock == GA_LOCK_EMERGENCY, "day: emergency lock survives a new day");
   GA_SetLock(s, GA_LOCK_DAILY_LOSS, s.day_key, "x");
   Check(s.lock == GA_LOCK_EMERGENCY, "lock: emergency is never downgraded to daily");
   Check(GA_DayKey(D'2026.11.09 23:59:59') == 20261109 && GA_DayKey(D'2026.11.10 00:00:00') == 20261110, "day key boundary");

   // Loss streaks
   datetime now = D'2026.11.09 10:00:00';
   FreshState(s, 1000, 0);
   GA_RecordClosedTrade(s, c, -1, now); GA_RecordClosedTrade(s, c, -1, now);
   Check(s.pause_until == 0, "streak: 2 losses no pause");
   GA_RecordClosedTrade(s, c, -1, now);
   Check(s.pause_until == now + 60 * 60, "streak: SCALP 3 losses -> 60 min pause");
   FreshState(s, 1000, 0);
   GA_RecordClosedTrade(s, c, -1, now); GA_RecordClosedTrade(s, c, 2, now);
   Check(s.consecutive_losses == 0, "streak: win resets");
   GAConfig cn; GA_FillDefaults(GA_MODE_NORMAL, cn);
   FreshState(s, 1000, 0);
   for(int i = 0; i < 3; i++) GA_RecordClosedTrade(s, cn, -1, now);
   Check(s.pause_rest_of_day, "streak: NORMAL 3 losses -> rest of day");
  }

void OkGate(GAGateInput &g)
  {
   g.now = D'2026.11.09 10:00:00';
   g.guards_ok = true; g.connected = true; g.trade_allowed = true;
   g.tick_age_sec = 1; g.spread = 0.20; g.stop_distance = 2.0;
   g.open_positions = 0; g.unprotected_positions = 0; g.real_equity = 1000;
  }

void TestGate()
  {
   GAConfig c; GA_FillDefaults(GA_MODE_SCALP, c);
   GAState s; GAGateInput g; string why;
   FreshState(s, 1000, 20); OkGate(g);
   Check(GA_EntryAllowed(c, s, g, why), "gate: normal conditions pass " + why);

   FreshState(s, 1000, 20); GA_SetLock(s, GA_LOCK_DAILY_LOSS, s.day_key, "t"); OkGate(g); Check(!GA_EntryAllowed(c, s, g, why), "gate: lock blocks");
   FreshState(s, 1000, 20); OkGate(g); g.guards_ok = false;          Check(!GA_EntryAllowed(c, s, g, why), "gate: failed guards block");
   FreshState(s, 1000, 20); OkGate(g); g.connected = false;          Check(!GA_EntryAllowed(c, s, g, why), "gate: disconnected blocks");
   FreshState(s, 1000, 20); OkGate(g); g.trade_allowed = false;      Check(!GA_EntryAllowed(c, s, g, why), "gate: algo trading off blocks");
   FreshState(s, 1000, 20); OkGate(g); g.unprotected_positions = 1;  Check(!GA_EntryAllowed(c, s, g, why), "gate: unprotected position blocks");
   FreshState(s, 1000, 20); OkGate(g); g.real_equity = 995;          Check(!GA_EntryAllowed(c, s, g, why), "gate: daily limit blocks even before lock is set");
   FreshState(s, 1000, 20); OkGate(g); s.entries_today = 15;         Check(!GA_EntryAllowed(c, s, g, why), "gate: 15 entries blocks the 16th");
   FreshState(s, 1000, 20); OkGate(g); s.entries_today = 14;         Check(GA_EntryAllowed(c, s, g, why), "gate: 15th entry allowed");
   FreshState(s, 1000, 20); OkGate(g); g.open_positions = 1;         Check(!GA_EntryAllowed(c, s, g, why), "gate: SCALP one position at a time");
   FreshState(s, 1000, 20); OkGate(g); s.last_loss_time = g.now - 120; Check(!GA_EntryAllowed(c, s, g, why), "gate: cool-down 2 min after loss blocks");
   FreshState(s, 1000, 20); OkGate(g); s.last_loss_time = g.now - 301; Check(GA_EntryAllowed(c, s, g, why), "gate: cool-down over after 5 min");
   FreshState(s, 1000, 20); OkGate(g); s.pause_until = g.now + 10;   Check(!GA_EntryAllowed(c, s, g, why), "gate: loss-streak pause blocks");
   FreshState(s, 1000, 20); OkGate(g); s.pause_rest_of_day = true;   Check(!GA_EntryAllowed(c, s, g, why), "gate: rest-of-day pause blocks");
   FreshState(s, 1000, 20); OkGate(g); g.tick_age_sec = 11;          Check(!GA_EntryAllowed(c, s, g, why), "gate: stale tick blocks");
   FreshState(s, 1000, 20); OkGate(g); g.spread = 0.36;              Check(!GA_EntryAllowed(c, s, g, why), "gate: spread above $0.35 blocks");
   FreshState(s, 1000, 20); OkGate(g); g.spread = 0.25; g.stop_distance = 1.5; Check(!GA_EntryAllowed(c, s, g, why), "gate: spread > 15% of stop blocks");
   FreshState(s, 1000, 20); OkGate(g); g.spread = 0.0;               Check(!GA_EntryAllowed(c, s, g, why), "gate: zero spread (bad data) blocks");
   FreshState(s, 1000, 20); OkGate(g); g.real_equity = 982; c.daily_loss_usd = 100;
   Check(!GA_EntryAllowed(c, s, g, why) && why == "virtual account blown", "gate: blown virtual account blocks");
  }

void TestStateCodec()
  {
   GAState s, t; string err;
   FreshState(s, 1234.56, 20);
   s.entries_today = 4; s.consecutive_losses = 2; s.last_loss_time = D'2026.11.09 10:00:00';
   s.pause_until = D'2026.11.09 11:00:00'; s.pause_rest_of_day = true;
   s.lock = GA_LOCK_DAILY_LOSS; s.lock_day = 20261109; s.lock_reason = "day loss $5.00\ninjected"; s.last_flow_deal = 987654321;
   string text = GA_StateSerialize(s);
   Check(GA_StateParse(text, 123456, t, err), "codec: round trip parses " + err);
   Check(t.day_key == s.day_key && t.entries_today == 4 && t.consecutive_losses == 2 && t.lock == GA_LOCK_DAILY_LOSS &&
         t.lock_day == 20261109 && t.last_flow_deal == 987654321 && t.pause_rest_of_day && t.last_loss_time == s.last_loss_time &&
         t.pause_until == s.pause_until, "codec: fields survive round trip");
   CheckNear(t.baseline_equity, 1234.56, "codec: baseline survives");
   CheckNear(t.virtual_start, 20, "codec: virtual start survives");
   Check(StringFind(t.lock_reason, "\n") < 0, "codec: newline in reason is sanitized");

   string tampered = text;
   StringReplace(tampered, "baseline_equity=1234.56", "baseline_equity=9999.00");
   Check(!GA_StateParse(tampered, 123456, t, err) && err == "checksum mismatch", "codec: edited baseline rejected");
   string unlock = text;
   StringReplace(unlock, "lock=1", "lock=0");
   Check(!GA_StateParse(unlock, 123456, t, err), "codec: hand-cleared lock rejected");
   Check(!GA_StateParse(text, 999, t, err), "codec: other account's state rejected");
   Check(!GA_StateParse("", 123456, t, err), "codec: empty file rejected");
   string missing = text;
   StringReplace(missing, "entries_today=4\n", "");
   Check(!GA_StateParse(missing, 123456, t, err), "codec: missing key rejected");
   string crlf = text;
   StringReplace(crlf, "\n", "\r\n");
   Check(GA_StateParse(crlf, 123456, t, err), "codec: Windows line endings accepted");
  }

void OnStart()
  {
   TestSizing();
   TestConfig();
   TestRiskCore();
   TestGate();
   TestStateCodec();

   string summary = StringFormat("GOLD AI %s risk tests: %d passed, %d failed", GA_VERSION, g_pass, g_fail);
   Print(summary);
   FolderCreate(GA_FOLDER, FILE_COMMON);
   int h = FileOpen(GA_FOLDER + "\\test_results.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h, summary + "\n" + g_failures);
      FileClose(h);
     }
   Alert(summary);
  }
