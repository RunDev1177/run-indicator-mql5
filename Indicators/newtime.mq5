//+------------------------------------------------------------------+
//|                                                      newtime.mq5 |
//|                                  Copyright 2026, Gemini AI Tutor |
//+------------------------------------------------------------------+
#property copyright "Gemini AI"
#property indicator_chart_window
#property indicator_plots 0

// --- Enum สำหรับเลือกตำแหน่งมุม ---
enum ENUM_CORNER_POS
{
   CORNER_LEFT_UPPER_POS  = CORNER_LEFT_UPPER,  // ซ้ายบน
   CORNER_RIGHT_UPPER_POS = CORNER_RIGHT_UPPER, // ขวาบน
   CORNER_LEFT_LOWER_POS  = CORNER_LEFT_LOWER,  // ซ้ายล่าง
   CORNER_RIGHT_LOWER_POS = CORNER_RIGHT_LOWER  // ขวาล่าง
};

// --- Input settings ---
input ENUM_CORNER_POS InpCorner      = CORNER_LEFT_LOWER_POS; // เลือกตำแหน่งมุม
input int             InpHoursOffset = 4;       // ปรับเวลา Server เป็นเวลาไทย
input int             InpFontSize    = 10;      // ขนาดตัวอักษร
input int             InpXDistance   = 300;      // ระยะห่างจากขอบซ้าย/ขวา
input int             InpYBase       = 25;      // ระยะห่างจากขอบบน/ล่าง
input int             InpLineSpacing = 18;      // ระยะห่างระหว่างบรรทัด

// --- กรองระดับความสำคัญของข่าว ---
input bool     ShowHigh   = true;        // แสดงข่าวสีแดง (High)
input bool     ShowMedium = false;        // แสดงข่าวสีส้ม (Medium)
input bool     ShowLow    = false;       // แสดงข่าวสีเหลือง (Low)
input bool     ShowNone   = false;       // แสดงข่าวสีเทา (None)

// --- กำหนดสี ---
input color    ColorHigh  = clrRed;
input color    ColorMed   = clrOrange;
input color    ColorLow   = clrYellow;
input color    ColorNone  = clrLightGray;

struct NewsData
{
   datetime time;
   string   currency;
   string   event_desc;
   color    event_color;
};

NewsData today_news[];

//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(300); 
   GetTodayNews();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { ObjectsDeleteAll(0, "news_"); EventKillTimer(); }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[])
{
   DisplayNews();
   return(rates_total);
}

void OnTimer() { GetTodayNews(); ChartRedraw(); }

//+------------------------------------------------------------------+
void GetTodayNews()
{
   datetime start = iTime(_Symbol, PERIOD_D1, 0); 
   datetime end   = start + 86400;                
   MqlCalendarValue values[];
   string curr1 = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string curr2 = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   
   ArrayFree(today_news);

   if(CalendarValueHistory(values, start, end))
   {
      for(int i=0; i<ArraySize(values); i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            bool skip = true;
            color item_color = clrWhite;

            if(event.importance == CALENDAR_IMPORTANCE_HIGH && ShowHigh) { skip = false; item_color = ColorHigh; }
            else if(event.importance == CALENDAR_IMPORTANCE_MODERATE && ShowMedium) { skip = false; item_color = ColorMed; }
            else if(event.importance == CALENDAR_IMPORTANCE_LOW && ShowLow) { skip = false; item_color = ColorLow; }
            else if(event.importance == CALENDAR_IMPORTANCE_NONE && ShowNone) { skip = false; item_color = ColorNone; }

            if(!skip)
            {
               MqlCalendarCountry country;
               if(CalendarCountryById(event.country_id, country))
               {
                  if(country.currency == curr1 || country.currency == curr2)
                  {
                     int size = ArraySize(today_news);
                     ArrayResize(today_news, size + 1);
                     today_news[size].time        = values[i].time;
                     today_news[size].currency    = country.currency;
                     today_news[size].event_desc  = event.name;
                     today_news[size].event_color = item_color;
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void DisplayNews()
{
   ObjectsDeleteAll(0, "news_");
   
   int current_y = InpYBase;
   int direction = 1; // 1 = เลื่อนขึ้น, -1 = เลื่อนลง
   
   // ถ้าเลือกตำแหน่งมุมบน ให้เรียงข่าวลงมาข้างล่าง
   if(InpCorner == CORNER_LEFT_UPPER_POS || InpCorner == CORNER_RIGHT_UPPER_POS)
      direction = 1; 
   else // ถ้าเลือกตำแหน่งมุมล่าง ให้เรียงข่าวขึ้นไปข้างบน
      direction = 1;

   // กรณีไม่มีข่าว
   if(ArraySize(today_news) == 0)
   {
      CreateLabel("news_none", "-- Today NEWS: No News Found --", InpXDistance, current_y, clrGray);
      return;
   }

   // วนลูปแสดงข่าว (ถ้ามุมล่างให้เรียงจากท้ายมาหน้าเพื่อให้ข่าวล่าสุดอยู่ล่างสุด)
   for(int i = 0; i < ArraySize(today_news); i++)
   {
      datetime thai_time = today_news[i].time + (InpHoursOffset * 3600);
      string time_str = TimeToString(thai_time, TIME_MINUTES);
      string msg = StringFormat("[%s] %s: %s", time_str, today_news[i].currency, today_news[i].event_desc);
      
      CreateLabel("news_item_" + (string)i, msg, InpXDistance, current_y, today_news[i].event_color);
      current_y += InpLineSpacing;
   }

   // แสดงหัวข้อไว้บรรทัดสุดท้าย (หรือบนสุดของกลุ่มข่าว)
   CreateLabel("news_header", "-- Today NEWS --", InpXDistance, current_y, clrCyan);
}

// ฟังก์ชันสร้าง Label แบบยืดหยุ่นมุม
void CreateLabel(string name, string text, int x, int y, color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, (int)InpCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   
   // ถ้าอยู่มุมขวา ให้จัดข้อความชิดขวา
   if(InpCorner == CORNER_RIGHT_UPPER_POS || InpCorner == CORNER_RIGHT_LOWER_POS)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   else
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
}