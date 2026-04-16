//+------------------------------------------------------------------+
//|                                                    autoDzSzi.mq5 |
//|                          Auto Demand & Supply Zone Indicator     |
//|                          Looks back 2000 bars                    |
//+------------------------------------------------------------------+
#property copyright   "autoDzSzi"
#property version     "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input Parameters
input int    InpLookback      = 2000;    // จำนวนแท่งย้อนหลัง
input int    InpSwingStrength = 3;       // ความแข็งแกร่งของ Swing (แท่งข้างละกี่แท่ง)
input int    InpZoneWidth     = 5;       // ความกว้างของโซน (แท่ง)
input color  InpDemandColor   = clrGreen;  // สีโซน Demand
input color  InpSupplyColor   = clrRed;    // สีโซน Supply
input int    InpMaxZones      = 50;      // จำนวนโซนสูงสุด
input bool   InpShowInvalid   = false;   // แสดงโซนที่ถูก break แล้ว
input int    InpTransparency  = 70;      // ความโปร่งใส (0=ทึบ, 100=ใส)

//--- Global Variables
string g_prefix = "autoDzSzi_";
int    g_demand_count = 0;
int    g_supply_count = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // ลบ object เก่าทั้งหมด
   DeleteAllObjects();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // คำนวณใหม่เมื่อมีแท่งใหม่
   if(rates_total < InpSwingStrength * 2 + 1)
      return(rates_total);

   // ลบ object เก่าก่อนวาดใหม่
   DeleteAllObjects();
   g_demand_count = 0;
   g_supply_count = 0;

   // กำหนด start bar
   int start = MathMax(InpSwingStrength, rates_total - InpLookback);
   int end   = rates_total - InpSwingStrength - 1;

   // วนหา Swing High / Swing Low
   for(int i = end; i >= start && g_demand_count + g_supply_count < InpMaxZones * 2; i--)
   {
      //--- ตรวจ Swing Low (Demand)
      if(IsSwingLow(low, i, InpSwingStrength, rates_total))
      {
         double zone_top    = open[i] > close[i] ? open[i] : close[i];  // ด้านบนของ candle body
         double zone_bottom = open[i] < close[i] ? open[i] : close[i];  // ด้านล่างของ candle body

         // ถ้า body เล็กมาก ใช้ wick แทน
         if(MathAbs(zone_top - zone_bottom) < _Point * 5)
         {
            zone_top    = high[i];
            zone_bottom = low[i];
         }

         bool is_broken = IsZoneBroken(zone_top, zone_bottom, i, rates_total, low, close, true);

         if(!is_broken || InpShowInvalid)
         {
            color zone_color = is_broken ? clrDarkGreen : InpDemandColor;
            DrawZone("D_" + IntegerToString(i), time[i], zone_top, zone_bottom,
                     zone_color, is_broken, rates_total, time);
            g_demand_count++;
         }
      }

      //--- ตรวจ Swing High (Supply)
      if(IsSwingHigh(high, i, InpSwingStrength, rates_total))
      {
         double zone_top    = open[i] > close[i] ? open[i] : close[i];
         double zone_bottom = open[i] < close[i] ? open[i] : close[i];

         if(MathAbs(zone_top - zone_bottom) < _Point * 5)
         {
            zone_top    = high[i];
            zone_bottom = low[i];
         }

         bool is_broken = IsZoneBroken(zone_top, zone_bottom, i, rates_total, high, close, false);

         if(!is_broken || InpShowInvalid)
         {
            color zone_color = is_broken ? clrDarkRed : InpSupplyColor;
            DrawZone("S_" + IntegerToString(i), time[i], zone_top, zone_bottom,
                     zone_color, is_broken, rates_total, time);
            g_supply_count++;
         }
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| ตรวจสอบ Swing Low                                                |
//+------------------------------------------------------------------+
bool IsSwingLow(const double &low[], int bar, int strength, int total)
{
   if(bar - strength < 0 || bar + strength >= total)
      return false;

   for(int j = 1; j <= strength; j++)
   {
      if(low[bar] >= low[bar - j]) return false;
      if(low[bar] >= low[bar + j]) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| ตรวจสอบ Swing High                                               |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &high[], int bar, int strength, int total)
{
   if(bar - strength < 0 || bar + strength >= total)
      return false;

   for(int j = 1; j <= strength; j++)
   {
      if(high[bar] <= high[bar - j]) return false;
      if(high[bar] <= high[bar + j]) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| ตรวจสอบว่าโซนถูก break แล้วหรือยัง                              |
//+------------------------------------------------------------------+
bool IsZoneBroken(double zone_top, double zone_bottom, int bar_idx,
                  int total, const double &price[], const double &close[],
                  bool is_demand)
{
   for(int k = bar_idx - 1; k >= 0; k--)
   {
      if(is_demand)
      {
         // Demand ถูก break เมื่อราคา close ต่ำกว่า zone_bottom
         if(close[k] < zone_bottom)
            return true;
      }
      else
      {
         // Supply ถูก break เมื่อราคา close สูงกว่า zone_top
         if(close[k] > zone_top)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| วาดโซน Demand/Supply                                             |
//+------------------------------------------------------------------+
void DrawZone(string suffix, datetime start_time, double top, double bottom,
              color clr, bool broken, int total, const datetime &time[])
{
   string obj_name = g_prefix + suffix;

   // กำหนดเวลาสิ้นสุด (แท่งล่าสุด)
   datetime end_time = time[0];

   // สร้าง Rectangle
   if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, start_time, top, end_time, bottom))
   {
      // แปลง transparency เป็น alpha (0-255)
      uchar alpha = (uchar)((100 - InpTransparency) * 255 / 100);

      // แยก RGB จาก color
      uchar r = (uchar)(clr & 0xFF);
      uchar g = (uchar)((clr >> 8) & 0xFF);
      uchar b = (uchar)((clr >> 16) & 0xFF);

      // ใช้ ColorToARGB
      color fill_color = (color)((alpha << 24) | (b << 16) | (g << 8) | r);

      ObjectSetInteger(0, obj_name, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE,     broken ? STYLE_DOT : STYLE_SOLID);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, obj_name, OBJPROP_FILL,      true);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK,      true);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTED,  false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN,    true);
      ObjectSetInteger(0, obj_name, OBJPROP_ZORDER,    0);

      // ตั้งค่าสี fill พร้อม transparency
      ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, fill_color);
   }
}

//+------------------------------------------------------------------+
//| ลบ object ทั้งหมดของ indicator นี้                               |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, g_prefix) == 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
