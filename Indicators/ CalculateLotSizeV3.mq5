//+------------------------------------------------------------------+
//|                                           CalculateLotSizeV3.mq5 |
//|                                  Copyright 2024, User            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, User"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property indicator_chart_window

//--- Input Parameters
input double InpRisk   = 100.0; // Risk (USD)
input int    InpSL     = 0;     // SL Point
input double InpRR     = 1.0;   // Reward/Risk (RR)

//--- UI Settings (Inputs)
input int    InpUIWidth  = 220; // UI Width
input int    InpUIHeight = 360; // UI Height
input int    InpXPos     = 20;  // X Position (Pixels from left)
input int    InpYPos     = 20;  // Y Position (Pixels from top)

//--- UI Color Settings (Inputs)
input color  InpBGColor     = clrDodgerBlue; // Background Color
input color  InpTextColor   = clrWhite;      // Text Color
input color  InpBorderColor = clrBlue;       // Border Color
input color  InpBtnColor    = clrBlue;       // Button Color

//--- Global Variables
string   prefix     = "CalcLotV3_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   CreateUI();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, prefix);
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Main Indicator Iteration                                         |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   UpdateDynamicInfo();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer function for live updates                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDynamicInfo();
}

//+------------------------------------------------------------------+
//| Create the User Interface                                        |
//+------------------------------------------------------------------+
void CreateUI()
{
   // Main Background
   CreateRect("MainBG", InpXPos, InpYPos, InpUIWidth, InpUIHeight, InpBGColor, InpBorderColor);
   
   int row = InpYPos + 10;
   int spacing = 25;
   
   // Headers and Static Info
   CreateText("Header", InpXPos + 10, row, "CalculateLotSize V3", 12, true); row += spacing + 5;
   
   CreateLabel("LblBalance", InpXPos + 10, row, "Balance:");
   CreateLabel("ValBalance", InpXPos + 100, row, ""); row += spacing;
   
   CreateLabel("LblSpread", InpXPos + 10, row, "Spread:");
   CreateLabel("ValSpread", InpXPos + 100, row, ""); row += spacing;
   
   CreateLabel("LblProduct", InpXPos + 10, row, "Product:");
   CreateLabel("ValProduct", InpXPos + 100, row, _Symbol); row += spacing + 5;
   
   // Inputs
   CreateLabel("LblType", InpXPos + 10, row, "Type (B/S):");
   CreateEdit("InpType", InpXPos + 100, row, 80, 20, "Buy"); row += spacing;
   
   CreateLabel("LblRisk", InpXPos + 10, row, "Risk (USD):");
   CreateEdit("InpRisk", InpXPos + 100, row, 80, 20, DoubleToString(InpRisk, 2)); row += spacing;
   
   CreateLabel("LblEntry", InpXPos + 10, row, "Entry Price:");
   CreateEdit("InpEntry", InpXPos + 100, row, 80, 20, DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits)); row += spacing;
   
   CreateLabel("LblSLP", InpXPos + 10, row, "SL Points:");
   CreateEdit("InpSLP", InpXPos + 100, row, 80, 20, IntegerToString(InpSL)); row += spacing;
   
   CreateLabel("LblRR", InpXPos + 10, row, "RR Ratio:");
   CreateEdit("InpRR", InpXPos + 100, row, 80, 20, DoubleToString(InpRR, 1)); row += spacing + 10;
   
   // Button
   CreateButton("BtnCal", InpXPos + 10, row, InpUIWidth - 20, 30, "CalLotsize", InpBtnColor); row += 40;
   
   // Results
   CreateLabel("ResLot", InpXPos + 10, row, "Lot Size:");
   CreateText("ValLot", InpXPos + 100, row, "0.00", 10, true); row += spacing;
   
   CreateLabel("ResSL", InpXPos + 10, row, "SL Price:");
   CreateText("ValSL", InpXPos + 100, row, "0.00000", 10, true); row += spacing;
   
   CreateLabel("ResTP", InpXPos + 10, row, "TP Price:");
   CreateText("ValTP", InpXPos + 100, row, "0.00000", 10, true);
}

//+------------------------------------------------------------------+
//| Update Dynamic Account Information                               |
//+------------------------------------------------------------------+
void UpdateDynamicInfo()
{
   ObjectSetString(0, prefix + "ValBalance", OBJPROP_TEXT, DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
   ObjectSetString(0, prefix + "ValSpread", OBJPROP_TEXT, IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == prefix + "BtnCal")
   {
      CalculateResults();
      ObjectSetInteger(0, prefix + "BtnCal", OBJPROP_STATE, false);
   }
}

//+------------------------------------------------------------------+
//| Core Calculation Logic                                           |
//+------------------------------------------------------------------+
void CalculateResults()
{
   string type   = ObjectGetString(0, prefix + "InpType", OBJPROP_TEXT);
   double risk   = StringToDouble(ObjectGetString(0, prefix + "InpRisk", OBJPROP_TEXT));
   double entry  = StringToDouble(ObjectGetString(0, prefix + "InpEntry", OBJPROP_TEXT));
   int    slP    = (int)StringToInteger(ObjectGetString(0, prefix + "InpSLP", OBJPROP_TEXT));
   double rr     = StringToDouble(ObjectGetString(0, prefix + "InpRR", OBJPROP_TEXT));
   
   if(slP <= 0) {
      Print("Invalid SL Points");
      return;
   }

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // 1. Calculate Lot Size
   double lot = risk / (slP * point * (tickValue / tickSize));
   
   // Normalize Lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / stepLot) * stepLot;
   if(lot < minLot) lot = 0;
   if(lot > maxLot) lot = maxLot;

   // 2. Calculate SL and TP Prices
   double slPrice = 0, tpPrice = 0;
   double tpP = slP * rr;

   if(StringFind(type, "Buy") >= 0 || StringFind(type, "buy") >= 0 || StringFind(type, "B") == 0)
   {
      slPrice = entry - (slP * point);
      tpPrice = entry + (tpP * point);
   }
   else // Sell
   {
      slPrice = entry + (slP * point);
      tpPrice = entry - (tpP * point);
   }

   // Update UI
   ObjectSetString(0, prefix + "ValLot", OBJPROP_TEXT, DoubleToString(lot, 2));
   ObjectSetString(0, prefix + "ValSL", OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
   ObjectSetString(0, prefix + "ValTP", OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
}

//+------------------------------------------------------------------+
//| UI Helper Functions                                              |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg, color border)
{
   ObjectCreate(0, prefix+name, OBJ_RECTANGLE_LABEL, 0, 0, 0); // Fixed OBJ_RECTLABEL to OBJ_RECTANGLE_LABEL
   ObjectSetInteger(0, prefix+name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, prefix+name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, prefix+name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, prefix+name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, prefix+name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, prefix+name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefix+name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, prefix+name, OBJPROP_WIDTH, 2);
}

void CreateLabel(string name, int x, int y, string txt)
{
   ObjectCreate(0, prefix+name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, prefix+name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, prefix+name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, prefix+name, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, prefix+name, OBJPROP_FONTSIZE, 9);
}

void CreateText(string name, int x, int y, string txt, int size, bool bold)
{
   ObjectCreate(0, prefix+name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, prefix+name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, prefix+name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, prefix+name, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, prefix+name, OBJPROP_FONTSIZE, size);
   if(bold) ObjectSetString(0, prefix+name, OBJPROP_FONT, "Trebuchet MS Bold");
}

void CreateEdit(string name, int x, int y, int w, int h, string def)
{
   ObjectCreate(0, prefix+name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, prefix+name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, prefix+name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, prefix+name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, prefix+name, OBJPROP_YSIZE, h);
   ObjectSetString(0, prefix+name, OBJPROP_TEXT, def);
   ObjectSetInteger(0, prefix+name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, prefix+name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, prefix+name, OBJPROP_ALIGN, ALIGN_CENTER);
}

void CreateButton(string name, int x, int y, int w, int h, string txt, color bg)
{
   ObjectCreate(0, prefix+name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, prefix+name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, prefix+name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, prefix+name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, prefix+name, OBJPROP_YSIZE, h);
   ObjectSetString(0, prefix+name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, prefix+name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, prefix+name, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, prefix+name, OBJPROP_FONTSIZE, 10);
}