//+------------------------------------------------------------------+
//| GOLD AI - position sizing (pure, unit-tested)                     |
//|                                                                   |
//| stop_distance is |actual entry price - SL| in price units, where  |
//| the entry price is the ask for a buy and the bid for a sell, so   |
//| the spread at entry is already inside it.                         |
//| Volume is ALWAYS rounded DOWN. If the minimum lot would risk more |
//| than the budget, the trade is skipped (never rounded up).         |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_SIZING_MQH
#define GOLD_AI_SIZING_MQH

#include "Types.mqh"

struct GASizingInput
  {
   double risk_budget;          // $ allowed to lose on this trade
   double stop_distance;        // price units
   double tick_size;            // SYMBOL_TRADE_TICK_SIZE
   double tick_value_loss;      // SYMBOL_TRADE_TICK_VALUE_LOSS, account currency per tick per 1 lot
   double vol_min;
   double vol_step;
   double vol_max;
   double commission_per_lot;   // round-trip, account currency, >= 0
   double slippage_price;       // expected adverse slippage at the stop, price units
  };

struct GASizingResult
  {
   int    code;                 // ENUM_GA_SIZE_RESULT
   double volume;               // 0 unless code == GA_SIZE_OK
   double loss_per_lot;         // $ lost per 1.0 lot if the stop is hit (incl. costs)
   double risk_at_volume;       // $ lost at `volume` if the stop is hit
  };

int GA_VolumeDigits(const double step)
  {
   if(step <= 0.0) return 2;
   int d = 0;
   double s = step;
   while(d < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; d++; }
   return d;
  }

// Risk budget = min(pct of sizing equity, absolute cap, remaining daily room).
double GA_RiskBudget(const double sizing_equity, const double risk_pct,
                     const double max_risk_usd, const double remaining_daily_room)
  {
   if(sizing_equity <= 0.0 || risk_pct <= 0.0) return 0.0;
   double b = sizing_equity * risk_pct / 100.0;
   if(max_risk_usd > 0.0)  b = MathMin(b, max_risk_usd);
   b = MathMin(b, remaining_daily_room);
   return MathMax(0.0, b);
  }

void GA_CalcVolume(const GASizingInput &in, GASizingResult &out)
  {
   out.code = GA_SIZE_BAD_INPUT;
   out.volume = 0.0;
   out.loss_per_lot = 0.0;
   out.risk_at_volume = 0.0;

   if(in.stop_distance <= 0.0 || in.tick_size <= 0.0 || in.tick_value_loss <= 0.0 ||
      in.vol_min <= 0.0 || in.vol_step <= 0.0 || in.vol_max < in.vol_min ||
      in.commission_per_lot < 0.0 || in.slippage_price < 0.0)
      return;

   out.loss_per_lot = ((in.stop_distance + in.slippage_price) / in.tick_size) * in.tick_value_loss
                      + in.commission_per_lot;
   if(out.loss_per_lot <= 0.0) return;

   if(in.risk_budget <= 0.0) { out.code = GA_SIZE_NO_BUDGET; return; }

   double raw   = in.risk_budget / out.loss_per_lot;
   // Tiny epsilon only absorbs floating error (0.99999999 steps -> 1 step); it never adds a step.
   double steps = MathFloor(raw / in.vol_step + 1e-7);
   double vol   = steps * in.vol_step;
   if(vol > in.vol_max) vol = MathFloor(in.vol_max / in.vol_step + 1e-7) * in.vol_step;
   vol = NormalizeDouble(vol, GA_VolumeDigits(in.vol_step));

   // Belt and braces: if rounding still left us over budget, drop one step.
   while(vol > 0.0 && vol * out.loss_per_lot > in.risk_budget * (1.0 + 1e-9))
      vol = NormalizeDouble(vol - in.vol_step, GA_VolumeDigits(in.vol_step));

   if(vol < in.vol_min - 1e-12)
     {
      out.code = GA_SIZE_MIN_LOT_EXCEEDS_RISK;
      out.risk_at_volume = in.vol_min * out.loss_per_lot;  // what the min lot WOULD have risked (for the log)
      return;
     }

   out.code = GA_SIZE_OK;
   out.volume = vol;
   out.risk_at_volume = vol * out.loss_per_lot;
  }

string GA_SizeResultName(const int code)
  {
   switch(code)
     {
      case GA_SIZE_OK:                   return "OK";
      case GA_SIZE_BAD_INPUT:            return "BAD_INPUT";
      case GA_SIZE_NO_BUDGET:            return "NO_BUDGET";
      case GA_SIZE_MIN_LOT_EXCEEDS_RISK: return "MIN_LOT_EXCEEDS_RISK";
     }
   return "UNKNOWN";
  }

#endif
