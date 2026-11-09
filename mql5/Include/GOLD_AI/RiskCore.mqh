//+------------------------------------------------------------------+
//| GOLD AI - risk rules (pure, unit-tested)                          |
//| Daily loss limit, virtual balance, day rollover, deposits, loss   |
//| streaks, locks and the single entry gate every trade must pass.   |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_RISKCORE_MQH
#define GOLD_AI_RISKCORE_MQH

#include "Types.mqh"
#include "Config.mqh"
#include "StateCodec.mqh"

int GA_DayKey(const datetime server_time)
  {
   MqlDateTime d;
   TimeToStruct(server_time, d);
   return d.year * 10000 + d.mon * 100 + d.day;
  }

bool GA_VirtualOn(const GAState &s) { return s.virtual_start > 0.0; }

// Equity the bot "believes" it has: the real equity, or the virtual $20 account.
double GA_SizingEquity(const GAState &s, const double real_equity)
  {
   if(!GA_VirtualOn(s)) return real_equity;
   return s.virtual_start + (real_equity - s.anchor_equity);
  }

double GA_DayStartSizingEquity(const GAState &s)
  {
   return GA_SizingEquity(s, s.baseline_equity);
  }

// The stricter of the $ limit and the % limit.
double GA_DailyLossLimit(const GAConfig &c, const GAState &s)
  {
   double lim = DBL_MAX;
   if(c.daily_loss_usd > 0.0) lim = c.daily_loss_usd;
   if(c.daily_loss_pct > 0.0) lim = MathMin(lim, GA_DayStartSizingEquity(s) * c.daily_loss_pct / 100.0);
   return lim;
  }

double GA_DayLoss(const GAState &s, const double real_equity)
  {
   return s.baseline_equity - real_equity;   // positive = losing
  }

bool GA_DailyLimitHit(const GAConfig &c, const GAState &s, const double real_equity)
  {
   return GA_DayLoss(s, real_equity) >= GA_DailyLossLimit(c, s) - 1e-9;
  }

double GA_RemainingDailyRoom(const GAConfig &c, const GAState &s, const double real_equity)
  {
   return MathMax(0.0, GA_DailyLossLimit(c, s) - GA_DayLoss(s, real_equity));
  }

bool GA_VirtualBlown(const GAConfig &c, const GAState &s, const double real_equity)
  {
   return GA_VirtualOn(s) && GA_SizingEquity(s, real_equity) <= c.virtual_blown_at + 1e-9;
  }

// Set a lock without ever downgrading a manual-clear lock to an auto-clearing one.
void GA_SetLock(GAState &s, const int lock, const int day_key, const string reason)
  {
   bool current_manual = (s.lock == GA_LOCK_EMERGENCY || s.lock == GA_LOCK_VIRTUAL_BLOWN);
   bool new_manual     = (lock == GA_LOCK_EMERGENCY || lock == GA_LOCK_VIRTUAL_BLOWN);
   if(current_manual && !new_manual) return;
   s.lock = lock;
   s.lock_day = day_key;
   s.lock_reason = reason;
  }

// Call on every tick/timer with the current server day. Returns true if a new day started.
bool GA_ApplyNewDay(GAState &s, const int day_key, const double real_equity)
  {
   if(day_key == s.day_key) return false;
   s.day_key            = day_key;
   s.baseline_equity    = real_equity;
   s.entries_today      = 0;
   s.consecutive_losses = 0;
   s.pause_until        = 0;
   s.pause_rest_of_day  = false;
   if(GA_LockClearsAtNewDay(s.lock))
     {
      s.lock = GA_LOCK_NONE;
      s.lock_day = 0;
      s.lock_reason = "";
     }
   return true;
  }

// Deposit (+) or withdrawal (-): shift baselines so it neither hides a loss nor triggers the lock.
void GA_ApplyExternalFlow(GAState &s, const double amount)
  {
   s.baseline_equity += amount;
   s.anchor_equity   += amount;
  }

void GA_RecordEntry(GAState &s) { s.entries_today++; }

// net_pnl = profit + swap + commission of the closing deal(s).
void GA_RecordClosedTrade(GAState &s, const GAConfig &c, const double net_pnl, const datetime now)
  {
   if(net_pnl < 0.0)
     {
      s.consecutive_losses++;
      s.last_loss_time = now;
      if(s.consecutive_losses >= c.loss_streak_limit)
        {
         if(c.loss_streak_pause_min > 0) s.pause_until = now + c.loss_streak_pause_min * 60;
         else                            s.pause_rest_of_day = true;
        }
     }
   else if(net_pnl > 0.0)
     {
      s.consecutive_losses = 0;
     }
  }

struct GAGateInput
  {
   datetime now;
   bool     guards_ok;              // symbol + account + terminal checks all passed
   bool     connected;
   bool     trade_allowed;          // terminal + EA algo trading enabled
   int      tick_age_sec;
   double   spread;                 // price units
   double   stop_distance;          // price units; 0 = not known yet (skip ratio check)
   int      open_positions;         // GOLD AI positions open now
   int      unprotected_positions;  // ANY XAUUSD position without a stop
   double   real_equity;
  };

// The single gate every new entry passes. Returns false with the reason.
bool GA_EntryAllowed(const GAConfig &c, const GAState &s, const GAGateInput &g, string &reason)
  {
   reason = "";
   if(s.lock != GA_LOCK_NONE)                    { reason = "locked:" + GA_LockName(s.lock); return false; }
   if(!g.guards_ok)                              { reason = "safety guards failed"; return false; }
   if(!g.connected)                              { reason = "terminal disconnected"; return false; }
   if(!g.trade_allowed)                          { reason = "algo trading disabled"; return false; }
   if(g.unprotected_positions > 0)               { reason = "a position has no stop-loss"; return false; }
   if(GA_DailyLimitHit(c, s, g.real_equity))     { reason = "daily loss limit reached"; return false; }
   if(GA_VirtualBlown(c, s, g.real_equity))      { reason = "virtual account blown"; return false; }
   if(s.entries_today >= c.max_entries_per_day)  { reason = "max entries per day reached"; return false; }
   if(g.open_positions >= c.max_open_positions)  { reason = "max open positions reached"; return false; }
   if(s.pause_rest_of_day)                       { reason = "loss streak: paused for the day"; return false; }
   if(s.pause_until > 0 && g.now < s.pause_until) { reason = "loss streak: paused"; return false; }
   if(s.last_loss_time > 0 && g.now < s.last_loss_time + c.cooldown_after_loss_min * 60)
                                                 { reason = "cool-down after loss"; return false; }
   if(g.tick_age_sec > c.stale_tick_sec)         { reason = "stale price data"; return false; }
   if(g.spread <= 0.0)                           { reason = "invalid spread"; return false; }
   if(g.spread > c.max_spread_usd + 1e-9)        { reason = "spread too wide"; return false; }
   if(g.stop_distance > 0.0 && g.spread > g.stop_distance * c.max_spread_frac_of_stop + 1e-9)
                                                 { reason = "spread too large vs stop"; return false; }
   return true;
  }

#endif
