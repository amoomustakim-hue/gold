//+------------------------------------------------------------------+
//| GOLD AI - risk configuration, per-mode defaults and validation   |
//| Pure: no terminal calls, so it is unit-testable.                  |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_CONFIG_MQH
#define GOLD_AI_CONFIG_MQH

#include "Types.mqh"

struct GAConfig
  {
   int      mode;                    // ENUM_GA_MODE
   double   virtual_start;           // 0 = off (use real equity); e.g. 20.0 on a $1,000 demo
   double   virtual_blown_at;        // virtual equity at/below which the test is "blown"
   double   daily_loss_usd;          // absolute daily loss limit ($5); 0 = not used
   double   daily_loss_pct;          // % of day-start (virtual) equity; 0 = not used. Stricter applies.
   double   risk_pct;                // risk per trade, % of sizing equity
   double   max_risk_usd;            // absolute cap per trade
   int      max_entries_per_day;
   int      max_open_positions;
   int      loss_streak_limit;       // consecutive losses that trigger a pause
   int      loss_streak_pause_min;   // 0 = pause for the rest of the trading day
   int      cooldown_after_loss_min;
   double   max_spread_usd;          // absolute spread cap (price units, $ per oz)
   double   max_spread_frac_of_stop; // spread / stop distance cap, e.g. 0.15
   double   max_slippage_usd;        // deviation allowed on fills
   int      stale_tick_sec;
   double   min_free_margin_mult;    // free margin must be >= margin needed * this
  };

void GA_FillDefaults(const int mode, GAConfig &c)
  {
   c.mode                    = mode;
   c.virtual_start           = 0.0;
   c.virtual_blown_at        = 2.0;
   c.daily_loss_usd          = 5.0;    // Amendment A3
   c.daily_loss_pct          = 0.0;
   c.max_slippage_usd        = 0.10;
   c.min_free_margin_mult    = 1.5;
   if(mode == GA_MODE_SCALP)
     {
      c.risk_pct                = 12.0;
      c.max_risk_usd            = 2.50;
      c.max_entries_per_day     = 15;  // Amendment A4 (confirmed)
      c.max_open_positions      = 1;
      c.loss_streak_limit       = 3;
      c.loss_streak_pause_min   = 60;
      c.cooldown_after_loss_min = 5;
      c.max_spread_usd          = 0.35;
      c.max_spread_frac_of_stop = 0.15;
      c.stale_tick_sec          = 10;
     }
   else
     {
      c.risk_pct                = 5.0;
      c.max_risk_usd            = 5.00;
      c.max_entries_per_day     = 3;
      c.max_open_positions      = 2;
      c.loss_streak_limit       = 3;
      c.loss_streak_pause_min   = 0;   // rest of day
      c.cooldown_after_loss_min = 30;
      c.max_spread_usd          = 0.50;
      c.max_spread_frac_of_stop = 0.10;
      c.max_slippage_usd        = 0.20;
      c.stale_tick_sec          = 60;
     }
  }

// Returns false with a reason if any value is outside safe bounds.
bool GA_ValidateConfig(const GAConfig &c, string &err)
  {
   err = "";
   if(c.mode != GA_MODE_NORMAL && c.mode != GA_MODE_SCALP)       { err = "unknown mode"; return false; }
   if(c.daily_loss_usd <= 0.0 && c.daily_loss_pct <= 0.0)        { err = "a daily loss limit is required"; return false; }
   if(c.daily_loss_usd < 0.0 || c.daily_loss_pct < 0.0)          { err = "daily loss limit cannot be negative"; return false; }
   if(c.daily_loss_pct > GA_HARD_MAX_DAILY_LOSS_PCT)             { err = "daily_loss_pct above hard maximum"; return false; }
   if(c.risk_pct <= 0.0 || c.risk_pct > GA_HARD_MAX_RISK_PCT)    { err = "risk_pct outside (0, hard max]"; return false; }
   if(c.max_risk_usd <= 0.0)                                     { err = "max_risk_usd must be > 0"; return false; }
   if(c.max_entries_per_day < 1 || c.max_entries_per_day > GA_HARD_MAX_ENTRIES) { err = "max_entries_per_day outside [1, hard max]"; return false; }
   if(c.max_open_positions < 1 || c.max_open_positions > GA_HARD_MAX_OPEN)      { err = "max_open_positions outside [1, hard max]"; return false; }
   if(c.loss_streak_limit < 1)                                   { err = "loss_streak_limit must be >= 1"; return false; }
   if(c.loss_streak_pause_min < 0 || c.cooldown_after_loss_min < 0) { err = "pause/cooldown cannot be negative"; return false; }
   if(c.max_spread_usd <= 0.0)                                   { err = "max_spread_usd must be > 0"; return false; }
   if(c.max_spread_frac_of_stop <= 0.0 || c.max_spread_frac_of_stop > 1.0) { err = "max_spread_frac_of_stop outside (0, 1]"; return false; }
   if(c.max_slippage_usd < 0.0 || c.max_slippage_usd > GA_HARD_MAX_SLIPPAGE_USD) { err = "max_slippage_usd outside [0, hard max]"; return false; }
   if(c.stale_tick_sec < 1)                                      { err = "stale_tick_sec must be >= 1"; return false; }
   if(c.min_free_margin_mult < 1.0)                              { err = "min_free_margin_mult must be >= 1"; return false; }
   if(c.virtual_start < 0.0)                                     { err = "virtual_start cannot be negative"; return false; }
   if(c.virtual_start > 0.0 && c.virtual_blown_at >= c.virtual_start) { err = "virtual_blown_at must be below virtual_start"; return false; }
   if(c.virtual_blown_at < 0.0)                                  { err = "virtual_blown_at cannot be negative"; return false; }
   return true;
  }

#endif
