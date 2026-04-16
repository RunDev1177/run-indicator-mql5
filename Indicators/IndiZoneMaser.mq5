//+------------------------------------------------------------------+
//|                                                   ZoneMaster.mq5 |
//|                                  Copyright 2024, Gemini AI User  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.20"
#property indicator_chart_window
#property indicator_plots 0

// เรียกใช้ Library สำหรับจัดการ Object และ Array
#include <Arrays\ArrayObj.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

//--- Input Parameters
input int      InpMaxBase      = 7;        // Max Base Candles (จำนวนแท่ง Base สูงสุด)
input color    InpDemandColor  = clrGreen;  // Demand Zone Color
input color    InpSupplyColor  = clrRed;    // Supply Zone Color
input int      InpZoneAlpha    = 80;       // Zone Transparency (0-255)

// Timeframe Filter
input bool     InpM1           = false;    // TF M1
input bool     InpM5           = false;    // TF M5
input bool     InpM15          = false;    // TF M15
input bool     InpM30          = false;    // TF M30
input bool     InpH1           = true;     // TF H1
input bool     InpH4           = true;     // TF H4
input bool     InpD1           = true;     // TF D1

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // ตรวจสอบเงื่อนไข Timeframe
   ENUM_TIMEFRAMES currentTF = _Period;
   bool canRun = false;
   
   if(currentTF == PERIOD_M1 && InpM1) canRun = true;
   else if(currentTF == PERIOD_M5 && InpM5) canRun = true;
   else if(currentTF == PERIOD_M15 && InpM15) canRun = true;
   else if(currentTF == PERIOD_M30 && InpM30) canRun = true;
   else if(currentTF == PERIOD_H1 && InpH1) canRun = true;
   else if(currentTF == PERIOD_H4 && InpH4) canRun = true;
   else if(currentTF == PERIOD_D1 && InpD1) canRun = true;
   
   // ถ้าเป็น Timeframe อื่นๆ ที่ไม่ได้ระบุ ให้ยอมรับถ้าไม่ได้ปิดไว้ทั้งหมด
   if(!InpM1 && !InpM5 && !InpM15 && !InpM30 && !InpH1 && !InpH4 && !InpD1) canRun = true;

   if(!canRun) {
      Print("ZoneMaster: This timeframe is disabled in settings.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "ZoneMaster");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "ZM_");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &spread[],
                const long &real_volume[])
{
   // เช็คจำนวนแท่งเทียนขั้นต่ำ
   if(rates_total < InpMaxBase + 10) return(0);

   // กำหนดขอบเขตการคำนวณ (ใช้ i เป็น index 0 คือแท่งเก่าสุด)
   int start = prev_calculated - 1;
   if(start < InpMaxBase + 1) start = InpMaxBase + 1;

   for(int i = start; i < rates_total - 1; i++)
   {
      // 1. ตรวจสอบ Imbalance (แท่ง i คือแท่งที่พุ่งออกมา)
      double body = MathAbs(close[i] - open[i]);
      double avg_body = 0;
      int count_avg = 0;
      for(int k=1; k<=5 && (i-k)>=0; k++) {
         avg_body += MathAbs(close[i-k] - open[i-k]);
         count_avg++;
      }
      if(count_avg > 0) avg_body /= count_avg;

      // เงื่อนไข Imbalance (แรงขับเคลื่อนราคาแรงกว่าปกติ)
      if(body > avg_body * 1.8) 
      {
         bool is_bullish = (close[i] > open[i]);
         int base_count = 0;
         int first_base_idx = -1;

         // 2. ค้นหา Base Candles ย้อนหลังจากแท่งก่อนหน้า (i-1)
         for(int j = i - 1; j >= i - InpMaxBase && j >= 0; j--)
         {
            double b_body = MathAbs(close[j] - open[j]);
            double b_range = high[j] - low[j];
            if(b_range <= 0) b_range = _Point;
            
            // นิยาม Base: เนื้อเทียนไม่เกิน 60% ของความยาวทั้งหมด
            if(b_body <= b_range * 0.6) {
               base_count++;
               first_base_idx = j;
            } else break;
         }

         // 3. วาดโซน
         if(base_count > 0 && base_count <= InpMaxBase)
         {
            double z_high = 0, z_low = 0;
            if(is_bullish) // Demand (Rally-Base-Rally หรือ Drop-Base-Rally)
            {
               z_high = -1; z_low = 9999999;
               for(int z = i-1; z >= first_base_idx; z--) {
                  z_high = MathMax(z_high, MathMax(open[z], close[z])); // เนื้อบน
                  z_low = MathMin(z_low, low[z]); // ไส้ล่าง
               }
               CreateZone(true, z_high, z_low, time[first_base_idx], time[i]);
            }
            else // Supply (Drop-Base-Drop หรือ Rally-Base-Drop)
            {
               z_high = -1; z_low = 9999999;
               for(int z = i-1; z >= first_base_idx; z--) {
                  z_high = MathMax(z_high, high[z]); // ไส้บน
                  z_low = MathMin(z_low, MathMin(open[z], close[z])); // เนื้อล่าง
               }
               CreateZone(false, z_high, z_low, time[first_base_idx], time[i]);
            }
         }
      }
   }

   // ตรวจสอบการ Retest หรือ Break ในแท่งล่าสุดเสมอ
   if(rates_total > 0)
      UpdateZones(close[rates_total-1], high[rates_total-1], low[rates_total-1], time[rates_total-1]);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| ฟังก์ชันสร้างโซน                                                   |
//+------------------------------------------------------------------+
void CreateZone(bool is_demand, double high, double low, datetime startT, datetime imbalanceT)
{
   string name = "ZM_" + TimeToString(startT, TIME_DATE|TIME_MINUTES) + (is_demand ? "_D" : "_S");
   if(ObjectFind(0, name) >= 0) return;

   // สร้างสี่เหลี่ยมโซน
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, startT, high, imbalanceT + PeriodSeconds()*50, low)) return;
   
   color col = is_demand ? InpDemandColor : InpSupplyColor;
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| ฟังก์ชันอัปเดตและลบโซน (Retest/Broken)                             |
//+------------------------------------------------------------------+
void UpdateZones(double c_price, double h_price, double l_price, datetime c_time)
{
   for(int i = ObjectsTotal(0, -1, OBJ_RECTANGLE) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, OBJ_RECTANGLE);
      if(StringFind(name, "ZM_") < 0) continue;

      double z_high = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double z_low = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      bool is_demand = (StringFind(name, "_D") > 0);

      // 1. ตรวจสอบการทำลายโซน (Broken) -> ลบโซน
      if((is_demand && c_price < z_low) || (!is_demand && c_price > z_high))
      {
         ObjectDelete(0, name);
         continue;
      }

      // 2. ตรวจสอบการ Retest (ราคามาแตะขอบโซน)
      bool retested = false;
      if(is_demand) {
         if(l_price <= z_high && l_price >= z_low) retested = true;
      } else {
         if(h_price >= z_low && h_price <= z_high) retested = true;
      }

      if(retested)
      {
         // เปลี่ยนสไตล์โซนที่ถูกทดสอบแล้ว (สีอ่อนลงโดยการปิด Fill และใช้เส้นประ)
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name, OBJPROP_FILL, false);
         
         static datetime lastAlertTime = 0;
         if(c_time != lastAlertTime) {
            SendTradeAlert(is_demand, z_high, z_low);
            lastAlertTime = c_time;
         }
      }
      
      // ขยายเส้นโซนไปทางขวาให้ตามราคาปัจจุบัน
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, c_time + PeriodSeconds()*10);
   }
}

//+------------------------------------------------------------------+
//| แจ้งเตือน และคำนวณ RR 1.5                                          |
//+------------------------------------------------------------------+
void SendTradeAlert(bool is_demand, double z_high, double z_low)
{
   string type = is_demand ? "DEMAND (BUY)" : "SUPPLY (SELL)";
   double entry = is_demand ? z_high : z_low;
   double sl = is_demand ? z_low : z_high;
   double risk = MathAbs(entry - sl);
   if(risk <= 0) risk = _Point * 20; // ค่าเผื่อกรณีโซนแคบเกินไป
   
   double tp = is_demand ? entry + (risk * 1.5) : entry - (risk * 1.5);
   
   string msg = StringFormat("ZoneMaster Entry!\nType: %s\nEntry: %G\nSL: %G\nTP (RR1.5): %G", 
                             type, entry, sl, tp);
   
   Alert(msg);
   Print(msg);
}