//+------------------------------------------------------------------+
//| GOLD AI - persistent risk state + text codec with checksum (pure) |
//|                                                                   |
//| Format: one key=value per line, final line checksum=XXXXXXXX.     |
//| The checksum covers every preceding line plus the account login,  |
//| so a hand-edited file or a file from another account is rejected. |
//| It detects corruption and casual edits. It is not cryptographic.  |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_STATECODEC_MQH
#define GOLD_AI_STATECODEC_MQH

#include "Types.mqh"

struct GAState
  {
   int      schema;
   long     login;
   int      day_key;            // trading day, yyyymmdd in broker server time
   double   baseline_equity;    // real equity at day start, adjusted for deposits/withdrawals
   double   anchor_equity;      // real equity when the virtual account started, flow-adjusted
   double   virtual_start;      // 0 = virtual balance off
   int      entries_today;
   int      consecutive_losses;
   datetime last_loss_time;
   datetime pause_until;
   bool     pause_rest_of_day;
   int      lock;               // ENUM_GA_LOCK
   int      lock_day;
   string   lock_reason;
   ulong    last_flow_deal;     // highest balance/credit deal ticket already applied
   datetime updated;
  };

void GA_StateInit(GAState &s, const long login, const int day_key, const double equity, const double virtual_start)
  {
   s.schema             = GA_STATE_SCHEMA;
   s.login              = login;
   s.day_key            = day_key;
   s.baseline_equity    = equity;
   s.anchor_equity      = equity;
   s.virtual_start      = virtual_start;
   s.entries_today      = 0;
   s.consecutive_losses = 0;
   s.last_loss_time     = 0;
   s.pause_until        = 0;
   s.pause_rest_of_day  = false;
   s.lock               = GA_LOCK_NONE;
   s.lock_day           = 0;
   s.lock_reason        = "";
   s.last_flow_deal     = 0;
   s.updated            = 0;
  }

uint GA_Fnv1a(const string text)
  {
   uint h = 2166136261;
   int n = StringLen(text);
   for(int i = 0; i < n; i++)
     {
      h ^= (uint)StringGetCharacter(text, i);
      h *= 16777619;
     }
   return h;
  }

string GA_Checksum(const string body, const long login)
  {
   return StringFormat("%08X", GA_Fnv1a(body + "|GOLD_AI|" + (string)login));
  }

string GA_SanitizeValue(const string v)
  {
   string r = v;
   StringReplace(r, "\r", " ");
   StringReplace(r, "\n", " ");
   return r;
  }

string GA_StateSerialize(const GAState &s)
  {
   string b = "";
   b += "schema="             + (string)s.schema + "\n";
   b += "login="              + (string)s.login + "\n";
   b += "day_key="            + (string)s.day_key + "\n";
   b += "baseline_equity="    + DoubleToString(s.baseline_equity, 2) + "\n";
   b += "anchor_equity="      + DoubleToString(s.anchor_equity, 2) + "\n";
   b += "virtual_start="      + DoubleToString(s.virtual_start, 2) + "\n";
   b += "entries_today="      + (string)s.entries_today + "\n";
   b += "consecutive_losses=" + (string)s.consecutive_losses + "\n";
   b += "last_loss_time="     + (string)(long)s.last_loss_time + "\n";
   b += "pause_until="        + (string)(long)s.pause_until + "\n";
   b += "pause_rest_of_day="  + (s.pause_rest_of_day ? "1" : "0") + "\n";
   b += "lock="               + (string)s.lock + "\n";
   b += "lock_day="           + (string)s.lock_day + "\n";
   b += "lock_reason="        + GA_SanitizeValue(s.lock_reason) + "\n";
   b += "last_flow_deal="     + (string)s.last_flow_deal + "\n";
   b += "updated="            + (string)(long)s.updated + "\n";
   return b + "checksum=" + GA_Checksum(b, s.login) + "\n";
  }

// Parses text produced by GA_StateSerialize. Fails on a missing key, a bad checksum,
// a schema mismatch or a different account login.
bool GA_StateParse(const string text, const long expected_login, GAState &s, string &err)
  {
   err = "";
   string t = text;
   StringReplace(t, "\r", "");
   string lines[];
   int n = StringSplit(t, '\n', lines);
   if(n <= 0) { err = "empty"; return false; }

   string body = "";
   string checksum = "";
   string keys[]; string vals[];
   int kv = 0;
   ArrayResize(keys, n); ArrayResize(vals, n);
   for(int i = 0; i < n; i++)
     {
      string line = lines[i];
      if(StringLen(line) == 0) continue;
      int eq = StringFind(line, "=");
      if(eq <= 0) { err = "malformed line " + (string)(i + 1); return false; }
      string k = StringSubstr(line, 0, eq);
      string v = StringSubstr(line, eq + 1);
      if(k == "checksum") { checksum = v; break; }
      body += line + "\n";
      keys[kv] = k; vals[kv] = v; kv++;
     }
   if(checksum == "") { err = "no checksum"; return false; }

   string required[16] = {"schema","login","day_key","baseline_equity","anchor_equity","virtual_start",
                              "entries_today","consecutive_losses","last_loss_time","pause_until",
                              "pause_rest_of_day","lock","lock_day","lock_reason","last_flow_deal","updated"};
   string got[16];
   for(int r = 0; r < 16; r++)
     {
      bool found = false;
      for(int j = 0; j < kv; j++)
         if(keys[j] == required[r]) { got[r] = vals[j]; found = true; break; }
      if(!found) { err = "missing key " + required[r]; return false; }
     }

   long login = StringToInteger(got[1]);
   if(login != expected_login) { err = "state belongs to another account"; return false; }
   if(GA_Checksum(body, login) != checksum) { err = "checksum mismatch"; return false; }
   if((int)StringToInteger(got[0]) != GA_STATE_SCHEMA) { err = "schema mismatch"; return false; }

   s.schema             = (int)StringToInteger(got[0]);
   s.login              = login;
   s.day_key            = (int)StringToInteger(got[2]);
   s.baseline_equity    = StringToDouble(got[3]);
   s.anchor_equity      = StringToDouble(got[4]);
   s.virtual_start      = StringToDouble(got[5]);
   s.entries_today      = (int)StringToInteger(got[6]);
   s.consecutive_losses = (int)StringToInteger(got[7]);
   s.last_loss_time     = (datetime)StringToInteger(got[8]);
   s.pause_until        = (datetime)StringToInteger(got[9]);
   s.pause_rest_of_day  = (got[10] == "1");
   s.lock               = (int)StringToInteger(got[11]);
   s.lock_day           = (int)StringToInteger(got[12]);
   s.lock_reason        = got[13];
   s.last_flow_deal     = (ulong)StringToInteger(got[14]);
   s.updated            = (datetime)StringToInteger(got[15]);
   return true;
  }

#endif
