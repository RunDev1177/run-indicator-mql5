//+------------------------------------------------------------------+
//|                                           CalculateLotSizeV4.mq5 |
//|                                  Copyright 2024, Gemini AI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini AI Agent"
#property link      "https://www.mql5.com"
#property version   "4.30"
#property indicator_chart_window

#include <Trade\Trade.mqh>

//--- input parameters
input double   InpRisk     = 100.0; // Risk (USD)
input int      InpSLPoint  = 100;   // SL Point (จุด)
input double   InpRR       = 1.0;   // RR Ratio

//--- UI Customization Inputs
input int      InpObjWidth = 200;          // Width of UI
input int      InpObjHeight = 25;          // Height of each row
input int      InpStartX   = 20;           // X Position (Pixels)
input int      InpStartY   = 60;           // Y Position (Pixels)
input color    InpBGColor  = clrRoyalBlue; // Background Color
input color    InpTextColor = clrWhite;    // Text Color

//--- Global Variables
CTrade         trade;
int            obj_width = InpObjWidth;
int            obj_height = InpObjHeight;
int            start_x = InpStartX;
int            start_y = InpStartY;
color          bg_color = InpBGColor;
color          text_color = InpTextColor;

//--- UI Objects Names
string prefix = "CalcLotV4_";

//+------------------------------------------------------------------+
//| ฟังก์ชันสร้าง Label แบบแก้ไขได้/ไม่ได้                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int width, bool readonly=true) {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
      
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, obj_height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, readonly ? text_color : clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, readonly ? bg_color : clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_READONLY, readonly);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateButton(string name, string text, int x, int y, int width, color btn_color) {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, obj_height + 5);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, btn_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_STATE, false); // รีเซ็ตสถานะปุ่ม
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // อัปเดตค่าจาก input มายังตัวแปร global
   obj_width = InpObjWidth;
   obj_height = InpObjHeight;
   start_x = InpStartX;
   start_y = InpStartY;
   bg_color = InpBGColor;
   text_color = InpTextColor;

   EventSetTimer(1);
   DrawUI();
   ChartRedraw();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, prefix);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| วาดหน้าจอ UI                                                     |
//+------------------------------------------------------------------+
void DrawUI() {
   int y = start_y;
   
   CreateLabel(prefix+"L_Balance", "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), start_x, y, obj_width); y+=obj_height+2;
   CreateLabel(prefix+"L_Spread", "Spread: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)), start_x, y, obj_width); y+=obj_height+2;
   CreateLabel(prefix+"L_Product", "Product: " + _Symbol, start_x, y, obj_width); y+=obj_height+10;
   
   CreateButton(prefix+"BTN_Type", "BUY", start_x, y, obj_width, clrDarkOrange); y+=obj_height+10;
   
   CreateLabel(prefix+"T_Risk", "Risk (USD)", start_x, y, obj_width/2);
   CreateLabel(prefix+"INP_Risk", DoubleToString(InpRisk, 2), start_x + obj_width/2, y, obj_width/2, false); y+=obj_height+2;
   
   CreateLabel(prefix+"T_Entry", "Entry Price", start_x, y, obj_width/2);
   CreateLabel(prefix+"INP_Entry", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits), start_x + obj_width/2, y, obj_width/2, false); y+=obj_height+2;
   
   CreateLabel(prefix+"T_SL", "SL Point", start_x, y, obj_width/2);
   CreateLabel(prefix+"INP_SL", IntegerToString(InpSLPoint), start_x + obj_width/2, y, obj_width/2, false); y+=obj_height+2;
   
   CreateLabel(prefix+"T_RR", "RR Ratio", start_x, y, obj_width/2);
   CreateLabel(prefix+"INP_RR", DoubleToString(InpRR, 1), start_x + obj_width/2, y, obj_width/2, false); y+=obj_height+10;
   
   CreateButton(prefix+"BTN_Cal", "Calculate LotSize", start_x, y, obj_width, clrBlue); y+=obj_height+15;
   
   CreateLabel(prefix+"RES_Lot", "LotSize: -", start_x, y, obj_width); y+=obj_height+2;
   CreateLabel(prefix+"RES_SLP", "SL Price: -", start_x, y, obj_width); y+=obj_height+2;
   CreateLabel(prefix+"RES_TPP", "TP Price: -", start_x, y, obj_width); y+=obj_height+15;
   
   CreateButton(prefix+"BTN_BuyLimit", "BUY LIMIT", start_x, y, obj_width/2 - 2, clrGreen);
   CreateButton(prefix+"BTN_SellLimit", "SELL LIMIT", start_x + obj_width/2 + 2, y, obj_width/2 - 2, clrRed);
}

//+------------------------------------------------------------------+
//| อัปเดตข้อมูล Real-time                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   ObjectSetString(0, prefix+"L_Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   ObjectSetString(0, prefix+"L_Spread", OBJPROP_TEXT, "Spread: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
}

//+------------------------------------------------------------------+
//| Event Handling                                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // เมื่อคลิกที่วัตถุ
   if(id == CHARTEVENT_OBJECT_CLICK) {
      
      // ปุ่มสลับ Buy/Sell
      if(sparam == prefix+"BTN_Type") {
         string current = ObjectGetString(0, sparam, OBJPROP_TEXT);
         if(current == "BUY") ObjectSetString(0, sparam, OBJPROP_TEXT, "SELL");
         else ObjectSetString(0, sparam, OBJPROP_TEXT, "BUY");
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      
      // ปุ่มคำนวณ
      if(sparam == prefix+"BTN_Cal") {
         double risk_usd = StringToDouble(ObjectGetString(0, prefix+"INP_Risk", OBJPROP_TEXT));
         double entry = StringToDouble(ObjectGetString(0, prefix+"INP_Entry", OBJPROP_TEXT));
         int sl_pts = (int)StringToInteger(ObjectGetString(0, prefix+"INP_SL", OBJPROP_TEXT));
         double rr = StringToDouble(ObjectGetString(0, prefix+"INP_RR", OBJPROP_TEXT));
         string type = ObjectGetString(0, prefix+"BTN_Type", OBJPROP_TEXT);
         
         if(sl_pts <= 0) {
            ObjectSetString(0, prefix+"RES_Lot", OBJPROP_TEXT, "Err: Set SL Point");
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double point = _Point;
         
         // คำนวณ LotSize
         double lot = risk_usd / (sl_pts * (tick_value / (tick_size / point)));
         
         // ปรับ Lot ให้ตรงตามกฎโบรกเกอร์
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         lot = MathFloor(lot/step) * step;
         lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
         lot = MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
         
         double sl_price = (type == "BUY") ? entry - (sl_pts * point) : entry + (sl_pts * point);
         double tp_price = (type == "BUY") ? entry + (sl_pts * point * rr) : entry - (sl_pts * point * rr);
         
         ObjectSetString(0, prefix+"RES_Lot", OBJPROP_TEXT, "LotSize: " + DoubleToString(lot, 2));
         ObjectSetString(0, prefix+"RES_SLP", OBJPROP_TEXT, "SL Price: " + DoubleToString(sl_price, _Digits));
         ObjectSetString(0, prefix+"RES_TPP", OBJPROP_TEXT, "TP Price: " + DoubleToString(tp_price, _Digits));
         
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      
      // ปุ่มเปิด Order
      if(sparam == prefix+"BTN_BuyLimit" || sparam == prefix+"BTN_SellLimit") {
         string lot_str = ObjectGetString(0, prefix+"RES_Lot", OBJPROP_TEXT);
         if(StringFind(lot_str, "-") >= 0) { 
            Print("Please calculate first.");
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return; 
         }
         
         double lot = StringToDouble(StringSubstr(lot_str, 9));
         double entry = StringToDouble(ObjectGetString(0, prefix+"INP_Entry", OBJPROP_TEXT));
         double sl = StringToDouble(StringSubstr(ObjectGetString(0, prefix+"RES_SLP", OBJPROP_TEXT), 10));
         double tp = StringToDouble(StringSubstr(ObjectGetString(0, prefix+"RES_TPP", OBJPROP_TEXT), 10));
         
         if(sparam == prefix+"BTN_BuyLimit") trade.BuyLimit(lot, entry, _Symbol, sl, tp);
         else trade.SellLimit(lot, entry, _Symbol, sl, tp);
         
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      
      ChartRedraw();
   }
}

int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
{
   return(rates_total);
}