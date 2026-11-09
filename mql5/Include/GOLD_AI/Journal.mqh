//+------------------------------------------------------------------+
//| GOLD AI - event journal (JSON lines) and phone push notifications |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_JOURNAL_MQH
#define GOLD_AI_JOURNAL_MQH

#include "Types.mqh"

string GA_JsonEscape(const string v)
  {
   string r = v;
   StringReplace(r, "\\", "\\\\");
   StringReplace(r, "\"", "\\\"");
   StringReplace(r, "\r", "\\r");
   StringReplace(r, "\n", "\\n");
   StringReplace(r, "\t", "\\t");
   return r;
  }

// Builds "key":"value" pairs. Usage: GA_Kv("reason", r) + "," + GA_KvNum("vol", v, 2)
string GA_Kv(const string k, const string v)              { return "\"" + k + "\":\"" + GA_JsonEscape(v) + "\""; }
string GA_KvNum(const string k, const double v, const int digits) { return "\"" + k + "\":" + DoubleToString(v, digits); }
string GA_KvInt(const string k, const long v)              { return "\"" + k + "\":" + (string)v; }

int GA_FileFlags(const bool tester) { return tester ? 0 : FILE_COMMON; }

//--- Append-only journal: one JSON object per line. Records accepted AND rejected decisions.
class GAJournal
  {
private:
   string m_file;
   bool   m_tester;
public:
   void Init(const long login, const bool tester)
     {
      m_tester = tester;
      FolderCreate(GA_FOLDER, GA_FileFlags(tester));
      m_file = GA_FOLDER + "\\events_" + (string)login + ".jsonl";
     }

   void Log(const string event, const string fields_json)
     {
      string line = "{" + GA_Kv("t_server", TimeToString(TimeTradeServer(), TIME_DATE | TIME_SECONDS)) + ","
                    + GA_Kv("t_utc", TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS)) + ","
                    + GA_Kv("v", GA_VERSION) + ","
                    + GA_Kv("ev", event)
                    + (StringLen(fields_json) > 0 ? "," + fields_json : "") + "}";
      Print("[GOLD_AI] ", line);
      int h = FileOpen(m_file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | GA_FileFlags(m_tester));
      if(h == INVALID_HANDLE) { Print("[GOLD_AI] journal open failed, err=", GetLastError()); return; }
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, line + "\r\n");
      FileClose(h);
     }
  };

//--- Push notifications to the MT5 phone app (MetaQuotes ID).
// Platform limits: <=255 chars, <=2/s and <=10/min. Exceeding them can disable
// the function, so messages are queued, merged and sent at most once every 7 s.
class GANotifier
  {
private:
   string   m_queue[];
   datetime m_last_sent;
   bool     m_enabled;
public:
   void Init(const bool tester)
     {
      ArrayResize(m_queue, 0);
      m_last_sent = 0;
      m_enabled = !tester;
     }

   void Push(const string msg)
     {
      int n = ArraySize(m_queue);
      if(n >= 50) return;                    // drop floods; everything is still in the journal
      ArrayResize(m_queue, n + 1);
      m_queue[n] = msg;
     }

   void Flush()
     {
      int n = ArraySize(m_queue);
      if(n == 0 || !m_enabled) { if(!m_enabled) ArrayResize(m_queue, 0); return; }
      if(TimeLocal() - m_last_sent < 7) return;
      if(!TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED)) { ArrayResize(m_queue, 0); return; }

      string text = "GOLD AI: ";
      int used = 0;
      for(int i = 0; i < n; i++)
        {
         string part = (i == 0 ? "" : " | ") + m_queue[i];
         if(StringLen(text) + StringLen(part) > 255)
           {
            if(i == 0) { text = StringSubstr(text + part, 0, 255); used = 1; }
            break;
           }
         text += part;
         used = i + 1;
        }
      if(!SendNotification(text))
         Print("[GOLD_AI] push failed, err=", GetLastError());
      m_last_sent = TimeLocal();
      // Remove the sent messages from the front of the queue.
      for(int j = used; j < n; j++) m_queue[j - used] = m_queue[j];
      ArrayResize(m_queue, n - used);
     }
  };

#endif
