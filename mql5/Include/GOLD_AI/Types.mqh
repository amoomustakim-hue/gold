//+------------------------------------------------------------------+
//| GOLD AI - shared types and compiled-in constants                 |
//| Pure definitions only: no terminal calls.                         |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_TYPES_MQH
#define GOLD_AI_TYPES_MQH

#define GA_VERSION          "0.1.0-M1"
#define GA_ALLOWED_SYMBOL   "XAUUSD"     // Owner-confirmed exact symbol. Not an input on purpose.
#define GA_MAGIC            20261109     // Identifies GOLD AI positions
#define GA_STATE_SCHEMA     1
#define GA_FOLDER           "GOLD_AI"

// Hard ceilings compiled into the EA. A config above these refuses to start.
#define GA_HARD_MAX_RISK_PCT        20.0   // % of (virtual) equity per trade
#define GA_HARD_MAX_DAILY_LOSS_PCT  50.0   // % of day-start equity
#define GA_HARD_MAX_ENTRIES         20
#define GA_HARD_MAX_OPEN            3
#define GA_HARD_MAX_SLIPPAGE_USD    1.00

enum ENUM_GA_MODE
  {
   GA_MODE_NORMAL = 0,   // NORMAL: M30 selective (original spec)
   GA_MODE_SCALP  = 1    // SCALP: M1-M5 aggressive scalping
  };

enum ENUM_GA_LOCK
  {
   GA_LOCK_NONE              = 0,
   GA_LOCK_DAILY_LOSS        = 1,  // clears at next trading day
   GA_LOCK_STATE_CORRUPT     = 2,  // clears at next trading day
   GA_LOCK_EMERGENCY         = 3,  // manual clear only
   GA_LOCK_VIRTUAL_BLOWN     = 4   // manual clear only
  };

enum ENUM_GA_SIZE_RESULT
  {
   GA_SIZE_OK                    = 0,
   GA_SIZE_BAD_INPUT             = 1,
   GA_SIZE_NO_BUDGET             = 2,
   GA_SIZE_MIN_LOT_EXCEEDS_RISK  = 3
  };

string GA_ModeName(const int mode)
  {
   return mode == GA_MODE_SCALP ? "SCALP" : "NORMAL";
  }

string GA_LockName(const int lock)
  {
   switch(lock)
     {
      case GA_LOCK_NONE:          return "NONE";
      case GA_LOCK_DAILY_LOSS:    return "DAILY_LOSS";
      case GA_LOCK_STATE_CORRUPT: return "STATE_CORRUPT";
      case GA_LOCK_EMERGENCY:     return "EMERGENCY";
      case GA_LOCK_VIRTUAL_BLOWN: return "VIRTUAL_BLOWN";
     }
   return "UNKNOWN";
  }

// Locks that clear automatically when a new trading day starts.
bool GA_LockClearsAtNewDay(const int lock)
  {
   return lock == GA_LOCK_DAILY_LOSS || lock == GA_LOCK_STATE_CORRUPT;
  }

#endif
