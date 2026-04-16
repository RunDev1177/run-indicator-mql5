//+------------------------------------------------------------------+
//|                                           CalculateLotSizeV2.mq5 |
//|                                  Copyright 2024, Gemini AI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini AI Agent"
#property link      "https://www.mql5.com"
#property version   "2.01"
#property indicator_chart_window

#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Input Parameters
input double InpRiskUSD = 100.0;    // Risk (USD)
input int    InpSLPoint = 500;      // SL Point
input double InpRR      = 1.0;      // Reward/Risk (RR)

//--- Global Variables
CChartObjectButton  btnCalculate;
CChartObjectEdit    editRisk, editSL, editRR, editEntry, editType;
CChartObjectLabel   lblBalance, lblLotResult, lblSLPrice, lblTPPrice;
CChartObjectRectLabel bgPanel;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Create Background Panel
    CreateBackground();

    //--- Create Labels and Inputs
    int x = 20, y = 30, spacing = 25;
    
    CreateLabel("lbl_title", "--- CALCULATE LOTSIZE V2 ---", x, y, 10, clrWhite);
    y += spacing;
    
    // Type (Buy/Sell)
    CreateLabel("lbl_t1", "Type (1=Buy, 2=Sell):", x, y, 9, clrWhite);
    CreateEdit(editType, "edit_type", "1", x + 130, y - 2, 40, 20);
    y += spacing;

    // Balance
    string balStr = "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
    CreateLabel("lbl_bal", balStr, x, y, 9, clrWhite);
    y += spacing;

    // Risk Input
    CreateLabel("lbl_r", "Risk ($):", x, y, 9, clrWhite);
    CreateEdit(editRisk, "edit_risk", DoubleToString(InpRiskUSD, 2), x + 130, y - 2, 60, 20);
    y += spacing;

    // Entry Price Input
    CreateLabel("lbl_e", "Entry Price:", x, y, 9, clrWhite);
    CreateEdit(editEntry, "edit_entry", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits), x + 130, y - 2, 80, 20);
    y += spacing;

    // SL Point Input
    CreateLabel("lbl_slp", "SL Point:", x, y, 9, clrWhite);
    CreateEdit(editSL, "edit_sl", IntegerToString(InpSLPoint), x + 130, y - 2, 60, 20);
    y += spacing;

    // RR Input
    CreateLabel("lbl_rr", "RR Ratio:", x, y, 9, clrWhite);
    CreateEdit(editRR, "edit_rr", DoubleToString(InpRR, 1), x + 130, y - 2, 40, 20);
    y += spacing + 5;

    // Button
    CreateButton();
    y += spacing + 10;

    // Results
    CreateLabel("lbl_res_title", "[ RESULTS ]", x, y, 9, clrYellow);
    y += spacing;
    CreateResultLabel(lblLotResult, "lbl_lot_res", "Lot Size: 0.00", x, y);
    y += spacing;
    CreateResultLabel(lblSLPrice, "lbl_sl_res", "SL Price: 0.00000", x, y);
    y += spacing;
    CreateResultLabel(lblTPPrice, "lbl_tp_res", "TP Price: 0.00000", x, y);

    ChartRedraw();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "calc_");
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == "calc_btn")
    {
        CalculateTrading();
        btnCalculate.State(false);
        ChartRedraw();
    }
}

//+------------------------------------------------------------------+
//| Calculation Logic                                                |
//+------------------------------------------------------------------+
void CalculateTrading()
{
    double riskUSD = StringToDouble(editRisk.Description());
    int slPoint = (int)StringToInteger(editSL.Description());
    double rr = StringToDouble(editRR.Description());
    double entry = StringToDouble(editEntry.Description());
    int type = (int)StringToInteger(editType.Description()); // 1 = Buy, 2 = Sell

    if(slPoint <= 0) {
        Print("SL Point must be greater than 0");
        return;
    }

    // Calculate Lot Size
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = _Point;

    // Correct Lot Calculation based on Tick Value
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double calculatedLot = riskUSD / (slPoint * (tickValue / (tickSize / point)));
    
    // Normalize Lot
    calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    if(calculatedLot < minLot) calculatedLot = 0;
    if(calculatedLot > maxLot) calculatedLot = maxLot;

    // Calculate SL and TP Price
    double slPrice = 0, tpPrice = 0;
    if(type == 1) // Buy
    {
        slPrice = entry - (slPoint * point);
        tpPrice = entry + (slPoint * point * rr);
    }
    else // Sell
    {
        slPrice = entry + (slPoint * point);
        tpPrice = entry - (slPoint * point * rr);
    }

    // Update Display
    lblLotResult.Description("Lot Size: " + DoubleToString(calculatedLot, 2));
    lblSLPrice.Description("SL Price: " + DoubleToString(slPrice, _Digits));
    lblTPPrice.Description("TP Price: " + DoubleToString(tpPrice, _Digits));
}

//+------------------------------------------------------------------+
//| UI Helper Functions                                              |
//+------------------------------------------------------------------+
void CreateBackground()
{
    bgPanel.Create(0, "calc_bg", 0, 10, 20, 230, 350);
    bgPanel.BackColor(clrRoyalBlue);
    bgPanel.BorderType(BORDER_FLAT);
    bgPanel.Color(clrWhite);
    bgPanel.Selectable(false);
}

void CreateLabel(string name, string text, int x, int y, int size, color clr)
{
    CChartObjectLabel *lbl = new CChartObjectLabel();
    lbl.Create(0, "calc_" + name, 0, x, y);
    lbl.Description(text);
    lbl.FontSize(size);
    lbl.Color(clr);
    lbl.Selectable(false);
}

void CreateResultLabel(CChartObjectLabel &obj, string name, string text, int x, int y)
{
    obj.Create(0, "calc_" + name, 0, x, y);
    obj.Description(text);
    obj.FontSize(10);
    obj.Color(clrWhite);
    obj.Selectable(false);
}

void CreateEdit(CChartObjectEdit &obj, string name, string text, int x, int y, int width, int height)
{
    obj.Create(0, "calc_" + name, 0, x, y, width, height);
    obj.Description(text);
    obj.FontSize(9);
    obj.TextAlign(ALIGN_CENTER);
    obj.BackColor(clrWhite); // Fixed from BackgroundColor
    obj.Color(clrBlack);
}

void CreateButton()
{
    btnCalculate.Create(0, "calc_btn", 0, 20, 215, 190, 30);
    btnCalculate.Description("CalLotsize");
    btnCalculate.FontSize(10);
    btnCalculate.Color(clrWhite);
    btnCalculate.BackColor(clrMediumBlue);
    btnCalculate.Selectable(false);
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
    return(rates_total);
}