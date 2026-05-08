//+------------------------------------------------------------------+
//|                                           CalculateLotSizeV7.mq5 |
//|                                  Copyright 2024, Trading Tool    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.07"
#property indicator_chart_window
#property indicator_plots 0

#include <Trade\Trade.mqh>

//--- Input Parameters
input double InpRiskUSD = 100.0;    // Default Risk (USD)
input int    InpSLPoints = 500;     // Default SL Point
input double InpRR = 1.0;          // Default RR Ratio
input int    InpPosX = 400;        // Initial X Position
input int    InpPosY = 100;        // Initial Y Position

//--- Global Variables
CTrade trade;
string prefix = "CLS_V7_";
int panel_w = 500;                 // ขยายความกว้างเพื่อความโปร่ง
int panel_h = 320;                 // ปรับความสูงเล็กน้อย
bool is_minimized = false;
int global_font_size = 11;
string global_font = "Verdana";    // เปลี่ยนฟอนต์ให้ดูนุ่มนวลขึ้น

// Dragging Variables
bool is_dragging = false;
int  drag_offset_x = 0;
int  drag_offset_y = 0;
int  current_x = 0;
int  current_y = 0;

//+------------------------------------------------------------------+
//| UI Helper Functions                                              |
//+------------------------------------------------------------------+
void CreatePanel(string name, int x, int y, int w, int h, color bg) {
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateLabel(string name, string text, int x, int y, color clr, int size=11, string font="Verdana") {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateEdit(string name, string text, int x, int y, int w, int h) {
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'30,30,30');
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, global_font_size);
   ObjectSetString(0, name, OBJPROP_FONT, global_font);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateButton(string name, string text, int x, int y, int w, int h, color bg, color txtClr=clrWhite) {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, global_font_size);
   ObjectSetString(0, name, OBJPROP_FONT, global_font);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   current_x = InpPosX;
   current_y = InpPosY;
   EventSetTimer(1);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); 
   DrawUI(current_x, current_y);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, prefix);
   EventKillTimer();
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Drawing Logic                                                    |
//+------------------------------------------------------------------+
void DrawUI(int x, int y) {
   ObjectsDeleteAll(0, prefix);
   
   if(is_minimized) {
      CreatePanel(prefix+"bg", x, y, 120, 40, clrBlack);
      CreateButton(prefix+"btn_min", "+", x+90, y+10, 20, 20, clrGray);
      CreateLabel(prefix+"lbl_title", "Lot Calc", x+10, y+12, clrWhite, global_font_size, global_font);
      return;
   }

   // Main Panel
   CreatePanel(prefix+"bg", x, y, panel_w, panel_h, clrBlack);
   
   // Top Bar (Drag Area)
   CreatePanel(prefix+"title_bar", x, y, panel_w, 30, C'20,20,20');
   CreateLabel(prefix+"title_txt", "LOT SIZE CALCULATOR V7", x+15, y+7, clrDarkGray, 9, global_font);

   // Top Buttons
   CreateButton(prefix+"btn_min", "-", x+panel_w-60, y+5, 22, 22, clrWhite, clrBlack);
   CreateButton(prefix+"btn_close", "X", x+panel_w-32, y+5, 22, 22, clrRed, clrWhite);

   // Row 1: Account Info
   CreateLabel(prefix+"lbl_m", "Balance:", x+25, y+50, clrLightGray, global_font_size, global_font);
   CreateLabel(prefix+"val_m", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " USD", x+110, y+50, clrWhite, global_font_size, global_font);
   
   CreateLabel(prefix+"lbl_s", "Spread:", x+280, y+50, clrLightGray, global_font_size, global_font);
   CreateLabel(prefix+"val_s", IntegerToString(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)), x+360, y+50, clrYellow, global_font_size, global_font);

   // Row 2: Time Info
   CreateLabel(prefix+"lbl_sv", "Server:", x+25, y+85, clrLightGray, global_font_size, global_font);
   CreateLabel(prefix+"val_sv", TimeToString(TimeCurrent(), TIME_SECONDS), x+110, y+85, clrWhite, global_font_size, global_font);
   
   CreateLabel(prefix+"lbl_th", "Local (TH):", x+240, y+85, clrLightGray, global_font_size, global_font);
   CreateLabel(prefix+"val_th", TimeToString(TimeCurrent() + (7*3600), TIME_SECONDS), x+360, y+85, clrWhite, global_font_size, global_font);

   // Separator Line
   CreatePanel(prefix+"sep1", x+20, y+115, panel_w-40, 1, C'50,50,50');

   // Row 3: Product & Risk
   CreateLabel(prefix+"lbl_p", "Symbol:", x+25, y+135, clrLightGray, global_font_size, global_font);
   CreateLabel(prefix+"val_p", _Symbol, x+110, y+135, clrOrange, global_font_size, global_font);
   
   CreateLabel(prefix+"lbl_r", "Risk ($):", x+260, y+135, clrLightGray, global_font_size, global_font);
   CreateEdit(prefix+"edit_risk", DoubleToString(InpRiskUSD, 0), x+360, y+130, 90, 26);

   // Row 4: Entry & SL Point
   CreateLabel(prefix+"lbl_ent", "Price:", x+25, y+175, clrLightGray, global_font_size, global_font);
   CreateEdit(prefix+"edit_entry", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits), x+110, y+170, 120, 26);
   
   CreateLabel(prefix+"lbl_slp", "SL Pts:", x+260, y+175, clrLightGray, global_font_size, global_font);
   CreateEdit(prefix+"edit_sl", IntegerToString(InpSLPoints), x+360, y+170, 90, 26);

   // Row 5: RR & Direction
   CreateLabel(prefix+"lbl_rr", "RR:", x+25, y+215, clrLightGray, global_font_size, global_font);
   CreateEdit(prefix+"edit_rr", DoubleToString(InpRR, 1), x+110, y+210, 60, 26);
   
   CreateLabel(prefix+"lbl_dir", "Type:", x+260, y+215, clrLightGray, global_font_size, global_font);
   CreateButton(prefix+"btn_type", "BUY", x+360, y+210, 90, 26, clrLightGreen, clrBlack);

   // Row 6: Action Button
   CreateButton(prefix+"btn_calc", "CALCULATE Lotsize", x+panel_w/2-90, y+255, 220, 40, clrWhite, clrBlack);

   // Footer Results
   CreateLabel(prefix+"res_lot", "Lot: ---", x+25, y+305, clrOrange, global_font_size, global_font);
   CreateLabel(prefix+"res_slp", "SL: ---", x+180, y+305, clrOrange, global_font_size, global_font);
   CreateLabel(prefix+"res_tpp", "TP: ---", x+350, y+305, clrOrange, global_font_size, global_font);
}

//+------------------------------------------------------------------+
//| Event Handling                                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   
   if(id == CHARTEVENT_MOUSE_MOVE) {
      int x = (int)lparam;
      int y = (int)dparam;
      uint mouse_state = (uint)sparam;

      if((mouse_state & 1) == 1) { 
         if(!is_dragging) {
            if(x >= current_x && x <= current_x + panel_w && y >= current_y && y <= current_y + 35) {
               is_dragging = true;
               drag_offset_x = x - current_x;
               drag_offset_y = y - current_y;
            }
         } else {
            current_x = x - drag_offset_x;
            current_y = y - drag_offset_y;
            DrawUI(current_x, current_y);
         }
      } else {
         is_dragging = false;
      }
   }

   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == prefix+"btn_close") ChartIndicatorDelete(0, ChartWindowFind(), "CalculateLotSizeV7");
      
      if(sparam == prefix+"btn_min") {
         is_minimized = !is_minimized;
         DrawUI(current_x, current_y);
      }

      if(sparam == prefix+"btn_type") {
         string current = ObjectGetString(0, sparam, OBJPROP_TEXT);
         if(current == "BUY") {
            ObjectSetString(0, sparam, OBJPROP_TEXT, "SELL");
            ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, clrOrangeRed);
         } else {
            ObjectSetString(0, sparam, OBJPROP_TEXT, "BUY");
            ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, clrLightGreen);
         }
      }

      if(sparam == prefix+"btn_calc") Calculate();
   }
}

void OnTimer() {
   if(is_minimized || is_dragging) return;
   ObjectSetString(0, prefix+"val_sv", OBJPROP_TEXT, TimeToString(TimeCurrent(), TIME_SECONDS));
   ObjectSetString(0, prefix+"val_th", OBJPROP_TEXT, TimeToString(TimeCurrent() + (7*3600), TIME_SECONDS));
   ObjectSetString(0, prefix+"val_s", OBJPROP_TEXT, IntegerToString(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
   ObjectSetString(0, prefix+"val_m", OBJPROP_TEXT, DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " USD");
}

void Calculate() {
   double risk = StringToDouble(ObjectGetString(0, prefix+"edit_risk", OBJPROP_TEXT));
   double entry = StringToDouble(ObjectGetString(0, prefix+"edit_entry", OBJPROP_TEXT));
   int sl_points = (int)StringToInteger(ObjectGetString(0, prefix+"edit_sl", OBJPROP_TEXT));
   double rr = StringToDouble(ObjectGetString(0, prefix+"edit_rr", OBJPROP_TEXT));
   string type = ObjectGetString(0, prefix+"btn_type", OBJPROP_TEXT);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = _Point;

   if(sl_points <= 0) return;

   double lot = risk / (sl_points * (tickValue / (tickSize / point)));
   lot = MathFloor(lot / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double sl_price = (type == "BUY") ? entry - (sl_points * point) : entry + (sl_points * point);
   double tp_price = (type == "BUY") ? entry + (sl_points * point * rr) : entry - (sl_points * point * rr);

   ObjectSetString(0, prefix+"res_lot", OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
   ObjectSetString(0, prefix+"res_slp", OBJPROP_TEXT, "SL: " + DoubleToString(sl_price, _Digits));
   ObjectSetString(0, prefix+"res_tpp", OBJPROP_TEXT, "TP: " + DoubleToString(tp_price, _Digits));
}