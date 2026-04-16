//+------------------------------------------------------------------+
//|                                                  ZoneMaster.mq5  |
//|                              Supply & Demand Zone Indicator       |
//+------------------------------------------------------------------+
#property copyright   "ZoneMaster"
#property version     "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input Parameters
input double InpRisk         = 3.0;   // Risk (%)
input int    InpMaxBase      = 7;     // Max Base Candles
input color  InpDemandColor  = clrGreen;  // Demand Zone Color
input color  InpSupplyColor  = clrRed;    // Supply Zone Color
input int    InpZoneAlpha    = 80;    // Zone Transparency (0-255)

//--- Zone Structure
struct Zone
{
   string   name;
   double   top;
   double   bottom;
   datetime timeStart;
   datetime timeEnd;
   bool     isSupply;
   bool     retested;
   bool     broken;
   int      barIndex;
};

//--- Global arrays
Zone     g_zones[];
int      g_zoneCount = 0;
datetime g_lastBar   = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllZoneObjects();
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   if(rates_total < 10) return(0);

   // ตรวจสอบว่ามีแท่งใหม่หรือไม่
   if(time[rates_total - 1] == g_lastBar && prev_calculated > 0)
   {
      // อัปเดต zone ที่ถูก retest หรือ break บนแท่งปัจจุบัน
      CheckZonesOnCurrentBar(rates_total, time, high, low, close);
      DrawAllZones(time, rates_total);
      return(rates_total);
   }
   g_lastBar = time[rates_total - 1];

   // สแกนแท่งใหม่ตั้งแต่แท่งที่ยังไม่ได้ประมวลผล
   int startBar = (prev_calculated < 3) ? 3 : prev_calculated - 1;

   for(int i = startBar; i < rates_total - 1; i++)
   {
      // ตรวจจับ Imbalance (Bullish) → Demand Zone
      if(IsImbalanceBullish(i, open, high, low, close))
      {
         FindAndAddDemandZone(i, rates_total, time, open, high, low, close);
      }

      // ตรวจจับ Imbalance (Bearish) → Supply Zone
      if(IsImbalanceBearish(i, open, high, low, close))
      {
         FindAndAddSupplyZone(i, rates_total, time, open, high, low, close);
      }
   }

   CheckZonesOnCurrentBar(rates_total, time, high, low, close);
   DrawAllZones(time, rates_total);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| ตรวจสอบ Bullish Imbalance (Gap Up)                               |
//| เกิดเมื่อ low[i] > high[i-2]                                     |
//+------------------------------------------------------------------+
bool IsImbalanceBullish(int i, const double &open[], const double &high[],
                        const double &low[], const double &close[])
{
   if(i < 2) return(false);
   // Bullish imbalance: low ของแท่งกลาง[i] สูงกว่า high ของแท่ง[i-2]
   return(low[i] > high[i - 2] && close[i] > open[i]);
}

//+------------------------------------------------------------------+
//| ตรวจสอบ Bearish Imbalance (Gap Down)                             |
//| เกิดเมื่อ high[i] < low[i-2]                                     |
//+------------------------------------------------------------------+
bool IsImbalanceBearish(int i, const double &open[], const double &high[],
                        const double &low[], const double &close[])
{
   if(i < 2) return(false);
   // Bearish imbalance: high ของแท่งกลาง[i] ต่ำกว่า low ของแท่ง[i-2]
   return(high[i] < low[i - 2] && close[i] < open[i]);
}

//+------------------------------------------------------------------+
//| หา Demand Zone จาก Bullish Imbalance                             |
//| ย้อนกลับจาก imbalance candle หา Base (ไม่เกิน InpMaxBase แท่ง)  |
//| Zone = Low ของ base ต่ำสุด → Body สูงสุดของ base                 |
//+------------------------------------------------------------------+
void FindAndAddDemandZone(int imbalanceBar, int rates_total,
                          const datetime &time[],
                          const double &open[], const double &high[],
                          const double &low[], const double &close[])
{
   // ย้อนหลังจาก imbalanceBar-1 (แท่งก่อนหน้า imbalance)
   int startSearch = imbalanceBar - 1;
   int endSearch   = MathMax(0, imbalanceBar - 1 - InpMaxBase);

   if(startSearch < 0) return;

   double zoneBottom = DBL_MAX;
   double zoneTop    = -DBL_MAX;
   int    baseStart  = startSearch;

   for(int j = startSearch; j >= endSearch; j--)
   {
      double bodyHigh = MathMax(open[j], close[j]);
      double bodyLow  = MathMin(open[j], close[j]);

      // Base candle: แท่งที่ไม่ใช่ strong bullish/bearish (candle kecil/sideways)
      // ใช้เกณฑ์ body < range * 0.5
      double candleRange = high[j] - low[j];
      double bodySize    = MathAbs(close[j] - open[j]);

      if(candleRange > 0 && bodySize / candleRange > 0.6 && j < startSearch)
         break; // พบแท่ง impulsive หยุดการค้นหา base

      zoneBottom = MathMin(zoneBottom, low[j]);
      zoneTop    = MathMax(zoneTop, bodyHigh);
      baseStart  = j;
   }

   if(zoneBottom == DBL_MAX || zoneTop == -DBL_MAX) return;
   if(zoneTop <= zoneBottom) return;

   // ตรวจสอบว่ามี zone ใกล้เคียงอยู่แล้วหรือไม่
   if(ZoneExists(zoneBottom, zoneTop, false)) return;

   // เพิ่ม zone ใหม่
   Zone z;
   z.name      = "DZ_" + IntegerToString(imbalanceBar) + "_" + IntegerToString((int)time[imbalanceBar]);
   z.top       = zoneTop;
   z.bottom    = zoneBottom;
   z.timeStart = time[baseStart];
   z.timeEnd   = 0;
   z.isSupply  = false;
   z.retested  = false;
   z.broken    = false;
   z.barIndex  = imbalanceBar;

   AddZone(z);
}

//+------------------------------------------------------------------+
//| หา Supply Zone จาก Bearish Imbalance                             |
//+------------------------------------------------------------------+
void FindAndAddSupplyZone(int imbalanceBar, int rates_total,
                          const datetime &time[],
                          const double &open[], const double &high[],
                          const double &low[], const double &close[])
{
   int startSearch = imbalanceBar - 1;
   int endSearch   = MathMax(0, imbalanceBar - 1 - InpMaxBase);

   if(startSearch < 0) return;

   double zoneBottom = DBL_MAX;
   double zoneTop    = -DBL_MAX;
   int    baseStart  = startSearch;

   for(int j = startSearch; j >= endSearch; j--)
   {
      double bodyHigh = MathMax(open[j], close[j]);
      double bodyLow  = MathMin(open[j], close[j]);

      double candleRange = high[j] - low[j];
      double bodySize    = MathAbs(close[j] - open[j]);

      if(candleRange > 0 && bodySize / candleRange > 0.6 && j < startSearch)
         break;

      zoneTop    = MathMax(zoneTop, high[j]);
      zoneBottom = MathMin(zoneBottom, bodyLow);
      baseStart  = j;
   }

   if(zoneBottom == DBL_MAX || zoneTop == -DBL_MAX) return;
   if(zoneTop <= zoneBottom) return;

   if(ZoneExists(zoneBottom, zoneTop, true)) return;

   Zone z;
   z.name      = "SZ_" + IntegerToString(imbalanceBar) + "_" + IntegerToString((int)time[imbalanceBar]);
   z.top       = zoneTop;
   z.bottom    = zoneBottom;
   z.timeStart = time[baseStart];
   z.timeEnd   = 0;
   z.isSupply  = true;
   z.retested  = false;
   z.broken    = false;
   z.barIndex  = imbalanceBar;

   AddZone(z);
}

//+------------------------------------------------------------------+
//| ตรวจสอบว่า zone คล้ายกันมีอยู่แล้วหรือไม่                       |
//+------------------------------------------------------------------+
bool ZoneExists(double bottom, double top, bool isSupply)
{
   double tolerance = (top - bottom) * 0.5;
   for(int i = 0; i < g_zoneCount; i++)
   {
      if(g_zones[i].isSupply != isSupply) continue;
      if(g_zones[i].broken) continue;
      if(MathAbs(g_zones[i].bottom - bottom) < tolerance &&
         MathAbs(g_zones[i].top - top) < tolerance)
         return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| เพิ่ม zone เข้า array                                            |
//+------------------------------------------------------------------+
void AddZone(Zone &z)
{
   ArrayResize(g_zones, g_zoneCount + 1);
   g_zones[g_zoneCount] = z;
   g_zoneCount++;
}

//+------------------------------------------------------------------+
//| ตรวจสอบ zone ทั้งหมดกับแท่งปัจจุบัน                             |
//+------------------------------------------------------------------+
void CheckZonesOnCurrentBar(int rates_total,
                            const datetime &time[],
                            const double   &high[],
                            const double   &low[],
                            const double   &close[])
{
   int currentBar = rates_total - 1;
   double currentHigh  = high[currentBar];
   double currentLow   = low[currentBar];
   double currentClose = close[currentBar];

   for(int i = 0; i < g_zoneCount; i++)
   {
      if(g_zones[i].broken) continue;

      bool insideZone = (currentLow <= g_zones[i].top && currentHigh >= g_zones[i].bottom);

      if(g_zones[i].isSupply)
      {
         // Supply: ราคาขึ้นมาในโซน = retest
         // ราคาปิดเหนือ top = broken
         if(currentClose > g_zones[i].top)
         {
            g_zones[i].broken   = true;
            g_zones[i].timeEnd  = time[currentBar];
         }
         else if(insideZone && !g_zones[i].retested)
         {
            g_zones[i].retested = true;
         }
      }
      else
      {
         // Demand: ราคาลงมาในโซน = retest
         // ราคาปิดต่ำกว่า bottom = broken
         if(currentClose < g_zones[i].bottom)
         {
            g_zones[i].broken   = true;
            g_zones[i].timeEnd  = time[currentBar];
         }
         else if(insideZone && !g_zones[i].retested)
         {
            g_zones[i].retested = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| วาด zone ทั้งหมด                                                 |
//+------------------------------------------------------------------+
void DrawAllZones(const datetime &time[], int rates_total)
{
   // ลบ object เก่าก่อน
   DeleteAllZoneObjects();

   datetime futureTime = time[rates_total - 1] + PeriodSeconds() * 20;

   for(int i = 0; i < g_zoneCount; i++)
   {
      if(g_zones[i].broken) continue;

      color zoneColor;

      if(g_zones[i].isSupply)
      {
         zoneColor = g_zones[i].retested ? AdjustColorBrightness(InpSupplyColor, 160) : InpSupplyColor;
      }
      else
      {
         zoneColor = g_zones[i].retested ? AdjustColorBrightness(InpDemandColor, 160) : InpDemandColor;
      }

      datetime endTime = (g_zones[i].timeEnd != 0) ? g_zones[i].timeEnd : futureTime;

      DrawZoneRectangle(g_zones[i].name,
                        g_zones[i].timeStart,
                        endTime,
                        g_zones[i].top,
                        g_zones[i].bottom,
                        zoneColor,
                        InpZoneAlpha);
   }
}

//+------------------------------------------------------------------+
//| วาด Rectangle สำหรับ zone                                        |
//+------------------------------------------------------------------+
void DrawZoneRectangle(string name, datetime t1, datetime t2,
                       double top, double bottom,
                       color clr, int alpha)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, top, t2, bottom);
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
      ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
      ObjectSetDouble(0,  name, OBJPROP_PRICE, 0, top);
      ObjectSetDouble(0,  name, OBJPROP_PRICE, 1, bottom);
   }

   // Blend color กับพื้นหลังดำโดยใช้ alpha (แทนการใช้ OBJPROP_TRANSPARENCY ที่ไม่มีใน MQL5)
   int r = (int)(clr & 0xFF);
   int g = (int)((clr >> 8) & 0xFF);
   int b = (int)((clr >> 16) & 0xFF);
   double ratio = (double)alpha / 255.0;
   r = (int)(r * ratio);
   g = (int)(g * ratio);
   b = (int)(b * ratio);
   color blendedColor = (color)(r | (g << 8) | (b << 16));

   ObjectSetInteger(0, name, OBJPROP_COLOR,      blendedColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, name, OBJPROP_FILL,       true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
}

//+------------------------------------------------------------------+
//| ปรับความสว่างของสี (สำหรับ retested zone)                       |
//+------------------------------------------------------------------+
color AdjustColorBrightness(color clr, int blendValue)
{
   int r = (int)(clr & 0xFF);
   int g = (int)((clr >> 8) & 0xFF);
   int b = (int)((clr >> 16) & 0xFF);

   // blend กับสีขาว
   r = r + (int)((255 - r) * blendValue / 255.0);
   g = g + (int)((255 - g) * blendValue / 255.0);
   b = b + (int)((255 - b) * blendValue / 255.0);

   return((color)(r | (g << 8) | (b << 16)));
}

//+------------------------------------------------------------------+
//| ลบ object ทั้งหมดของ indicator                                   |
//+------------------------------------------------------------------+
void DeleteAllZoneObjects()
{
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(objName, "DZ_") == 0 || StringFind(objName, "SZ_") == 0)
         ObjectDelete(0, objName);
   }
}

//+------------------------------------------------------------------+
//| Calculate Risk-based Lot Size (เพื่อใช้งานภายนอกหากต้องการ)     |
//+------------------------------------------------------------------+
double CalcLotSize(double entryPrice, double stopLoss)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount     = accountBalance * InpRisk / 100.0;
   double tickValue      = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize       = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double priceDiff      = MathAbs(entryPrice - stopLoss);

   if(priceDiff <= 0 || tickSize <= 0 || tickValue <= 0) return(0);

   double lotSize = riskAmount / (priceDiff / tickSize * tickValue);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   return(lotSize);
}
//+------------------------------------------------------------------+