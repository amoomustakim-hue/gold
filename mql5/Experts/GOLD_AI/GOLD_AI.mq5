//+------------------------------------------------------------------+
//| GOLD AI - XAUUSD Expert Advisor                                   |
//| Milestone M1: risk engine only. NO trading strategy is loaded.    |
//| The only order this version can place is the optional demo-only  |
//| self-test trade that proves the stop-loss pipeline works.         |
//+------------------------------------------------------------------+
#property copyright "GOLD AI"
#property version   "0.10"
#property description "GOLD AI M1 - risk engine (no strategy). XAUUSD only."

#include <GOLD_AI/Types.mqh>
#include <GOLD_AI/Config.mqh>
#include <GOLD_AI/Sizing.mqh>
#include <GOLD_AI/StateCodec.mqh>
#include <GOLD_AI/RiskCore.mqh>
#include <GOLD_AI/Journal.mqh>
#include <GOLD_AI/StateStore.mqh>
#include <GOLD_AI/Guards.mqh>
#include <GOLD_AI/Execution.mqh>

//--- Mode and account
input ENUM_GA_MODE InpMode            = GA_MODE_SCALP;  // Trading mode
input long         InpExpectedLogin   = 0;              // Your Exness account number (required)
input string       InpExpectedServer  = "";             // Part of the server name, e.g. "Exness" (optional)
input bool         InpAllowReal       = false;          // Allow a REAL account (keep false)
input string       InpLivePhrase      = "";             // Must equal "I ACCEPT REAL MONEY RISK" for real accounts
//--- Virtual $20 account on a bigger demo
input double       InpVirtualStart    = 20.0;           // Virtual balance on demo (0 = off)
input double       InpVirtualBlownAt  = 2.0;            // Virtual equity treated as "account blown"
//--- Limits (0 = use the mode default)
input double       InpDailyLossUSD    = 5.0;            // Daily loss limit, $ (amendment A3)
input double       InpDailyLossPct    = 0.0;            // Optional % limit; stricter of the two applies
input double       InpRiskPct         = 0.0;            // Risk per trade % (0 = mode default)
input double       InpMaxRiskUSD      = 0.0;            // Max risk per trade $ (0 = mode default)
input int          InpMaxEntries      = 0;              // Max entries per day (0 = mode default)
input double       InpCommissionPerLot = 0.0;           // Round-trip commission per lot, $ (Standard: 0)
//--- Manual controls
input bool         InpEmergencyStop   = false;          // EMERGENCY: close GOLD AI trades and lock
input bool         InpClearManualLock = false;          // Clear an EMERGENCY / VIRTUAL_BLOWN lock
input bool         InpPushAlerts      = true;           // Send alerts to the MT5 phone app
//--- M1 acceptance test
input bool         InpSelfTestTrade   = false;          // DEMO ONLY: open+verify+close one min-lot trade
input double       InpSelfTestStopUSD = 2.0;            // Self-test stop distance, $ per oz

GAConfig      g_cfg;
GAState       g_state;
GASymbolSpec  g_spec;
GAJournal     g_journal;
GANotifier    g_notify;
GAExecution   g_exec;
GAPositionScan g_scan;
bool          g_tester      = false;
bool          g_guards_ok   = false;
string        g_guard_err   = "";
int           g_timer_ticks = 0;
int           g_selftest_stage = 0;     // 0 idle, 1 pending, 2 open, 3 done
ulong         g_selftest_pos = 0;
datetime      g_selftest_opened = 0;

//+------------------------------------------------------------------+
void Alert2(const string msg)
  {
   if(InpPushAlerts) g_notify.Push(msg);
  }

void SaveState()
  {
   if(!GA_StateSave(g_state, g_tester))
      g_journal.Log("state_save_failed", GA_KvInt("err", GetLastError()));
  }

double Equity() { return AccountInfoDouble(ACCOUNT_EQUITY); }

void TriggerLock(const int lock, const string reason)
  {
   int before = g_state.lock;
   GA_SetLock(g_state, lock, g_state.day_key, reason);
   int failed = g_exec.CloseAllOurs();   // amendment A8: close open trades immediately
   SaveState();
   if(g_state.lock != before)
     {
      g_journal.Log("lock", GA_Kv("lock", GA_LockName(g_state.lock)) + "," + GA_Kv("reason", reason) + "," +
                    GA_KvNum("equity", Equity(), 2) + "," + GA_KvInt("close_failures", failed));
      Alert2("LOCKED " + GA_LockName(g_state.lock) + ": " + reason +
             (failed > 0 ? " | CLOSE FAILED x" + (string)failed + " - CHECK NOW" : ""));
     }
  }

ulong LatestFlowDeal(const datetime from)
  {
   ulong latest = 0;
   if(!HistorySelect(from, TimeCurrent() + 86400)) return 0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(d, DEAL_TYPE);
      if((type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_CREDIT || type == DEAL_TYPE_BONUS) && d > latest)
         latest = d;
     }
   return latest;
  }

// Deposits/withdrawals/credits shift the baseline so they neither hide a loss nor trigger the lock.
void ApplyNewFlows()
  {
   if(!HistorySelect(TimeCurrent() - 14 * 86400, TimeCurrent() + 86400)) return;
   int n = HistoryDealsTotal();
   ulong newest = g_state.last_flow_deal;
   bool changed = false;
   for(int i = 0; i < n; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d <= g_state.last_flow_deal) continue;
      long type = HistoryDealGetInteger(d, DEAL_TYPE);
      if(type != DEAL_TYPE_BALANCE && type != DEAL_TYPE_CREDIT && type != DEAL_TYPE_BONUS) continue;
      double amount = HistoryDealGetDouble(d, DEAL_PROFIT);
      GA_ApplyExternalFlow(g_state, amount);
      if(d > newest) newest = d;
      changed = true;
      g_journal.Log("external_flow", GA_KvInt("deal", (long)d) + "," + GA_KvNum("amount", amount, 2));
     }
   if(changed) { g_state.last_flow_deal = newest; SaveState(); }
  }

void CheckGuards()
  {
   string err = "";
   bool ok = GA_CheckSymbol(_Symbol, g_spec, err);
   if(ok) g_exec.UpdateSpec(g_spec);
   if(ok != g_guards_ok || err != g_guard_err)
     {
      g_journal.Log(ok ? "guards_ok" : "guards_failed", GA_Kv("reason", err));
      if(!ok) Alert2("Safety check failed: " + err);
     }
   g_guards_ok = ok;
   g_guard_err = err;
  }

void CheckRiskNow()
  {
   if(GA_ApplyNewDay(g_state, GA_DayKey(TimeTradeServer()), Equity()))
     {
      SaveState();
      g_journal.Log("new_day", GA_KvInt("day", g_state.day_key) + "," + GA_KvNum("baseline", g_state.baseline_equity, 2));
      Alert2("New trading day. Limit $" + DoubleToString(GA_DailyLossLimit(g_cfg, g_state), 2));
     }
   double eq = Equity();
   if(GA_VirtualBlown(g_cfg, g_state, eq) && g_state.lock != GA_LOCK_VIRTUAL_BLOWN)
      TriggerLock(GA_LOCK_VIRTUAL_BLOWN, "virtual equity " + DoubleToString(GA_SizingEquity(g_state, eq), 2));
   else if(g_state.lock == GA_LOCK_NONE && GA_DailyLimitHit(g_cfg, g_state, eq))
      TriggerLock(GA_LOCK_DAILY_LOSS, "day loss $" + DoubleToString(GA_DayLoss(g_state, eq), 2));
  }

void BuildGate(GAGateInput &g, const double stop_distance)
  {
   MqlTick t;
   bool have = SymbolInfoTick(GA_ALLOWED_SYMBOL, t);
   g.now                   = TimeTradeServer();
   g.guards_ok             = g_guards_ok;
   g.connected             = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   g.trade_allowed         = GA_TradeAllowed();
   g.tick_age_sec          = have ? (int)(TimeTradeServer() - t.time) : 999999;
   g.spread                = have ? t.ask - t.bid : 0.0;
   g.stop_distance         = stop_distance;
   g.open_positions        = g_scan.ours;
   g.unprotected_positions = g_scan.unprotected_ours + g_scan.unprotected_other;
   g.real_equity           = Equity();
  }

void WriteStatus()
  {
   double eq = Equity();
   GAGateInput g; BuildGate(g, 0.0);
   string why = "";
   bool can = GA_EntryAllowed(g_cfg, g_state, g, why);
   string s = "";
   s += "version="          + GA_VERSION + "\n";
   s += "mode="             + GA_ModeName(g_cfg.mode) + "\n";
   s += "strategy=NONE (M1 risk engine only)\n";
   s += "account="          + (string)AccountInfoInteger(ACCOUNT_LOGIN) + (GA_IsDemo() ? " DEMO" : " REAL") + "\n";
   s += "equity="           + DoubleToString(eq, 2) + "\n";
   s += "virtual_equity="   + DoubleToString(GA_SizingEquity(g_state, eq), 2) + "\n";
   s += "day_loss="         + DoubleToString(GA_DayLoss(g_state, eq), 2) + "\n";
   s += "day_limit="        + DoubleToString(GA_DailyLossLimit(g_cfg, g_state), 2) + "\n";
   s += "entries_today="    + (string)g_state.entries_today + "/" + (string)g_cfg.max_entries_per_day + "\n";
   s += "lock="             + GA_LockName(g_state.lock) + "\n";
   s += "open_positions="   + (string)g_scan.ours + "\n";
   s += "unprotected="      + (string)(g_scan.unprotected_ours + g_scan.unprotected_other) + "\n";
   s += "entry_allowed="    + (can ? "yes" : "no: " + why) + "\n";
   s += "spread="           + DoubleToString(g.spread, 2) + "\n";
   s += "ping_ms="          + (string)(TerminalInfoInteger(TERMINAL_PING_LAST) / 1000) + "\n";
   s += "updated_server="   + TimeToString(TimeTradeServer(), TIME_DATE | TIME_SECONDS) + "\n";
   int h = FileOpen(GA_FOLDER + "\\status_" + (string)g_state.login + ".txt",
                    FILE_WRITE | FILE_TXT | FILE_ANSI | GA_FileFlags(g_tester));
   if(h != INVALID_HANDLE) { FileWriteString(h, s); FileClose(h); }

   Comment("GOLD AI ", GA_VERSION, "   MODE: ", GA_ModeName(g_cfg.mode), (GA_IsDemo() ? "   [DEMO]" : "   [REAL MONEY]"),
           "\nStrategy: NONE (M1 risk engine only)",
           "\nLock: ", GA_LockName(g_state.lock), (g_state.lock != GA_LOCK_NONE ? " (" + g_state.lock_reason + ")" : ""),
           "\nToday: -$", DoubleToString(MathMax(0.0, GA_DayLoss(g_state, eq)), 2), " of $", DoubleToString(GA_DailyLossLimit(g_cfg, g_state), 2),
           "   Entries ", g_state.entries_today, "/", g_cfg.max_entries_per_day,
           (GA_VirtualOn(g_state) ? "\nVirtual equity: $" + DoubleToString(GA_SizingEquity(g_state, eq), 2) : ""),
           "\nNew entry allowed: ", (can ? "yes" : "no - " + why));
  }

//--- Demo-only acceptance test: proves sizing, stop placement, stop verification and journaling.
void RunSelfTest()
  {
   if(g_selftest_stage == 1)
     {
      double stop = InpSelfTestStopUSD;
      GAGateInput g; BuildGate(g, stop);
      string why = "";
      if(!GA_EntryAllowed(g_cfg, g_state, g, why))
        {
         g_journal.Log("selftest_rejected", GA_Kv("reason", why));
         Alert2("Self-test REJECTED by risk gate: " + why);
         g_selftest_stage = 3;
         return;
        }
      double eq = Equity();
      GASizingInput in;
      in.risk_budget        = GA_RiskBudget(GA_SizingEquity(g_state, eq), g_cfg.risk_pct, g_cfg.max_risk_usd,
                                            GA_RemainingDailyRoom(g_cfg, g_state, eq));
      in.stop_distance      = stop;
      in.tick_size          = g_spec.tick_size;
      in.tick_value_loss    = g_spec.tick_value_loss;
      in.vol_min            = g_spec.vol_min;
      in.vol_step           = g_spec.vol_step;
      in.vol_max            = g_spec.vol_max;
      in.commission_per_lot = InpCommissionPerLot;
      in.slippage_price     = g_cfg.max_slippage_usd;
      GASizingResult r;
      GA_CalcVolume(in, r);
      g_journal.Log("selftest_sizing", GA_Kv("result", GA_SizeResultName(r.code)) + "," + GA_KvNum("budget", in.risk_budget, 2) + "," +
                    GA_KvNum("loss_per_lot", r.loss_per_lot, 2) + "," + GA_KvNum("volume", r.volume, 2) + "," +
                    GA_KvNum("risk_at_volume", r.risk_at_volume, 2));
      if(r.code != GA_SIZE_OK)
        {
         Alert2("Self-test skipped: " + GA_SizeResultName(r.code) + " (this is the skip rule working)");
         g_selftest_stage = 3;
         return;
        }
      MqlTick t; SymbolInfoTick(GA_ALLOWED_SYMBOL, t);
      GAFill f; string err = "";
      bool ok = g_exec.OpenProtected(true, r.volume, t.ask - stop, t.ask + stop, "GOLD_AI selftest", f, err);
      if(f.position > 0 || ok) { GA_RecordEntry(g_state); SaveState(); }
      g_journal.Log(ok ? "selftest_open_verified" : "selftest_open_failed",
                    GA_Kv("err", err) + "," + GA_KvInt("position", (long)f.position) + "," + GA_KvNum("price", f.price, 2) + "," +
                    GA_KvNum("sl", f.sl, 2) + "," + GA_KvNum("tp", f.tp, 2) + "," + GA_KvNum("volume", f.volume, 2));
      Alert2(ok ? "Self-test: BUY " + DoubleToString(f.volume, 2) + " @" + DoubleToString(f.price, 2) + " SL " + DoubleToString(f.sl, 2) + " VERIFIED"
                : "Self-test FAILED: " + err);
      if(ok) { g_selftest_pos = f.position; g_selftest_opened = TimeLocal(); g_selftest_stage = 2; }
      else   g_selftest_stage = 3;
     }
   else if(g_selftest_stage == 2 && TimeLocal() - g_selftest_opened >= 10)
     {
      CTrade tr; tr.SetExpertMagicNumber(GA_MAGIC);
      bool closed = !PositionSelectByTicket(g_selftest_pos) || tr.PositionClose(g_selftest_pos);
      g_journal.Log(closed ? "selftest_pass" : "selftest_close_failed", GA_KvInt("position", (long)g_selftest_pos));
      Alert2(closed ? "Self-test PASS: opened, stop verified, closed." : "Self-test: CLOSE FAILED, check terminal");
      g_selftest_stage = 3;
     }
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_tester = (bool)MQLInfoInteger(MQL_TESTER);
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   g_journal.Init(login, g_tester);
   g_notify.Init(g_tester);

   //--- Config
   GA_FillDefaults(InpMode, g_cfg);
   g_cfg.virtual_start    = InpVirtualStart;
   g_cfg.virtual_blown_at = InpVirtualBlownAt;
   g_cfg.daily_loss_usd   = InpDailyLossUSD;
   g_cfg.daily_loss_pct   = InpDailyLossPct;
   if(InpRiskPct > 0)    g_cfg.risk_pct            = InpRiskPct;
   if(InpMaxRiskUSD > 0) g_cfg.max_risk_usd        = InpMaxRiskUSD;
   if(InpMaxEntries > 0) g_cfg.max_entries_per_day = InpMaxEntries;
   string err = "";
   if(!GA_ValidateConfig(g_cfg, err))
     {
      g_journal.Log("config_rejected", GA_Kv("reason", err));
      Alert("GOLD AI: config rejected - ", err);
      return INIT_PARAMETERS_INCORRECT;
     }

   //--- Account guard (fatal) and symbol guard
   if(!g_tester && !GA_CheckAccount(InpExpectedLogin, InpExpectedServer, InpAllowReal, InpLivePhrase, err))
     {
      g_journal.Log("account_rejected", GA_Kv("reason", err));
      Alert("GOLD AI: ", err);
      return INIT_FAILED;
     }
   if(!GA_IsDemo() && g_cfg.virtual_start > 0.0)
     {
      Alert("GOLD AI: virtual balance is for demo only. Set InpVirtualStart = 0 on a real account.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(_Symbol != GA_ALLOWED_SYMBOL)
     {
      Alert("GOLD AI: attach to an ", GA_ALLOWED_SYMBOL, " chart only (this is ", _Symbol, ")");
      return INIT_FAILED;
     }
   if(!GA_CheckSymbol(_Symbol, g_spec, err))
      g_journal.Log("guards_failed", GA_Kv("reason", err));   // keep running, blocked, so the watchdog still works
   else
      g_guards_ok = true;
   g_guard_err = err;
   g_exec.Init(g_spec, g_cfg.max_slippage_usd);

   //--- State
   int today = GA_DayKey(TimeTradeServer());
   double eq = Equity();
   int load = GA_StateLoad(login, g_tester, g_state, err);
   if(load == GA_LOAD_FIRST_RUN)
     {
      GA_StateInit(g_state, login, today, eq, g_cfg.virtual_start);
      g_state.last_flow_deal = LatestFlowDeal(0);
      g_journal.Log("state_first_run", GA_KvNum("equity", eq, 2) + "," + GA_KvNum("virtual_start", g_cfg.virtual_start, 2));
     }
   else if(load == GA_LOAD_CORRUPT)
     {
      GA_StateInit(g_state, login, today, eq, g_cfg.virtual_start);
      g_state.last_flow_deal = LatestFlowDeal(0);
      g_state.entries_today = g_cfg.max_entries_per_day;
      GA_SetLock(g_state, GA_LOCK_STATE_CORRUPT, today, err);
      g_journal.Log("state_corrupt", GA_Kv("reason", err));
      Alert2("State file problem (" + err + "). Locked until next trading day.");
     }
   else
      g_journal.Log("state_loaded", GA_KvInt("day", g_state.day_key) + "," + GA_KvNum("baseline", g_state.baseline_equity, 2) + "," +
                    GA_Kv("lock", GA_LockName(g_state.lock)) + "," + GA_KvInt("entries", g_state.entries_today));

   if(MathAbs(g_state.virtual_start - g_cfg.virtual_start) > 1e-9)
     {
      g_journal.Log("virtual_reanchored", GA_KvNum("old", g_state.virtual_start, 2) + "," + GA_KvNum("new", g_cfg.virtual_start, 2));
      g_state.virtual_start = g_cfg.virtual_start;
      g_state.anchor_equity = eq;
     }

   GA_ApplyNewDay(g_state, today, eq);
   ApplyNewFlows();

   //--- Manual controls
   if(InpEmergencyStop)
      TriggerLock(GA_LOCK_EMERGENCY, "manual emergency stop");
   else if(InpClearManualLock && (g_state.lock == GA_LOCK_EMERGENCY || g_state.lock == GA_LOCK_VIRTUAL_BLOWN))
     {
      g_journal.Log("manual_lock_cleared", GA_Kv("lock", GA_LockName(g_state.lock)));
      g_state.lock = GA_LOCK_NONE; g_state.lock_day = 0; g_state.lock_reason = "";
      if(GA_VirtualOn(g_state)) { g_state.anchor_equity = eq; }   // a cleared blown test restarts at the virtual start
      Alert2("Manual lock cleared. Set InpClearManualLock back to false.");
     }

   //--- Reconcile with broker positions
   g_exec.Scan(g_scan);
   g_journal.Log("reconciled", GA_KvInt("our_positions", g_scan.ours) + "," + GA_KvInt("closed_unprotected", g_scan.closed_by_watchdog) + "," +
                 GA_KvInt("unprotected_other", g_scan.unprotected_other));

   SaveState();
   CheckRiskNow();

   if(InpSelfTestTrade)
     {
      if(GA_IsDemo() && !g_tester) g_selftest_stage = 1;
      else g_journal.Log("selftest_refused", GA_Kv("reason", "self-test runs on a live demo account only"));
     }

   EventSetTimer(1);
   g_journal.Log("started", GA_Kv("mode", GA_ModeName(g_cfg.mode)) + "," + GA_Kv("account", GA_IsDemo() ? "DEMO" : "REAL") + "," +
                 GA_KvNum("risk_pct", g_cfg.risk_pct, 2) + "," + GA_KvNum("max_risk_usd", g_cfg.max_risk_usd, 2) + "," +
                 GA_KvNum("daily_limit", GA_DailyLossLimit(g_cfg, g_state), 2) + "," + GA_KvInt("max_entries", g_cfg.max_entries_per_day) + "," +
                 GA_KvNum("tick_size", g_spec.tick_size, 5) + "," + GA_KvNum("tick_value_loss", g_spec.tick_value_loss, 5) + "," +
                 GA_KvNum("contract", g_spec.contract_size, 2) + "," + GA_KvNum("vol_min", g_spec.vol_min, 2) + "," +
                 GA_KvNum("vol_step", g_spec.vol_step, 2) + "," + GA_KvInt("stops_level_pts", g_spec.stops_level_pts));
   Alert2("Started " + GA_ModeName(g_cfg.mode) + (GA_IsDemo() ? " DEMO" : " REAL") + ", lock " + GA_LockName(g_state.lock));
   WriteStatus();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   SaveState();
   g_journal.Log("stopped", GA_KvInt("reason", reason));
   Comment("");
  }

void OnTick()
  {
   CheckRiskNow();
  }

void OnTimer()
  {
   g_timer_ticks++;
   CheckRiskNow();
   if(g_timer_ticks % 5 == 0)
     {
      g_exec.Scan(g_scan);
      if(g_scan.closed_by_watchdog > 0)
        {
         g_journal.Log("watchdog_closed_unprotected", GA_KvInt("count", g_scan.closed_by_watchdog));
         Alert2("Closed " + (string)g_scan.closed_by_watchdog + " GOLD AI trade(s) with no stop-loss");
        }
      if(g_scan.unprotected_ours > 0)  Alert2("GOLD AI trade WITHOUT stop and close failed - CHECK NOW");
      if(g_state.lock != GA_LOCK_NONE && g_scan.ours > 0)   // locked but something is still open: keep trying
        {
         int failed = g_exec.CloseAllOurs();
         g_journal.Log("lock_close_retry", GA_KvInt("failed", failed));
         if(failed > 0) Alert2("LOCKED but " + (string)failed + " trade(s) will not close - CHECK NOW");
        }
      if(g_scan.unprotected_other > 0 && g_timer_ticks % 300 == 0)
         Alert2("A manual XAUUSD trade has no stop-loss. New GOLD AI entries are blocked.");
      WriteStatus();
     }
   if(g_timer_ticks % 30 == 0) { ApplyNewFlows(); CheckGuards(); }
   if(g_selftest_stage == 1 || g_selftest_stage == 2) RunSelfTest();
   g_notify.Flush();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != GA_ALLOWED_SYMBOL) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != GA_MAGIC) return;
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT) return;

   ulong pos_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(PositionSelectByTicket(pos_id)) return;   // partially closed; count when fully closed

   double net = 0.0;
   if(HistorySelectByPosition(pos_id))
     {
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         net += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
        }
     }
   GA_RecordClosedTrade(g_state, g_cfg, net, TimeTradeServer());
   SaveState();
   g_journal.Log("closed", GA_KvInt("position", (long)pos_id) + "," + GA_KvNum("net", net, 2) + "," +
                 GA_KvInt("loss_streak", g_state.consecutive_losses));
   Alert2("Closed " + (net >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(net), 2) +
          " | today -$" + DoubleToString(MathMax(0.0, GA_DayLoss(g_state, Equity())), 2) + " of $" +
          DoubleToString(GA_DailyLossLimit(g_cfg, g_state), 2));
   CheckRiskNow();
  }
//+------------------------------------------------------------------+
