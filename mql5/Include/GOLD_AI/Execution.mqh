//+------------------------------------------------------------------+
//| GOLD AI - order execution with verified stop-loss + watchdog      |
//|                                                                   |
//| Every order is sent WITH its stop. After the fill the position is |
//| re-read. If the stop is missing or wrong it is re-sent ONCE, and |
//| if it still is not right the position is closed.                  |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_EXECUTION_MQH
#define GOLD_AI_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include "Types.mqh"
#include "Guards.mqh"

struct GAFill
  {
   ulong  position;
   double price;
   double volume;
   double sl;
   double tp;
  };

struct GAPositionScan
  {
   int ours;                 // GOLD AI positions on XAUUSD
   int unprotected_ours;     // ours without a valid stop (after the watchdog acted)
   int unprotected_other;    // manual/other-EA XAUUSD positions without a stop
   int closed_by_watchdog;
  };

class GAExecution
  {
private:
   CTrade       m_trade;
   GASymbolSpec m_spec;

   double NormPrice(const double p) const
     {
      return NormalizeDouble(MathRound(p / m_spec.tick_size) * m_spec.tick_size, m_spec.digits);
     }

   bool StopMatches(const double actual, const double wanted) const
     {
      return actual > 0.0 && MathAbs(actual - wanted) <= m_spec.tick_size * 1.5;
     }

   bool SelectPositionWithRetry(const ulong position_id)
     {
      for(int i = 0; i < 10; i++)
        {
         if(PositionSelectByTicket(position_id)) return true;
         Sleep(100);
        }
      return false;
     }

public:
   void Init(const GASymbolSpec &spec, const double max_slippage_usd)
     {
      m_spec = spec;
      m_trade.SetExpertMagicNumber(GA_MAGIC);
      m_trade.SetDeviationInPoints((ulong)MathMax(1.0, MathRound(max_slippage_usd / spec.point)));
      m_trade.SetTypeFillingBySymbol(GA_ALLOWED_SYMBOL);
      m_trade.SetAsyncMode(false);
      m_trade.LogLevel(LOG_LEVEL_ERRORS);
     }

   void UpdateSpec(const GASymbolSpec &spec) { m_spec = spec; }

   // Opens a market position with SL (required) and TP (optional, 0 = none), then verifies the SL.
   bool OpenProtected(const bool is_buy, const double volume, const double sl_in, const double tp_in,
                      const string comment, GAFill &fill, string &err)
     {
      err = "";
      fill.position = 0; fill.price = 0; fill.volume = 0; fill.sl = 0; fill.tp = 0;
      MqlTick t;
      if(!SymbolInfoTick(GA_ALLOWED_SYMBOL, t)) { err = "no tick"; return false; }
      double price = is_buy ? t.ask : t.bid;
      double sl = NormPrice(sl_in);
      double tp = tp_in > 0.0 ? NormPrice(tp_in) : 0.0;
      double min_gap = m_spec.stops_level_pts * m_spec.point;

      if(sl <= 0.0)                                   { err = "stop-loss is required"; return false; }
      if(is_buy  && sl >= price - min_gap)            { err = "buy stop not below price by the broker stop level"; return false; }
      if(!is_buy && sl <= price + min_gap)            { err = "sell stop not above price by the broker stop level"; return false; }
      if(tp > 0.0 && is_buy  && tp <= price + min_gap) { err = "buy target too close"; return false; }
      if(tp > 0.0 && !is_buy && tp >= price - min_gap) { err = "sell target too close"; return false; }

      double margin = 0.0;
      if(!OrderCalcMargin(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, GA_ALLOWED_SYMBOL, volume, price, margin))
        { err = "margin calculation failed"; return false; }
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin * 1.5)
        { err = "not enough free margin"; return false; }

      bool sent = is_buy ? m_trade.Buy(volume, GA_ALLOWED_SYMBOL, price, sl, tp, comment)
                         : m_trade.Sell(volume, GA_ALLOWED_SYMBOL, price, sl, tp, comment);
      uint rc = m_trade.ResultRetcode();
      if(!sent || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
        { err = "order rejected: " + (string)rc + " " + m_trade.ResultRetcodeDescription(); return false; }

      // Locate the resulting position. Hedging accounts: position ticket == position id.
      ulong deal = m_trade.ResultDeal();
      ulong position_id = 0;
      if(deal > 0 && HistoryDealSelect(deal))
         position_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      bool found = position_id > 0 && SelectPositionWithRetry(position_id);
      if(!found && PositionSelect(GA_ALLOWED_SYMBOL) && PositionGetInteger(POSITION_MAGIC) == GA_MAGIC)
        { found = true; position_id = (ulong)PositionGetInteger(POSITION_TICKET); }
      if(!found) { err = "filled but position not found; watchdog will verify"; return false; }

      fill.position = position_id;
      fill.price    = PositionGetDouble(POSITION_PRICE_OPEN);
      fill.volume   = PositionGetDouble(POSITION_VOLUME);
      fill.sl       = PositionGetDouble(POSITION_SL);
      fill.tp       = PositionGetDouble(POSITION_TP);

      if(StopMatches(fill.sl, sl)) return true;

      // One bounded retry to set the stop.
      if(m_trade.PositionModify(position_id, sl, tp) && SelectPositionWithRetry(position_id))
        {
         fill.sl = PositionGetDouble(POSITION_SL);
         if(StopMatches(fill.sl, sl)) return true;
        }

      // Still unprotected: close it.
      bool closed = m_trade.PositionClose(position_id);
      err = closed ? "stop could not be verified; position closed"
                   : "stop could not be verified AND close failed";
      return false;
     }

   // Closes every GOLD AI position on XAUUSD. Returns how many failed to close.
   int CloseAllOurs()
     {
      int failed = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != GA_ALLOWED_SYMBOL) continue;
         if(PositionGetInteger(POSITION_MAGIC) != GA_MAGIC) continue;
         if(!m_trade.PositionClose(ticket)) failed++;
        }
      return failed;
     }

   // Watchdog: closes OUR positions without a stop; reports others (never touches manual trades).
   void Scan(GAPositionScan &r)
     {
      r.ours = 0; r.unprotected_ours = 0; r.unprotected_other = 0; r.closed_by_watchdog = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != GA_ALLOWED_SYMBOL) continue;
         bool ours = PositionGetInteger(POSITION_MAGIC) == GA_MAGIC;
         bool protected_ok = PositionGetDouble(POSITION_SL) > 0.0;
         if(ours) r.ours++;
         if(protected_ok) continue;
         if(!ours) { r.unprotected_other++; continue; }
         if(m_trade.PositionClose(ticket)) { r.closed_by_watchdog++; r.ours--; }
         else                              r.unprotected_ours++;
        }
     }
  };

#endif
