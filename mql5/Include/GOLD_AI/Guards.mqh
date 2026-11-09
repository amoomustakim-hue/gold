//+------------------------------------------------------------------+
//| GOLD AI - symbol, account and terminal guards                     |
//| Any failure means: no new trades.                                 |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_GUARDS_MQH
#define GOLD_AI_GUARDS_MQH

#include "Types.mqh"

#define GA_LIVE_PHRASE "I ACCEPT REAL MONEY RISK"

struct GASymbolSpec
  {
   double point;
   int    digits;
   double tick_size;
   double tick_value_loss;
   double contract_size;
   double vol_min;
   double vol_step;
   double vol_max;
   int    stops_level_pts;
   int    freeze_level_pts;
  };

// Exactly XAUUSD, gold vs US dollar, fully tradeable, sane contract properties.
bool GA_CheckSymbol(const string chart_symbol, GASymbolSpec &spec, string &err)
  {
   err = "";
   if(chart_symbol != GA_ALLOWED_SYMBOL)
     { err = "chart symbol '" + chart_symbol + "' is not exactly " + GA_ALLOWED_SYMBOL; return false; }
   if(!SymbolSelect(GA_ALLOWED_SYMBOL, true))
     { err = GA_ALLOWED_SYMBOL + " not available in Market Watch"; return false; }
   if(SymbolInfoString(GA_ALLOWED_SYMBOL, SYMBOL_CURRENCY_BASE) != "XAU" ||
      SymbolInfoString(GA_ALLOWED_SYMBOL, SYMBOL_CURRENCY_PROFIT) != "USD")
     { err = "symbol is not XAU priced in USD"; return false; }
   if(SymbolInfoInteger(GA_ALLOWED_SYMBOL, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
     { err = "symbol trading is not fully enabled"; return false; }

   spec.point            = SymbolInfoDouble(GA_ALLOWED_SYMBOL, SYMBOL_POINT);
   spec.digits           = (int)SymbolInfoInteger(GA_ALLOWED_SYMBOL, SYMBOL_DIGITS);
   spec.tick_size        = SymbolInfoDouble(GA_ALLOWED_SYMBOL, SYMBOL_TRADE_TICK_SIZE);
   spec.tick_value_loss  = SymbolInfoDouble(GA_ALLOWED_SYMBOL, SYMBOL_TRADE_TICK_VALUE_LOSS);
   spec.contract_size    = SymbolInfoDouble(GA_ALLOWED_SYMBOL, SYMBOL_TRADE_CONTRACT_SIZE);
   spec.vol_min          = SymbolInfoDouble(GA_ALLOWED_SYMBOL, SYMBOL_VOLUME_MIN);
   spec.vol_step         = SymbolInfoDouble(GA_ALLOWED_SYMBOL, SYMBOL_VOLUME_STEP);
   spec.vol_max          = SymbolInfoDouble(GA_ALLOWED_SYMBOL, SYMBOL_VOLUME_MAX);
   spec.stops_level_pts  = (int)SymbolInfoInteger(GA_ALLOWED_SYMBOL, SYMBOL_TRADE_STOPS_LEVEL);
   spec.freeze_level_pts = (int)SymbolInfoInteger(GA_ALLOWED_SYMBOL, SYMBOL_TRADE_FREEZE_LEVEL);

   if(spec.point <= 0 || spec.tick_size <= 0 || spec.tick_value_loss <= 0 || spec.contract_size <= 0 ||
      spec.vol_min <= 0 || spec.vol_step <= 0 || spec.vol_max < spec.vol_min)
     { err = "symbol specification incomplete (tick/volume/contract values)"; return false; }
   return true;
  }

// Must be the configured account; real money needs two deliberate settings.
bool GA_CheckAccount(const long expected_login, const string expected_server_part,
                     const bool allow_real, const string live_phrase, string &err)
  {
   err = "";
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   if(expected_login <= 0)
     { err = "set InpExpectedLogin to your Exness account number"; return false; }
   if(login != expected_login)
     { err = "account " + (string)login + " is not the configured account " + (string)expected_login; return false; }
   if(StringLen(expected_server_part) > 0 && StringFind(AccountInfoString(ACCOUNT_SERVER), expected_server_part) < 0)
     { err = "server '" + AccountInfoString(ACCOUNT_SERVER) + "' does not match '" + expected_server_part + "'"; return false; }
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD")
     { err = "account currency must be USD (limits are in dollars)"; return false; }

   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode == ACCOUNT_TRADE_MODE_REAL)
     {
      if(!allow_real || live_phrase != GA_LIVE_PHRASE)
        { err = "REAL account detected but live trading is not explicitly enabled"; return false; }
     }
   else if(mode != ACCOUNT_TRADE_MODE_DEMO)
     { err = "unsupported account type (contest?)"; return false; }
   else if(allow_real)
     { err = "InpAllowReal is on but this is a demo account: config mismatch"; return false; }
   return true;
  }

bool GA_IsDemo()
  {
   return (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO;
  }

bool GA_TradeAllowed()
  {
   return TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
          AccountInfoInteger(ACCOUNT_TRADE_EXPERT) && AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
  }

#endif
