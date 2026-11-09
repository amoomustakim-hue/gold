//+------------------------------------------------------------------+
//| GOLD AI - durable state file (atomic write + first-run marker)    |
//|                                                                   |
//| A terminal global variable marks that this account has run GOLD  |
//| AI before. If the marker exists but the state file is missing or |
//| fails its checksum, the EA locks for the day instead of starting |
//| a fresh (and therefore reset) daily baseline.                     |
//+------------------------------------------------------------------+
#ifndef GOLD_AI_STATESTORE_MQH
#define GOLD_AI_STATESTORE_MQH

#include "StateCodec.mqh"
#include "Journal.mqh"

enum ENUM_GA_LOAD
  {
   GA_LOAD_OK        = 0,
   GA_LOAD_FIRST_RUN = 1,
   GA_LOAD_CORRUPT   = 2
  };

string GA_StateFile(const long login)  { return GA_FOLDER + "\\state_" + (string)login + ".txt"; }
string GA_MarkerName(const long login) { return "GOLD_AI_INIT_" + (string)login; }

bool GA_StateSave(GAState &s, const bool tester)
  {
   s.updated = TimeTradeServer();
   int flags = GA_FileFlags(tester);
   FolderCreate(GA_FOLDER, flags);
   string final_name = GA_StateFile(s.login);
   string tmp_name   = final_name + ".tmp";
   int h = FileOpen(tmp_name, FILE_WRITE | FILE_TXT | FILE_ANSI | flags);
   if(h == INVALID_HANDLE) { Print("[GOLD_AI] state tmp open failed, err=", GetLastError()); return false; }
   FileWriteString(h, GA_StateSerialize(s));
   FileClose(h);
   if(!FileMove(tmp_name, flags, final_name, flags | FILE_REWRITE))
     {
      Print("[GOLD_AI] state move failed, err=", GetLastError());
      return false;
     }
   if(!tester) GlobalVariableSet(GA_MarkerName(s.login), (double)s.updated);
   return true;
  }

int GA_StateLoad(const long login, const bool tester, GAState &s, string &err)
  {
   err = "";
   int flags = GA_FileFlags(tester);
   string name = GA_StateFile(login);
   bool marker = !tester && GlobalVariableCheck(GA_MarkerName(login));

   if(!FileIsExist(name, flags))
     {
      if(marker) { err = "state file missing but this account has run GOLD AI before"; return GA_LOAD_CORRUPT; }
      return GA_LOAD_FIRST_RUN;
     }

   int h = FileOpen(name, FILE_READ | FILE_TXT | FILE_ANSI | flags);
   if(h == INVALID_HANDLE) { err = "cannot open state file, err=" + (string)GetLastError(); return GA_LOAD_CORRUPT; }
   string text = "";
   while(!FileIsEnding(h)) text += FileReadString(h) + "\n";
   FileClose(h);

   if(!GA_StateParse(text, login, s, err)) return GA_LOAD_CORRUPT;
   return GA_LOAD_OK;
  }

#endif
