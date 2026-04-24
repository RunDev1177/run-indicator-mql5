//+------------------------------------------------------------------+
//|                                           CalculateLotSize V5.mq5|
//|                                  Copyright 2024, Gemini Al-Trader|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Al-Trader"
#property link      "https://www.mql5.com"
#property version   "5.10"
#property indicator_chart_window

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input group "Trading Settings"
input double   InpRisk     = 100.0;    // Risk (USD)
input int      InpSLPoints = 0;        // SL (Points)
input double   InpRR       = 1.0;      // Reward/Risk Ratio

input group "UI Layout Settings"
input int      InpX        = 20;       // Panel X Position
input int      InpY        = 150;       // Panel Y Position
input int      InpW        = 240;      // Panel Width
input int      InpH        = 480;      // Panel Height

//--- GLOBAL VARIABLES
CTrade         trade;
long           chart_id = 0;
int            sub_window = 0;

//--- UI OBJECT NAMES
string prefix = "CalcLotV5_";
string obj_panel     = prefix + "panel";
string obj_title     = prefix + "title";
string obj_balance   = prefix + "balance";
string obj_spread    = prefix + "spread";
string obj_product   = prefix + "product";
string obj_time      = prefix + "time";
string obj_dir_btn   = prefix + "dir_btn";
string obj_risk_inp  = prefix + "risk_inp";
string obj_entry_inp = prefix + "entry_inp";
string obj_sl_inp    = prefix + "sl_inp";
string obj_rr_inp    = prefix + "rr_inp";
string obj_btn_cal   = prefix + "btn_cal";
string obj_res_lot   = prefix + "res_lot";
string obj_res_slp   = prefix + "res_slp";
string obj_res_tp    = prefix + "res_tp";
string obj_btn_buy   = prefix + "btn_buy";
string obj_btn_sell  = prefix + "btn_sell";

//--- STATE
bool is_buy = true;
double calculated_lot = 0;
double calculated_sl = 0;
double calculated_tp = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   chart_id = ChartID();
   CreateUI();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(chart_id, prefix);
   EventKillTimer();
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
                const long &volume[],
                const int &spread[])
{
   UpdateRealTimeInfo();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer function for real-time updates                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateRealTimeInfo();
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Button Click: Change Direction
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == obj_dir_btn)
   {
      is_buy = !is_buy;
      ObjectSetString(chart_id, obj_dir_btn, OBJPROP_TEXT, is_buy ? "BUY" : "SELL");
      ObjectSetInteger(chart_id, obj_dir_btn, OBJPROP_BGCOLOR, is_buy ? clrDodgerBlue : clrCrimson);
      ObjectSetInteger(chart_id, obj_dir_btn, OBJPROP_STATE, false);
   }

   // Button Click: Calculate
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == obj_btn_cal)
   {
      CalculateResult();
      ObjectSetInteger(chart_id, obj_btn_cal, OBJPROP_STATE, false);
   }

   // Button Click: Place Buy Limit
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == obj_btn_buy)
   {
      PlaceLimitOrder(ORDER_TYPE_BUY_LIMIT);
      ObjectSetInteger(chart_id, obj_btn_buy, OBJPROP_STATE, false);
   }

   // Button Click: Place Sell Limit
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == obj_btn_sell)
   {
      PlaceLimitOrder(ORDER_TYPE_SELL_LIMIT);
      ObjectSetInteger(chart_id, obj_btn_sell, OBJPROP_STATE, false);
   }
}

//+------------------------------------------------------------------+
//| Create UI Elements                                               |
//+------------------------------------------------------------------+
void CreateUI()
{
   int x = InpX;
   int y = InpY;
   int w = InpW;
   int h = InpH;

   // Main Panel
   CreateRect(obj_panel, x, y, w, h, clrMediumBlue, clrWhite);
   CreateLabel(obj_title, x + 10, y + 10, "CALCULATE LOTSIZE V5", 11, clrWhite);

   // 1. Info Section
   int curr_y = y + 40;
   CreateLabel(obj_balance, x + 10, curr_y, "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), 9, clrWhite);
   curr_y += 20;
   CreateLabel(obj_spread, x + 10, curr_y, "Spread: ", 9, clrWhite);
   curr_y += 20;
   CreateLabel(obj_product, x + 10, curr_y, "Product: " + _Symbol, 9, clrWhite);
   curr_y += 20;
   CreateLabel(obj_time, x + 10, curr_y, "Time: ", 8, clrWhite);

   // 2. Input Section
   curr_y += 35;
   CreateLabel(prefix + "l1", x + 10, curr_y, "Direction:", 9, clrWhite);
   CreateButton(obj_dir_btn, x + w - 90, curr_y - 5, 80, 20, "BUY", clrDodgerBlue, clrWhite);

   curr_y += 30;
   CreateLabel(prefix + "l2", x + 10, curr_y, "Risk ($):", 9, clrWhite);
   CreateEdit(obj_risk_inp, x + w - 90, curr_y - 5, 80, 20, DoubleToString(InpRisk, 2), clrWhite, clrBlack);

   curr_y += 30;
   CreateLabel(prefix + "l3", x + 10, curr_y, "Entry Price:", 9, clrWhite);
   CreateEdit(obj_entry_inp, x + w - 90, curr_y - 5, 80, 20, DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits), clrWhite, clrBlack);

   curr_y += 30;
   CreateLabel(prefix + "l4", x + 10, curr_y, "SL Points:", 9, clrWhite);
   CreateEdit(obj_sl_inp, x + w - 90, curr_y - 5, 80, 20, IntegerToString(InpSLPoints), clrWhite, clrBlack);

   curr_y += 30;
   CreateLabel(prefix + "l5", x + 10, curr_y, "RR Ratio:", 9, clrWhite);
   CreateEdit(obj_rr_inp, x + w - 90, curr_y - 5, 80, 20, DoubleToString(InpRR, 1), clrWhite, clrBlack);

   // 3. Action Button
   curr_y += 40;
   CreateButton(obj_btn_cal, x + 10, curr_y, w - 20, 30, "CalLotsize", clrBlue, clrWhite);

   // 4. Result Section
   curr_y += 50;
   CreateLabel(obj_res_lot, x + 10, curr_y, "Lotsize: 0.00", 10, clrYellow);
   curr_y += 25;
   CreateLabel(obj_res_slp, x + 10, curr_y, "SL Price: 0.00", 9, clrWhite);
   curr_y += 25;
   CreateLabel(obj_res_tp, x + 10, curr_y, "TP Price: 0.00", 9, clrWhite);

   // 5. Order Buttons
   curr_y += 40;
   int btn_w = (w - 30) / 2;
   CreateButton(obj_btn_buy, x + 10, curr_y, btn_w, 30, "Buy Limit", clrGreen, clrWhite);
   CreateButton(obj_btn_sell, x + w - btn_w - 10, curr_y, btn_w, 30, "Sell Limit", clrRed, clrWhite);
}

//+------------------------------------------------------------------+
//| Logic: Update Info                                               |
//+------------------------------------------------------------------+
void UpdateRealTimeInfo()
{
   ObjectSetString(chart_id, obj_balance, OBJPROP_TEXT, "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
   ObjectSetString(chart_id, obj_spread, OBJPROP_TEXT, "Spread: " + IntegerToString(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));

   datetime server_time = TimeCurrent();
   datetime thai_time = server_time + (4 * 3600); 
   ObjectSetString(chart_id, obj_time, OBJPROP_TEXT, "SV: " + TimeToString(server_time, TIME_SECONDS) + " | TH: " + TimeToString(thai_time, TIME_SECONDS));
}

//+------------------------------------------------------------------+
//| Logic: Calculate Lot Size                                        |
//+------------------------------------------------------------------+
void CalculateResult()
{
   double risk_usd = StringToDouble(ObjectGetString(chart_id, obj_risk_inp, OBJPROP_TEXT));
   double entry    = StringToDouble(ObjectGetString(chart_id, obj_entry_inp, OBJPROP_TEXT));
   int sl_points   = (int)StringToInteger(ObjectGetString(chart_id, obj_sl_inp, OBJPROP_TEXT));
   double rr       = StringToDouble(ObjectGetString(chart_id, obj_rr_inp, OBJPROP_TEXT));

   if(sl_points <= 0) {
      ObjectSetString(chart_id, obj_res_lot, OBJPROP_TEXT, "Error: Set SL Points");
      return;
   }

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = _Point;

   double sl_distance = sl_points * point;
   calculated_lot = risk_usd / (sl_points * (tick_value / (tick_size / point)));
   calculated_lot = MathFloor(calculated_lot / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(calculated_lot < min_lot) calculated_lot = min_lot;
   if(calculated_lot > max_lot) calculated_lot = max_lot;

   if(is_buy) {
      calculated_sl = entry - sl_distance;
      calculated_tp = entry + (sl_distance * rr);
   } else {
      calculated_sl = entry + sl_distance;
      calculated_tp = entry - (sl_distance * rr);
   }

   ObjectSetString(chart_id, obj_res_lot, OBJPROP_TEXT, "Lotsize: " + DoubleToString(calculated_lot, 2));
   ObjectSetString(chart_id, obj_res_slp, OBJPROP_TEXT, "SL Price: " + DoubleToString(calculated_sl, _Digits));
   ObjectSetString(chart_id, obj_res_tp,  OBJPROP_TEXT, "TP Price: " + DoubleToString(calculated_tp, _Digits));
}

//+------------------------------------------------------------------+
//| Logic: Place Order                                               |
//+------------------------------------------------------------------+
void PlaceLimitOrder(ENUM_ORDER_TYPE type)
{
   double entry = StringToDouble(ObjectGetString(chart_id, obj_entry_inp, OBJPROP_TEXT));
   if(calculated_lot <= 0) {
      CalculateResult();
   }
   
   if(calculated_lot > 0) {
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT) {
         trade.OrderOpen(_Symbol, type, calculated_lot, 0, entry, calculated_sl, calculated_tp);
      }
   }
}

//+------------------------------------------------------------------+
//| UI Helpers                                                       |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, int size, color clr)
{
   ObjectCreate(chart_id, name, OBJ_LABEL, sub_window, 0, 0);
   ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(chart_id, name, OBJPROP_FONT, "Trebuchet MS");
}

void CreateRect(string name, int x, int y, int w, int h, color bg, color border)
{
   ObjectCreate(chart_id, name, OBJ_RECTANGLE_LABEL, sub_window, 0, 0);
   ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(chart_id, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(chart_id, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(chart_id, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(chart_id, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(chart_id, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color clr)
{
   ObjectCreate(chart_id, name, OBJ_BUTTON, sub_window, 0, 0);
   ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(chart_id, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(chart_id, name, OBJPROP_YSIZE, h);
   ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chart_id, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(chart_id, name, OBJPROP_BORDER_COLOR, clrWhite);
}

void CreateEdit(string name, int x, int y, int w, int h, string text, color bg, color clr)
{
   ObjectCreate(chart_id, name, OBJ_EDIT, sub_window, 0, 0);
   ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(chart_id, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(chart_id, name, OBJPROP_YSIZE, h);
   ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chart_id, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_id, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, 9);
}
