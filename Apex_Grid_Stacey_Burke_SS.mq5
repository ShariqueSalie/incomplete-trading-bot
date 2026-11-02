//+------------------------------------------------------------------+
//|                                   Apex_Grid_Stacey_Burke_SS.mq5  |
//|                                  Copyright 2026                  |
//|                                                                  |
//|              FIXED PRICE LEVELS: 00, 25, 50, 75                 |
//|              DAY 1-2-3 PANEL + SIGNAL TABLE                      |
//|              SESSION-ALIGNED (18:00 -> 17:00)                    |
//|              ALERTS REMOVED                                      |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- EMA Plots
#property indicator_label2  "EMA 20"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "EMA 50"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  2

#property indicator_label4  "EMA 96"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrPurple
#property indicator_width4  2

#property indicator_label5  "EMA 200"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGreen
#property indicator_width5  2

//--- General Inputs
input int      InpLockEndHour    = 16;
input int      InpLockEndMinute  = 30;
input double   InpEMACloseness   = 5.0;

//--- EMA Settings
input bool     ShowEMA           = true;
input int      EMAPeriod_14      = 14;
input int      EMAPeriod_20      = 20;
input int      EMAPeriod_50      = 50;
input int      EMAPeriod_96      = 96;
input int      EMAPeriod_200     = 200;

//--- Session Settings
input int      SessionStartHour  = 1;
input int      SessionEndHour    = 1;

//--- Day 1-2-3 Settings (TOP-RIGHT)
input bool     ShowDay123Panel         = true;
input int      Day123PanelWidthPx      = 200;
input int      Day123PanelTopPx        = 20;

//--- Signal Table Settings (BOTTOM-RIGHT)
input string   TablePosition           = "Bottom Right";
input bool     ShowSignalTable         = true;
input int      SignalPanelWidthPx      = 220;
input int      SignalPanelBottomPx     = 20;
input int      SignalPanelTopPx        = 200;

//--- PWC Settings
input bool     ShowPWC           = true;
input color    PWCColor          = clrDodgerBlue;

//--- Previous Week Levels Settings
input bool     ShowPrevWeekLevels    = true;

//--- Previous Month Levels Settings
input bool     ShowPrevMonthLevels   = true;

//--- Previous Days Levels Settings
input bool     ShowPrevDaysLevels    = true;
input int      NumberOfDays          = 6;

//--- Price Level Settings
input bool     ShowPriceLevels       = true;
input double   ReferencePrice        = 0;
input int      NumberOfLevelsAbove   = 30;
input int      NumberOfLevelsBelow   = 30;

//--- HOD/LOD Settings
input bool     DrawHODLODLines       = true;

//--- Debug Settings
input bool     DebugSignalEngine     = false;   // set false after diagnosing

//--- Indicator buffers
double ema14Buffer[];
double ema20Buffer[];
double ema50Buffer[];
double ema96Buffer[];
double ema200Buffer[];

//--- Day 1-2-3 structs
double monH=0, monL=DBL_MAX;
double tueH=0, tueL=DBL_MAX;
double wedH=0, wedL=DBL_MAX;
double thuH=0, thuL=DBL_MAX;
double friH=0, friL=DBL_MAX;

datetime lastSessDateD123 = 0;
int      lastSessIdxD123  = 0;

//--- Global variables
double hod=0, lod=0;
double dayOpen=0;
datetime lastDayStart=0;
bool hodlodLocked = false;
double runningHod = 0;
double runningLod = 0;

double weeklyPWCFib = 0;

datetime lastBarTime = 0;
datetime lastDailyCalc = 0;
datetime lastWeeklyCalc = 0;
datetime lastMonthlyCalc = 0;
double cachedPoint = 0;
datetime lastPointCheck = 0;

struct DayLevels
{
   datetime dayDate;
   double high;
   double low;
   double close;
   double open;
   color lineColor;
   bool isValid;
};
DayLevels prevDays[100];

struct WeekLevels
{
   double weekHigh;
   double weekLow;
   bool isValid;
};
WeekLevels prevWeek;

struct MonthLevels
{
   double monthHigh;
   double monthLow;
   bool isValid;
};
MonthLevels prevMonth;

//=== SIGNAL ENGINE STATE ============================================
double pdh = 0.0;
double pdl = 0.0;
double pdc = 0.0;
double cdh = 0.0;
double cdl = 0.0;
double fridayHigh = 0.0;
double fridayLow = 0.0;
double lastFridayHigh = 0.0;
double lastFridayLow = 0.0;
double cibLevel = 0.0;
bool   showCIBLevel = false;
int    cibLevelStartBar = -1;
string cibDirection = "";

bool   tradedAbovePDH = false;
bool   tradedBelowPDL = false;

int    consecutiveCount = 1;
bool   lastWasHigher = false;
double lastPDC = 0.0;
bool   isFirstCount = true;
bool   yesterdayWasFGDSignal = false;
bool   yesterdayWasFRDSignal = false;
bool   yesterdayWas3Plus = false;
string yesterdayDirection = "";

string signalDayType = "";
string yesterdaySignal = "";

bool   isAPlusSetup = false;
string aPlusType = "";
bool   isAPlusPlusSetup = false;
string aPlusPlusType = "";
bool   is3PlusTrigger = false;
string threePlusType = "";

string lastEMASignal = "NONE";
bool   lastEMABull = false;

//=== helpers ========================================================

datetime GetSessionDate(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.hour < SessionStartHour)
      t -= 86400;
   MqlDateTime sd;
   TimeToStruct(t, sd);
   sd.hour = 0;
   sd.min  = 0;
   sd.sec  = 0;
   return StructToTime(sd);
}

datetime SessionStartTime(datetime sessDate)
{
   MqlDateTime dt;
   TimeToStruct(sessDate, dt);
   dt.hour = SessionStartHour;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

datetime SessionEndTime(datetime sessDate)
{
   MqlDateTime dt;
   TimeToStruct(sessDate, dt);
   dt.hour = SessionEndHour;
   dt.min  = 59;
   dt.sec  = 59;
   datetime endTime = StructToTime(dt);
   if(SessionEndHour <= SessionStartHour)
      endTime += 86400;
   return endTime;
}

// Broker D1 closes at 23:59 server time. Convert a D1 bar open time
// to the 23:59 close time of that same broker day.
datetime BrokerDayClose2359(datetime barOpenTime)
{
   MqlDateTime dt;
   TimeToStruct(barOpenTime, dt);
   dt.hour = 23;
   dt.min  = 59;
   dt.sec  = 0;
   return StructToTime(dt);
}

// Calendar-day floor (00:00) used to compare D1 bar dates.
datetime DayStart00(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Compute OHLC of a completed session                              |
//+------------------------------------------------------------------+
bool GetSessionOHLC(datetime sessDate,
                    double &sHigh, double &sLow, double &sClose, double &sOpen)
{
   sHigh = -DBL_MAX;
   sLow  =  DBL_MAX;
   sClose = 0.0;
   sOpen  = 0.0;

   datetime startT = SessionStartTime(sessDate);
   datetime endT   = SessionEndTime(sessDate);
   // extend to be safe
   startT = startT - 60;
   endT   = endT   + 60;

   int total = Bars(_Symbol, _Period);
   if(total <= 0) return false;

   int firstIdx = -1;
   for(int shift = total - 1; shift >= 0; shift--)
   {
      datetime bt = iTime(_Symbol, _Period, shift);
      if(bt < startT) continue;
      if(bt > endT) continue;
      double h = iHigh(_Symbol, _Period, shift);
      double l = iLow(_Symbol, _Period, shift);
      double c = iClose(_Symbol, _Period, shift);
      double o = iOpen(_Symbol, _Period, shift);
      if(firstIdx == -1)
      {
         sOpen = o;
         firstIdx = shift;
      }
      if(h > sHigh) sHigh = h;
      if(l < sLow)  sLow  = l;
      sClose = c;
   }

   if(firstIdx == -1 || sHigh < sLow) return false;
   return true;
}

double GetPointValue()
{
   datetime now = TimeCurrent();
   if(now - lastPointCheck < 60 && cachedPoint > 0)
      return cachedPoint;
   lastPointCheck = now;
   cachedPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(cachedPoint <= 0) cachedPoint = 0.00001;
   return cachedPoint;
}

void UpdateLabel(string name, int x, int y, string text, int fontSize, color clr = clrWhite, int corner = CORNER_LEFT_UPPER)
{
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

int GetSessionDayOfWeek(datetime t, datetime &sessionDate)
{
   sessionDate = GetSessionDate(t);
   MqlDateTime sdt;
   TimeToStruct(sessionDate, sdt);
   return sdt.day_of_week;
}

int DowToIndex(int dow)
{
   switch(dow)
   {
      case 1: return 1; // Monday
      case 2: return 2; // Tuesday
      case 3: return 3; // Wednesday
      case 4: return 4; // Thursday
      case 5: return 5; // Friday
      case 0: return 1; // Sunday treated as start? but better follow server day
      case 6: return 1;
      default: return 0;
   }
}

void ResetDayRanges()
{
   monH=0; monL=DBL_MAX;
   tueH=0; tueL=DBL_MAX;
   wedH=0; wedL=DBL_MAX;
   thuH=0; thuL=DBL_MAX;
   friH=0; friL=DBL_MAX;
   lastSessDateD123 = 0;
   lastSessIdxD123  = 0;
}

void GetDay123Slots(int idx, int &s1, int &s2, int &s3)
{
   s1 = 0; s2 = 0; s3 = 0;
   if(idx == 1) s1 = 1;
   else if(idx == 2) { s1 = 1; s2 = 2; }
   else if(idx == 3) { s1 = 1; s2 = 2; s3 = 3; }
   else if(idx == 4) { s1 = 3; s2 = 4; }
   else if(idx == 5) { s1 = 3; s2 = 4; s3 = 5; }
}

double GetSlotH(int slot)
{
   if(slot==1) return monH;
   if(slot==2) return tueH;
   if(slot==3) return wedH;
   if(slot==4) return thuH;
   if(slot==5) return friH;
   return 0;
}
double GetSlotL(int slot)
{
   if(slot==1) return monL==DBL_MAX?0:monL;
   if(slot==2) return tueL==DBL_MAX?0:tueL;
   if(slot==3) return wedL==DBL_MAX?0:wedL;
   if(slot==4) return thuL==DBL_MAX?0:thuL;
   if(slot==5) return friL==DBL_MAX?0:friL;
   return 0;
}
bool GetSlotValid(int slot)
{
   if(slot==1) return monL!=DBL_MAX && monH!=0;
   if(slot==2) return tueL!=DBL_MAX && tueH!=0;
   if(slot==3) return wedL!=DBL_MAX && wedH!=0;
   if(slot==4) return thuL!=DBL_MAX && thuH!=0;
   if(slot==5) return friL!=DBL_MAX && friH!=0;
   return false;
}

double GetDaySlotRange(int slot)
{
   if(!GetSlotValid(slot)) return -1.0;
   return GetSlotH(slot) - GetSlotL(slot);
}

double GetDayTotalRange(int s1, int s2, int s3)
{
   double totalHigh = -DBL_MAX;
   double totalLow  = DBL_MAX;
   bool haveData = false;
   int slots[3]; slots[0]=s1; slots[1]=s2; slots[2]=s3;
   for(int i=0;i<3;i++)
   {
      int sl = slots[i];
      if(!GetSlotValid(sl)) continue;
      if(GetSlotH(sl) > totalHigh) totalHigh = GetSlotH(sl);
      if(GetSlotL(sl) < totalLow)  totalLow  = GetSlotL(sl);
      haveData = true;
   }
   if(!haveData || totalHigh < totalLow) return -1.0;
   return totalHigh - totalLow;
}

void DrawDay123Panel()
{
   if(!ShowDay123Panel) return;

   datetime now = TimeCurrent();
   datetime sessDate;
   int dow = GetSessionDayOfWeek(now, sessDate); // 0=Sun
   int idx = DowToIndex(dow);

   int s1, s2, s3;
   GetDay123Slots(idx, s1, s2, s3);

   double r1 = GetDaySlotRange(s1);
   double r2 = GetDaySlotRange(s2);
   double r3 = GetDaySlotRange(s3);
   double total = GetDayTotalRange(s1, s2, s3);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int lh = 16;
   int yPos = Day123PanelTopPx;

   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int xPos = chartWidth - Day123PanelWidthPx;
   if(xPos < 5) xPos = 5;

   int lc = 0;
   color hdrColor = clrGold;
   color rowColor = clrWhite;

   UpdateLabel("D123_Hdr1", xPos, yPos + lh*lc++, "Day       Range", 9, hdrColor);
   UpdateLabel("D123_D1",   xPos, yPos + lh*lc++,
               StringFormat("Day 1  %10s", (r1 < 0 ? "-" : DoubleToString(r1, digits))), 9, rowColor);
   UpdateLabel("D123_D2",   xPos, yPos + lh*lc++,
               StringFormat("Day 2  %10s", (r2 < 0 ? "-" : DoubleToString(r2, digits))), 9, rowColor);
   UpdateLabel("D123_D3",   xPos, yPos + lh*lc++,
               StringFormat("Day 3  %10s", (r3 < 0 ? "-" : DoubleToString(r3, digits))), 9, rowColor);
   UpdateLabel("D123_Tot",  xPos, yPos + lh*lc++,
               StringFormat("Total  %10s", (total < 0 ? "-" : DoubleToString(total, digits))), 9, clrOrange);
}

void UpdateDay123Ranges(const datetime &time[], const double &high[], const double &low[], int rates_total)
{
   for(int i = 0; i < rates_total; i++)
   {
      datetime barTime = time[i];
      if(lastSessDateD123 != 0 && barTime <= lastSessDateD123 && false) { }
      // use session date change like Pine

      datetime sessDate;
      int dow = GetSessionDayOfWeek(barTime, sessDate); // 0=Sun
      int idx = DowToIndex(dow);

      bool newSession = false;
      if(lastSessDateD123 == 0)
      {
         newSession = true;
         lastSessDateD123 = sessDate;
         lastSessIdxD123  = idx;
      }
      else if(sessDate != lastSessDateD123)
      {
         newSession = true;
         lastSessDateD123 = sessDate;
         lastSessIdxD123  = idx;
      }

      if(idx == 1)
      {
         if(newSession || monL == DBL_MAX) { monH = high[i]; monL = low[i]; }
         else { if(high[i] > monH) monH = high[i]; if(low[i] < monL) monL = low[i]; }
      }
      else if(idx == 2)
      {
         if(newSession || tueL == DBL_MAX) { tueH = high[i]; tueL = low[i]; }
         else { if(high[i] > tueH) tueH = high[i]; if(low[i] < tueL) tueL = low[i]; }
      }
      else if(idx == 3)
      {
         if(newSession || wedL == DBL_MAX) { wedH = high[i]; wedL = low[i]; }
         else { if(high[i] > wedH) wedH = high[i]; if(low[i] < wedL) wedL = low[i]; }
      }
      else if(idx == 4)
      {
         if(newSession || thuL == DBL_MAX) { thuH = high[i]; thuL = low[i]; }
         else { if(high[i] > thuH) thuH = high[i]; if(low[i] < thuL) thuL = low[i]; }
      }
      else if(idx == 5)
      {
         if(newSession || friL == DBL_MAX) { friH = high[i]; friL = low[i]; }
         else { if(high[i] > friH) friH = high[i]; if(low[i] < friL) friL = low[i]; }
      }
   }
}

void DrawSignalTable()
{
   if(!ShowSignalTable) return;

   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

   bool bottom = (TablePosition == "Bottom Right");
   int corner  = bottom ? CORNER_LEFT_LOWER : CORNER_LEFT_UPPER;

   int xPos = chartWidth - SignalPanelWidthPx;
   if(xPos < 5) xPos = 5;

   int yBase = bottom ? SignalPanelBottomPx : SignalPanelTopPx;

   int lh = 16;
   int lc = 0;

   color hdrColor = clrGold;
   color rowColor = clrWhite;
   color noColor  = clrGray;
   color bgHeader = C'20,30,40';
   color bgRow    = C'10,15,25';

   // Use labels styled like table rows
   // Header removed as requested

   bool insideTrigger = (yesterdaySignal == "INSIDE");
   string insideText = insideTrigger ? "YES" : "NO";
   color insideColor = insideTrigger ? clrBlue : noColor;
   UpdateLabel("SIG_Inside", xPos, yBase + lh*lc++,
               StringFormat("INSIDE        %s", insideText), 9, insideColor, corner);

   bool cibTrigger = (yesterdaySignal == "CIBBO") || (yesterdaySignal == "CIBBO DN") || (yesterdaySignal == "CIBBO↓");
   string cibTextTbl = cibTrigger ? (yesterdaySignal == "CIBBO" ? "YES" : "YES") : "NO";
   color cibColorTbl = cibTrigger ? (yesterdaySignal == "CIBBO" ? clrAqua : clrRed) : noColor;
   UpdateLabel("SIG_CIB", xPos, yBase + lh*lc++,
               StringFormat("CIB           %s", cibTextTbl), 9, cibColorTbl, corner);

   string threeText = is3PlusTrigger ? threePlusType : "NO";
   color threeColor = is3PlusTrigger ? (yesterdayDirection == "UP" ? clrLime : clrRed) : noColor;
   UpdateLabel("SIG_3Plus", xPos, yBase + lh*lc++,
               StringFormat("3+            %s", threeText), 9, threeColor, corner);

   string aPlusText = yesterdayWasFGDSignal ? "FGD" : yesterdayWasFRDSignal ? "FRD" : "NO";
   color aPlusColor = yesterdayWasFGDSignal ? clrAqua : yesterdayWasFRDSignal ? clrRed : noColor;
   UpdateLabel("SIG_APlus", xPos, yBase + lh*lc++,
               StringFormat("A+            %s", aPlusText), 9, aPlusColor, corner);

   string aPlusPlusText = isAPlusPlusSetup ? aPlusPlusType : "NO";
   color aPlusPlusColor = isAPlusPlusSetup ? ((StringFind(aPlusPlusType,"BULL")>=0) ? clrLime : clrRed) : noColor;
   UpdateLabel("SIG_APlusPlus", xPos, yBase + lh*lc++,
               StringFormat("A++           %s", aPlusPlusText), 9, aPlusPlusColor, corner);

   string aPlusPlusPlusText = isAPlusSetup ? aPlusType : "NO";
   color aPlusPlusPlusColor = isAPlusSetup ? ((StringFind(aPlusType,"BULL")>=0) ? clrLime : clrRed) : noColor;
   UpdateLabel("SIG_APlusPlusPlus", xPos, yBase + lh*lc++,
               StringFormat("A+++          %s", aPlusPlusPlusText), 9, aPlusPlusPlusColor, corner);

   string emaSig = lastEMASignal;
   if(emaSig == "NONE") emaSig = "NO";
   color emaSigColor = (emaSig == "BUY") ? clrLime : (emaSig == "SELL") ? clrRed : noColor;
   UpdateLabel("SIG_EMA", xPos, yBase + lh*lc++,
               StringFormat("SIGNAL        %s", emaSig), 9, emaSigColor, corner);
}

void UpdateEMASignal(const double &close[], int rates_total)
{
   if(rates_total < 5) return;
   if(!ShowEMA) return;
   
   // Need at least 2 bars to detect cross
   int idx = rates_total - 1;
   int prevIdx = rates_total - 2;
   
   if(ema20Buffer[idx] <= 0 || ema50Buffer[idx] <= 0) return;
   
   bool currentBull = (close[idx] > ema20Buffer[idx] && ema20Buffer[idx] > ema50Buffer[idx]);
   bool currentBear = (close[idx] < ema20Buffer[idx] && ema20Buffer[idx] < ema50Buffer[idx]);
   
   // Detect cross
   bool prevBull = (close[prevIdx] > ema20Buffer[prevIdx] && ema20Buffer[prevIdx] > ema50Buffer[prevIdx]);
   bool prevBear = (close[prevIdx] < ema20Buffer[prevIdx] && ema20Buffer[prevIdx] < ema50Buffer[prevIdx]);
   
   if(currentBull && !prevBull)
   {
      lastEMASignal = "BUY";
      lastEMABull = true;
   }
   else if(currentBear && !prevBear)
   {
      lastEMASignal = "SELL";
      lastEMABull = false;
   }
   else if(currentBull)
   {
      if(lastEMASignal != "BUY")
      {
         lastEMASignal = "BUY";
         lastEMABull = true;
      }
   }
   else if(currentBear)
   {
      if(lastEMASignal != "SELL")
      {
         lastEMASignal = "SELL";
         lastEMABull = false;
      }
   }
}

void ProcessDailySignals(int rates_total, const datetime &time[],
                         const double &open[], const double &high[],
                         const double &low[],  const double &close[])
{
   if(rates_total < 3) return;

   int last = rates_total - 1;

   static datetime prevSessionDate = 0;
   datetime curSessionDate = GetSessionDate(time[last]);
   bool isNewSession = (prevSessionDate != curSessionDate);

   MqlDateTime sdt;
   TimeToStruct(curSessionDate, sdt);
   bool isFriday = (sdt.day_of_week == 5);

   if(!isNewSession)
      return;

   // Daily bar mapping (series indexing).
   // If today's D1 bar already exists: yesterday = sd+1, day before = sd+2.
   // On a weekend/holiday load the newest bar is already the last completed
   // day, so yesterday = sd, day before = sd+1.
   int d1Bars = Bars(_Symbol, PERIOD_D1);
   int sd = iBarShift(_Symbol, PERIOD_D1, TimeCurrent(), false);
   if(sd < 0) sd = 0;
   bool todayBarExists = (DayStart00(iTime(_Symbol, PERIOD_D1, sd)) ==
                          DayStart00(TimeCurrent()));
   int yShift  = todayBarExists ? sd + 1 : sd;
   int dbShift = yShift + 1;
   if(d1Bars <= 0 || dbShift >= d1Bars)
   {
      // Do not mark the session as processed yet - retry on the next tick.
      if(DebugSignalEngine)
         PrintFormat("SIG-DEBUG: not enough D1 history (sd=%d y=%d db=%d bars=%d)",
                     sd, yShift, dbShift, d1Bars);
      return;
   }

   double dClose1 = iClose(_Symbol, PERIOD_D1, yShift);
   double dOpen1  = iOpen(_Symbol, PERIOD_D1, yShift);
   double dHigh1  = iHigh(_Symbol, PERIOD_D1, yShift);
   double dLow1   = iLow(_Symbol, PERIOD_D1, yShift);
   double dClose2 = iClose(_Symbol, PERIOD_D1, dbShift);
   double dHigh2  = iHigh(_Symbol, PERIOD_D1, dbShift);
   double dLow2   = iLow(_Symbol, PERIOD_D1, dbShift);
   if(dClose1 <= 0 || dClose2 <= 0)
   {
      if(DebugSignalEngine)
         Print("SIG-DEBUG: D1 close data not ready");
      return;
   }

   double refPDC = dClose1;   // previous day close (PDC shown on the current day)
   double sigPDC = dClose2;   // PDC that was valid for yesterday's signal

   pdh = dHigh2;              // PDH/PDL that yesterday traded against
   pdl = dLow2;
   pdc = refPDC;

   // keep Friday tracking from daily if possible
   {
      datetime d1Time = iTime(_Symbol, PERIOD_D1, yShift);
      MqlDateTime d1dt; TimeToStruct(d1Time, d1dt);
      if(d1dt.day_of_week == 5) { lastFridayHigh = dHigh1; lastFridayLow = dLow1; }
   }
   if(isFriday && lastFridayHigh > 0.0) { fridayHigh = lastFridayHigh; fridayLow = lastFridayLow; }

   consecutiveCount = 1;
   lastWasHigher    = false;
   yesterdayWasFGDSignal = false;
   yesterdayWasFRDSignal = false;
   yesterdayWas3Plus     = false;
   yesterdayDirection    = "";

   bool havePrevPDC = (dClose1 > 0.0 && dClose2 > 0.0);
   bool curHigherDaily = havePrevPDC ? (dClose1 > dClose2 + 1e-9) : false;
   lastWasHigher = curHigherDaily;

   int count = 1;
   bool walkDir = curHigherDaily;
   int maxWalk = 25;
   if(havePrevPDC)
   {
      for(int k = 2; k <= maxWalk + 1; k++)
      {
         int shiftN   = yShift + (k - 1);
         int shiftNm1 = yShift + k;
         if(shiftNm1 >= d1Bars) break;
         double cN = iClose(_Symbol, PERIOD_D1, shiftN);
         double cNm1 = iClose(_Symbol, PERIOD_D1, shiftNm1);
         if(cN == 0 || cNm1 == 0) break;
         bool stepHigher = (cN > cNm1 + 1e-9);
         if(stepHigher == walkDir)
         {
            count++;
            if(count >= 60) break;
         }
         else break;
      }
   }
   consecutiveCount = count;

   if(havePrevPDC && consecutiveCount == 1)
   {
      bool yG = (dClose1 > dClose2 + 1e-9);
      yesterdayWasFGDSignal = yG;
      yesterdayWasFRDSignal = !yG;
   }
   else
   {
      yesterdayWasFGDSignal = false;
      yesterdayWasFRDSignal = false;
   }

   if(havePrevPDC && consecutiveCount >= 3)
   {
      yesterdayWas3Plus = true;
      yesterdayDirection = curHigherDaily ? "UP" : "DOWN";
   }
   else
   {
      yesterdayWas3Plus = false;
      yesterdayDirection = "";
   }

   lastPDC = refPDC;

   // Determine signal type based on D1 vs PDH/PDL (using day before yesterday range per Pine)
   bool yTradedAbovePDH = (pdh > 0.0 && dHigh1 > pdh);
   bool yTradedBelowPDL = (pdl > 0.0 && dLow1  < pdl);

   // INSIDE = yesterday stayed inside the day-before-yesterday range
   // (did not trade above PDH and did not trade below PDL).
   string tempSignalType = "";
   if(yTradedAbovePDH && yTradedBelowPDL)
   {
      if(dClose1 < sigPDC - 1e-9)
         tempSignalType = "FBFRDBO";
   }
   else if(yTradedAbovePDH)
   {
      if(dClose1 > pdh + 1e-9)
      {
         tempSignalType   = "CIBBO";
         cibLevel         = pdh;
         showCIBLevel     = true;
         cibLevelStartBar = last;
         cibDirection     = "BULL";
      }
      else if(dClose1 > sigPDC + 1e-9)
         tempSignalType = "BO";
      else if(dClose1 < sigPDC - 1e-9)
         tempSignalType = "FB";
   }
   else if(yTradedBelowPDL)
   {
      if(dClose1 < pdl - 1e-9)
      {
         tempSignalType   = "CIBBO DN";
         cibLevel         = pdl;
         showCIBLevel     = true;
         cibLevelStartBar = last;
         cibDirection     = "BEAR";
      }
      else if(dClose1 < sigPDC - 1e-9)
         tempSignalType = "BO DN";
      else if(dClose1 > sigPDC + 1e-9)
         tempSignalType = "FB DN";
   }
   else
   {
      tempSignalType = "INSIDE";
   }

   string displayType = tempSignalType;
   if(havePrevPDC)
   {
      if(consecutiveCount == 1)
      {
         if(dClose1 > dClose2 + 1e-9)  displayType = displayType + " FGD";
         else                          displayType = displayType + " FRD";
      }
      else
      {
         displayType = displayType + " " + IntegerToString(consecutiveCount);
      }
   }

   yesterdaySignal = tempSignalType;
   signalDayType   = displayType;

   if(DebugSignalEngine)
   {
      PrintFormat("SIG-DEBUG D1[1]=%.5f D1[2]=%.5f PDC=%.5f SigPDC=%.5f PDH=%.5f PDL=%.5f above=%d below=%d havePrev=%d curHigher=%d count=%d FGD=%d FRD=%d 3+=%d type=%s",
                  dClose1, dClose2, refPDC, sigPDC, pdh, pdl,
                  (int)yTradedAbovePDH, (int)yTradedBelowPDL,
                  (int)havePrevPDC, (int)curHigherDaily, consecutiveCount,
                  (int)yesterdayWasFGDSignal, (int)yesterdayWasFRDSignal, (int)yesterdayWas3Plus,
                  tempSignalType);
   }

   bool cibboFGD   = (yesterdaySignal == "CIBBO")      && yesterdayWasFGDSignal;
   bool cibboFRD   = (yesterdaySignal == "CIBBO DN")   && yesterdayWasFRDSignal;
   bool boFGD      = (yesterdaySignal == "BO")         && yesterdayWasFGDSignal;
   bool boFRD      = (yesterdaySignal == "BO DN")      && yesterdayWasFRDSignal;
   bool fbfrdboFRD = (yesterdaySignal == "FBFRDBO")    && yesterdayWasFRDSignal;

   isAPlusSetup     = (cibboFGD || cibboFRD);
   aPlusType        = cibboFGD ? "BULLISH A+++"
                    : cibboFRD ? "BEARISH A+++" : "";

   isAPlusPlusSetup = (boFGD || boFRD || fbfrdboFRD);
   aPlusPlusType    = boFGD ? "BULLISH A++"
                    : (boFRD || fbfrdboFRD) ? "BEARISH A++" : "";

   is3PlusTrigger   = yesterdayWas3Plus;
   threePlusType    = yesterdayWas3Plus
                      ? (yesterdayDirection == "UP" ? "3+ UP" : "3+ DOWN")
                      : "";

   // Session successfully processed
   prevSessionDate = curSessionDate;
}

void GetPreviousDaysLevels()
{
   datetime now = TimeCurrent();
   datetime curSessDate = GetSessionDate(now);
   int maxDays = MathMin(NumberOfDays, 100);

   for(int d = 1; d <= maxDays; d++)
   {
      datetime targetSess = curSessDate - d * 86400;
      double sHigh, sLow, sClose, sOpen = 0;
      // try daily first for accuracy
      int shiftD = iBarShift(_Symbol, PERIOD_D1, targetSess, true);
      if(shiftD >= 0)
      {
         sHigh = iHigh(_Symbol, PERIOD_D1, shiftD);
         sLow  = iLow(_Symbol, PERIOD_D1, shiftD);
         sClose= iClose(_Symbol, PERIOD_D1, shiftD);
         sOpen = iOpen(_Symbol, PERIOD_D1, shiftD);
         prevDays[d-1].dayDate   = targetSess;
         prevDays[d-1].high      = sHigh;
         prevDays[d-1].low       = sLow;
         prevDays[d-1].close     = sClose;
         prevDays[d-1].open      = sOpen;
         prevDays[d-1].isValid   = true;
         prevDays[d-1].lineColor = (sClose > sOpen) ? clrGreen : clrRed;
         continue;
      }
      if(GetSessionOHLC(targetSess, sHigh, sLow, sClose, sOpen))
      {
         prevDays[d-1].dayDate   = targetSess;
         prevDays[d-1].high      = sHigh;
         prevDays[d-1].low       = sLow;
         prevDays[d-1].close     = sClose;
         prevDays[d-1].open      = sOpen;
         prevDays[d-1].isValid   = true;
         prevDays[d-1].lineColor = (sClose > sOpen) ? clrGreen : clrRed;
      }
   }
}

void DrawPreviousDaysLevels()
{
   // Rebuild all PDC lines (current + past 5) on every redraw.
   // Remove objects from older layouts too.
   ObjectsDeleteAll(0, "PDC_Line_Day");
   ObjectsDeleteAll(0, "PDC_Line_Past");

   if(!ShowPrevDaysLevels) return;

   int maxDays = MathMin(NumberOfDays, 100);

   for(int d = 0; d < maxDays; d++)
   {
      if(!prevDays[d].isValid) continue;

      string suffix = "_Day" + IntegerToString(d+1);
      datetime sessStart = SessionStartTime(prevDays[d].dayDate);
      datetime sessEnd   = SessionEndTime(prevDays[d].dayDate);

      string pdhName = "PDH_Line" + suffix;
      ObjectDelete(0, pdhName);
      ObjectCreate(0, pdhName, OBJ_TREND, 0, sessStart, prevDays[d].high, sessEnd, prevDays[d].high);
      ObjectSetInteger(0, pdhName, OBJPROP_COLOR, prevDays[d].lineColor);
      ObjectSetInteger(0, pdhName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, pdhName, OBJPROP_RAY_RIGHT, false);

      string pdlName = "PDL_Line" + suffix;
      ObjectDelete(0, pdlName);
      ObjectCreate(0, pdlName, OBJ_TREND, 0, sessStart, prevDays[d].low, sessEnd, prevDays[d].low);
      ObjectSetInteger(0, pdlName, OBJPROP_COLOR, prevDays[d].lineColor);
      ObjectSetInteger(0, pdlName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, pdlName, OBJPROP_RAY_RIGHT, false);
   }

   // PDC lines = close of the preceding broker D1 bar (23:59).
   // Draw the current day plus the last 5 past days. Each line starts at the
   // preceding day's 23:59 and stops at that day's 23:59.
   {
      int sdCur = iBarShift(_Symbol, PERIOD_D1, TimeCurrent(), false);
      if(sdCur < 0) sdCur = 0;

      int d1Bars = Bars(_Symbol, PERIOD_D1);
      int pastCount = 5;

      for(int k = 0; k <= pastCount; k++)
      {
         int dayShift  = sdCur + k;      // 0 = current day, 1 = yesterday...
         int prevShift = dayShift + 1;   // bar whose close is this day's PDC
         if(d1Bars <= 0 || prevShift >= d1Bars) continue;

         datetime dayBarTime  = iTime(_Symbol, PERIOD_D1, dayShift);
         datetime prevBarTime = iTime(_Symbol, PERIOD_D1, prevShift);
         if(dayBarTime <= 0 || prevBarTime <= 0) continue;

         double pdcLineVal = iClose(_Symbol, PERIOD_D1, prevShift);
         if(pdcLineVal <= 0 && k == 0) pdcLineVal = pdc;
         if(pdcLineVal <= 0 && k < 100 && prevDays[k].isValid)
            pdcLineVal = prevDays[k].close;
         if(pdcLineVal <= 0) continue;

         datetime pdcStart = BrokerDayClose2359(prevBarTime); // preceding day 23:59
         datetime pdcEnd   = BrokerDayClose2359(dayBarTime);  // this day 23:59
         if(pdcEnd <= pdcStart) pdcEnd = pdcStart + 86400;

         string pdcName = (k == 0) ? "PDC_Line_YesterdayOnToday"
                                   : "PDC_Line_Past" + IntegerToString(k);
         ObjectDelete(0, pdcName);
         ObjectCreate(0, pdcName, OBJ_TREND, 0, pdcStart, pdcLineVal, pdcEnd, pdcLineVal);
         ObjectSetInteger(0, pdcName, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, pdcName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, pdcName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, pdcName, OBJPROP_RAY_LEFT, false);
      }
   }
}

void GetPreviousWeekLevels()
{
   datetime now = TimeCurrent();
   datetime curSessDate = GetSessionDate(now);
   datetime currentMonday = curSessDate;

   MqlDateTime dt;
   TimeToStruct(currentMonday, dt);
   while(dt.day_of_week != 1)
   {
      currentMonday -= 86400;
      TimeToStruct(currentMonday, dt);
   }

   datetime prevWeekMonday = currentMonday - 7 * 86400;

   double tempHigh = 0;
   double tempLow  = DBL_MAX;
   bool got = false;

   for(int d = 0; d < 5; d++)
   {
      datetime sess = prevWeekMonday + d * 86400;
      double sHigh, sLow, sClose, sOpen;
      if(!GetSessionOHLC(sess, sHigh, sLow, sClose, sOpen)) continue;
      if(sHigh > tempHigh) tempHigh = sHigh;
      if(sLow  < tempLow)  tempLow  = sLow;
      got = true;
   }

   if(got && tempHigh > 0)
   {
      prevWeek.weekHigh = tempHigh;
      prevWeek.weekLow  = tempLow;
      prevWeek.isValid  = true;
   }
}

void DrawPreviousWeekLevels()
{
   if(!ShowPrevWeekLevels || !prevWeek.isValid) return;

   datetime now = TimeCurrent();
   datetime startTime = now - (3600 * 24 * 30);
   datetime endTime = now + (3600 * 24 * 10);

   string highLine = "PrevWeek_High";
   ObjectDelete(0, highLine);
   ObjectCreate(0, highLine, OBJ_TREND, 0, startTime, prevWeek.weekHigh, endTime, prevWeek.weekHigh);
   ObjectSetInteger(0, highLine, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, highLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, highLine, OBJPROP_RAY_RIGHT, true);

   string lowLine = "PrevWeek_Low";
   ObjectDelete(0, lowLine);
   ObjectCreate(0, lowLine, OBJ_TREND, 0, startTime, prevWeek.weekLow, endTime, prevWeek.weekLow);
   ObjectSetInteger(0, lowLine, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, lowLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lowLine, OBJPROP_RAY_RIGHT, true);
}

void GetPreviousMonthLevels()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(GetSessionDate(now), dt);

   int prevMonthYear = dt.year;
   int prevMonthNum = dt.mon - 1;
   if(prevMonthNum < 1)
   {
      prevMonthNum = 12;
      prevMonthYear--;
   }

   double tempHigh = 0;
   double tempLow  = DBL_MAX;
   bool got = false;

   datetime curSess = GetSessionDate(now);
   datetime checkDate = curSess;

   for(int step = 0; step < 40; step++)
   {
      checkDate -= 86400;
      MqlDateTime cd;
      TimeToStruct(checkDate, cd);
      if(cd.mon != prevMonthNum || cd.year != prevMonthYear)
         break;

      double sHigh, sLow, sClose, sOpen;
      if(!GetSessionOHLC(checkDate, sHigh, sLow, sClose, sOpen)) continue;
      if(sHigh > tempHigh) tempHigh = sHigh;
      if(sLow  < tempLow)  tempLow  = sLow;
      got = true;
   }

   if(got && tempHigh > 0)
   {
      prevMonth.monthHigh = tempHigh;
      prevMonth.monthLow  = tempLow;
      prevMonth.isValid   = true;
   }
}

void DrawPreviousMonthLevels()
{
   if(!ShowPrevMonthLevels || !prevMonth.isValid) return;

   datetime now = TimeCurrent();
   datetime startTime = now - (3600 * 24 * 30);
   datetime endTime = now + (3600 * 24 * 10);

   string highLine = "PrevMonth_High";
   ObjectDelete(0, highLine);
   ObjectCreate(0, highLine, OBJ_TREND, 0, startTime, prevMonth.monthHigh, endTime, prevMonth.monthHigh);
   ObjectSetInteger(0, highLine, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, highLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, highLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, highLine, OBJPROP_RAY_RIGHT, true);

   string lowLine = "PrevMonth_Low";
   ObjectDelete(0, lowLine);
   ObjectCreate(0, lowLine, OBJ_TREND, 0, startTime, prevMonth.monthLow, endTime, prevMonth.monthLow);
   ObjectSetInteger(0, lowLine, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, lowLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lowLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lowLine, OBJPROP_RAY_RIGHT, true);
}

void CalculateWeeklyPWC()
{
   datetime now = TimeCurrent();
   datetime curSessDate = GetSessionDate(now);
   datetime lastFriday = 0;

   for(int i = 1; i <= 7; i++)
   {
      datetime checkDate = curSessDate - (i * 86400);
      MqlDateTime c;
      TimeToStruct(checkDate, c);
      if(c.day_of_week == 5)
      {
         lastFriday = checkDate;
         break;
      }
   }

   if(lastFriday > 0)
   {
      double sHigh, sLow, sClose, sOpen;
      if(GetSessionOHLC(lastFriday, sHigh, sLow, sClose, sOpen))
         weeklyPWCFib = sClose;
   }

   if(weeklyPWCFib == 0)
   {
      int weeklyShift = iBarShift(_Symbol, PERIOD_W1, 1);
      if(weeklyShift >= 0) weeklyPWCFib = iClose(_Symbol, PERIOD_W1, weeklyShift);
   }
}

void DrawPWCLine()
{
   if(!ShowPWC || weeklyPWCFib == 0) return;

   datetime now = TimeCurrent();
   datetime startTime = now - (3600 * 24 * 60);
   datetime endTime = now + (3600 * 24 * 30);

   string lineName = "PWC_Line";
   ObjectDelete(0, lineName);
   ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, weeklyPWCFib, endTime, weeklyPWCFib);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, PWCColor);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, true);
}

void UpdatePWC()
{
   CalculateWeeklyPWC();
   DrawPWCLine();
}

void DrawPriceLevels()
{
   if(!ShowPriceLevels) return;

   datetime now = TimeCurrent();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double reference = (ReferencePrice == 0) ? currentPrice : ReferencePrice;

   double majorStep = 100.0;
   double quarterStep = 25.0;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(currentPrice >= 10000)
   {
      majorStep = 1000.0;
      quarterStep = 250.0;
   }
   else if(currentPrice >= 1000)
   {
      majorStep = 100.0;
      quarterStep = 25.0;
   }
   else if(currentPrice >= 100)
   {
      majorStep = 50.0;
      quarterStep = 12.5;
   }
   else if(currentPrice >= 10)
   {
      majorStep = 10.0;
      quarterStep = 2.5;
   }
   else if(digits >= 4)
   {
      majorStep = 0.01;
      quarterStep = 0.0025;
   }
   else if(digits >= 3)
   {
      majorStep = 1.0;
      quarterStep = 0.25;
   }
   else
   {
      majorStep = 100.0;
      quarterStep = 25.0;
   }

   double baseLevel = MathFloor(reference / majorStep) * majorStep;
   if(baseLevel <= 0) baseLevel = majorStep;

   datetime startTime = now - (3600 * 24 * 30);
   datetime endTime = now + (3600 * 24 * 10);

   for(int i = -NumberOfLevelsBelow - 5; i <= NumberOfLevelsAbove + 5; i++)
   {
      ObjectDelete(0, "L_Major_" + IntegerToString(i));
      ObjectDelete(0, "L_25_" + IntegerToString(i));
      ObjectDelete(0, "L_50_" + IntegerToString(i));
      ObjectDelete(0, "L_75_" + IntegerToString(i));
   }

   for(int i = -NumberOfLevelsBelow; i <= NumberOfLevelsAbove; i++)
   {
      double majorLevel = baseLevel + (i * majorStep);
      if(majorLevel <= 0) continue;
      majorLevel = NormalizeDouble(majorLevel, digits);

      string majorName = "L_Major_" + IntegerToString(i);
      ObjectCreate(0, majorName, OBJ_TREND, 0, startTime, majorLevel, endTime, majorLevel);
      ObjectSetInteger(0, majorName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, majorName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, majorName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, majorName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, majorName, OBJPROP_RAY_LEFT, true);

      double level25 = majorLevel + quarterStep;
      if(level25 > 0)
      {
         level25 = NormalizeDouble(level25, digits);
         string name25 = "L_25_" + IntegerToString(i);
         ObjectCreate(0, name25, OBJ_TREND, 0, startTime, level25, endTime, level25);
         ObjectSetInteger(0, name25, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, name25, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name25, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name25, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, name25, OBJPROP_RAY_LEFT, true);
      }

      double level50 = majorLevel + (quarterStep * 2);
      if(level50 > 0)
      {
         level50 = NormalizeDouble(level50, digits);
         string name50 = "L_50_" + IntegerToString(i);
         ObjectCreate(0, name50, OBJ_TREND, 0, startTime, level50, endTime, level50);
         ObjectSetInteger(0, name50, OBJPROP_COLOR, clrMagenta);
         ObjectSetInteger(0, name50, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name50, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name50, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, name50, OBJPROP_RAY_LEFT, true);
      }

      double level75 = majorLevel + (quarterStep * 3);
      if(level75 > 0)
      {
         level75 = NormalizeDouble(level75, digits);
         string name75 = "L_75_" + IntegerToString(i);
         ObjectCreate(0, name75, OBJ_TREND, 0, startTime, level75, endTime, level75);
         ObjectSetInteger(0, name75, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, name75, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name75, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name75, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, name75, OBJPROP_RAY_LEFT, true);
      }
   }
}

int OnInit()
{
   ChartSetInteger(0, CHART_FOREGROUND, true);

   // Force-load history so session lookups have enough bars
   int barsNeeded = 5000;
   if(Bars(_Symbol, _Period) < barsNeeded)
   {
      datetime t0 = TimeCurrent() - (datetime)barsNeeded * PeriodSeconds(_Period);
      MqlRates rates[];
      CopyRates(_Symbol, _Period, t0, barsNeeded, rates);
   }

   if(ShowEMA)
   {
      SetIndexBuffer(0, ema14Buffer, INDICATOR_DATA);
      SetIndexBuffer(1, ema20Buffer, INDICATOR_DATA);
      SetIndexBuffer(2, ema50Buffer, INDICATOR_DATA);
      SetIndexBuffer(3, ema96Buffer, INDICATOR_DATA);
      SetIndexBuffer(4, ema200Buffer, INDICATOR_DATA);
   }

   ResetDayRanges();

   pdh = pdl = pdc = cdh = cdl = 0.0;
   fridayHigh = fridayLow = lastFridayHigh = lastFridayLow = 0.0;
   cibLevel = 0.0; showCIBLevel = false; cibLevelStartBar = -1; cibDirection = "";
   tradedAbovePDH = tradedBelowPDL = false;
   consecutiveCount = 1; lastWasHigher = false; lastPDC = 0.0;
   isFirstCount = true;
   yesterdayWasFGDSignal = yesterdayWasFRDSignal = yesterdayWas3Plus = false;
   yesterdayDirection = ""; signalDayType = ""; yesterdaySignal = "";
   isAPlusSetup = false; aPlusType = "";
   isAPlusPlusSetup = false; aPlusPlusType = "";
   is3PlusTrigger = false; threePlusType = "";
   lastEMASignal = "NONE";
   lastEMABull = false;

   GetPreviousDaysLevels();
   GetPreviousWeekLevels();
   GetPreviousMonthLevels();
   CalculateWeeklyPWC();
   DrawPWCLine();
   DrawPriceLevels();

   Print("═══════════════════════════════════════════════════════════════");
   Print("✅ Apex Grid Stacey Burke SS INDICATOR LOADED");
   Print("═══════════════════════════════════════════════════════════════");
   Print("📊 Symbol: ", _Symbol, " TF: ", EnumToString(_Period));
   Print("📋 Day 1-2-3 Panel: ", ShowDay123Panel ? "ON @ Top Right" : "OFF");
   Print("📋 Signal Table: ", ShowSignalTable ? "ON @ " + TablePosition : "OFF");
   Print("📋 Session: ", SessionStartHour, ":00 -> ", SessionEndHour, ":00 server time");
   Print("✅ PDC = BROKER D1 (23:59 close)");
   Print("✅ PDC lines: current day + last 5 past days, each starts 23:59 and stops 23:59");
   Print("📋 DebugSignalEngine: ", DebugSignalEngine ? "ON" : "OFF");
   Print("═══════════════════════════════════════════════════════════════");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0);
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   if(rates_total < 200) return(0);

   int start = (prev_calculated <= 0) ? 1 : prev_calculated;
   if(start >= rates_total) start = rates_total - 1;

   if(ShowEMA)
   {
      double ema14  = (start > 1) ? ema14Buffer[start-1]  : close[start-1];
      double ema20  = (start > 1) ? ema20Buffer[start-1]  : close[start-1];
      double ema50  = (start > 1) ? ema50Buffer[start-1]  : close[start-1];
      double ema96  = (start > 1) ? ema96Buffer[start-1]  : close[start-1];
      double ema200 = (start > 1) ? ema200Buffer[start-1] : close[start-1];

      double mult14  = 2.0 / (EMAPeriod_14  + 1);
      double mult20  = 2.0 / (EMAPeriod_20  + 1);
      double mult50  = 2.0 / (EMAPeriod_50  + 1);
      double mult96  = 2.0 / (EMAPeriod_96  + 1);
      double mult200 = 2.0 / (EMAPeriod_200 + 1);

      for(int i = start; i < rates_total; i++)
      {
         ema14  = close[i] * mult14  + ema14  * (1 - mult14);
         ema20  = close[i] * mult20  + ema20  * (1 - mult20);
         ema50  = close[i] * mult50  + ema50  * (1 - mult50);
         ema96  = close[i] * mult96  + ema96  * (1 - mult96);
         ema200 = close[i] * mult200 + ema200 * (1 - mult200);

         ema14Buffer[i]  = ema14;
         ema20Buffer[i]  = ema20;
         ema50Buffer[i]  = ema50;
         ema96Buffer[i]  = ema96;
         ema200Buffer[i] = ema200;
      }
   }

   UpdateDay123Ranges(time, high, low, rates_total);

   ProcessDailySignals(rates_total, time, open, high, low, close);
   
   if(ShowEMA)
   {
      UpdateEMASignal(close, rates_total);
   }
   // EMA20 pullback style like reference
   if(rates_total >= 25 && ShowEMA)
   {
      double ema20v = ema20Buffer[rates_total-1];
      double ema20v1 = ema20Buffer[rates_total-2];
      if(ema20v > 0 && ema20v1 > 0)
      {
         static int emaTrendArr[10];
         static int emaTrend = 0;
         if(close[rates_total-1] > ema20v && close[rates_total-2] <= ema20v1)
            emaTrend = 1;
         if(close[rates_total-1] < ema20v && close[rates_total-2] >= ema20v1)
            emaTrend = -1;
         if(emaTrend == 1 && close[rates_total-1] > ema20v && close[rates_total-2] > ema20v)
         {
            if(low[rates_total-1] <= ema20v && close[rates_total-1] > ema20v)
               lastEMASignal = "BUY";
         }
         if(emaTrend == -1 && close[rates_total-1] < ema20v && close[rates_total-2] < ema20v)
         {
            if(high[rates_total-1] >= ema20v && close[rates_total-1] < ema20v)
               lastEMASignal = "SELL";
         }
      }
   }

   datetime currentSess = GetSessionDate(TimeCurrent());

   bool isNewBar = (time[rates_total-1] != lastBarTime);
   if(isNewBar)
   {
      lastBarTime = time[rates_total-1];

      if(currentSess != lastDailyCalc)
      {
         lastDailyCalc = currentSess;
         GetPreviousDaysLevels();
         DrawPreviousDaysLevels();
      }
      else
      {
         DrawPreviousDaysLevels();
      }

      MqlDateTime dt;
      TimeToStruct(currentSess, dt);
      if(dt.day_of_week == 1 && currentSess != lastWeeklyCalc)
      {
         lastWeeklyCalc = currentSess;
         GetPreviousWeekLevels();
         DrawPreviousWeekLevels();
         UpdatePWC();
      }

      if(dt.mon != lastMonthlyCalc)
      {
         lastMonthlyCalc = dt.mon;
         GetPreviousMonthLevels();
         DrawPreviousMonthLevels();
      }

      DrawPriceLevels();
   }

   if(ShowDay123Panel) DrawDay123Panel();
   if(ShowSignalTable) DrawSignalTable();

   if(currentSess != lastDayStart)
   {
      lastDayStart = currentSess;
      hodlodLocked = false;
      hod = 0;
      lod = 0;
      runningHod = 0;
      runningLod = DBL_MAX;

      datetime sessStart = SessionStartTime(currentSess);
      datetime sessEnd   = SessionEndTime(currentSess);

      for(int i = rates_total-1; i >= 0; i--)
      {
         if(time[i] >= sessStart && time[i] < sessEnd)
         {
            if(runningHod == 0) runningHod = open[i];
            if(runningLod == DBL_MAX) runningLod = open[i];
            if(high[i] > runningHod) runningHod = high[i];
            if(low[i] < runningLod) runningLod = low[i];
         }
         else if(time[i] < sessStart) break;
      }
   }
   else if(isNewBar && !hodlodLocked)
   {
      datetime sessStart = SessionStartTime(currentSess);
      datetime sessEnd   = SessionEndTime(currentSess);

      if(time[rates_total-1] >= sessStart && time[rates_total-1] < sessEnd)
      {
         if(high[rates_total-1] > runningHod) runningHod = high[rates_total-1];
         if(low[rates_total-1] < runningLod) runningLod = low[rates_total-1];
      }
   }

   MqlDateTime currentTime;
   TimeToStruct(time[rates_total-1], currentTime);
   int currentMinutes = currentTime.hour * 60 + currentTime.min;
   int lockMinutes = InpLockEndHour * 60 + InpLockEndMinute;

   if(currentMinutes >= lockMinutes && !hodlodLocked && DrawHODLODLines)
   {
      hod = runningHod;
      lod = runningLod;
      hodlodLocked = true;

      string hodLine = "HOD_Line";
      string lodLine = "LOD_Line";
      datetime endTime = SessionEndTime(currentSess);

      ObjectDelete(0, hodLine);
      ObjectCreate(0, hodLine, OBJ_TREND, 0, SessionStartTime(currentSess), hod, endTime, hod);
      ObjectSetInteger(0, hodLine, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, hodLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, hodLine, OBJPROP_RAY_RIGHT, true);

      ObjectDelete(0, lodLine);
      ObjectCreate(0, lodLine, OBJ_TREND, 0, SessionStartTime(currentSess), lod, endTime, lod);
      ObjectSetInteger(0, lodLine, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, lodLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lodLine, OBJPROP_RAY_RIGHT, true);
   }
   else if(!hodlodLocked)
   {
      hod = runningHod;
      lod = runningLod;
   }

   ChartRedraw();
   return(rates_total);
}
