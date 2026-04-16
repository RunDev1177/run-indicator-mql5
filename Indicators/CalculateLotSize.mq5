//+------------------------------------------------------------------+
//|                                              LotSizeCalculator.mq5|
//|                                  Copyright 2024, Trading Tool    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.10"
#property strict
#property indicator_chart_window

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\ComboBox.mqh>

//--- Input parameters
input double   InpDefaultRisk = 3.0;      // Default Risk %
input double   InpDefaultRR   = 1.0;      // Default Reward/Risk

//--- Global Variables
CAppDialog     m_panel;
CEdit          m_edit_balance;
CEdit          m_edit_risk;
CEdit          m_edit_sl_points;
CEdit          m_edit_entry;
CEdit          m_edit_rr;
CComboBox      m_combo_type;    // เพิ่มส่วนเลือก BUY/SELL
CEdit          m_edit_lot;
CEdit          m_edit_sl_price;
CEdit          m_edit_tp_price;
CButton        m_btn_calc;

//+------------------------------------------------------------------+
//| Custom function to Create Panel                                   |
//+------------------------------------------------------------------+
bool CreatePanel()
{
   if(!m_panel.Create(0, "Lot Size Calculator", 0, 20, 20, 280, 450))
      return(false);

   int x1 = 10;
   int x2 = 130;
   int y  = 10;
   int h  = 25;
   int w_edit  = 120;

   //--- Title Label
   CLabel *title = new CLabel;
   title.Create(0, "Title", 0, 60, y, 200, y+h);
   title.Text("LOT SIZE CALCULATOR");
   title.Color(clrDodgerBlue);
   m_panel.Add(title);
   
   y += 35;

   //--- Balance
   CreateLabel("lbl_balance", "Balance", x1, y);
   m_edit_balance.Create(0, "edit_balance", 0, x2, y, x2+w_edit, y+h);
   m_edit_balance.Text(DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   m_panel.Add(m_edit_balance);
   y += 30;

   //--- Risk %
   CreateLabel("lbl_risk", "Risk %", x1, y);
   m_edit_risk.Create(0, "edit_risk", 0, x2, y, x2+w_edit, y+h);
   m_edit_risk.Text(DoubleToString(InpDefaultRisk, 1));
   m_panel.Add(m_edit_risk);
   y += 30;

   //--- SL Points
   CreateLabel("lbl_sl_pts", "SL Points", x1, y);
   m_edit_sl_points.Create(0, "edit_sl_pts", 0, x2, y, x2+w_edit, y+h);
   m_edit_sl_points.Text("500");
   m_panel.Add(m_edit_sl_points);
   y += 30;

   //--- Entry Price
   CreateLabel("lbl_entry", "Entry Price", x1, y);
   m_edit_entry.Create(0, "edit_entry", 0, x2, y, x2+w_edit, y+h);
   m_edit_entry.Text(DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits));
   m_panel.Add(m_edit_entry);
   y += 30;

   //--- RR
   CreateLabel("lbl_rr", "RR", x1, y);
   m_edit_rr.Create(0, "edit_rr", 0, x2, y, x2+w_edit, y+h);
   m_edit_rr.Text(DoubleToString(InpDefaultRR, 1));
   m_panel.Add(m_edit_rr);
   y += 30;

   //--- Type (BUY/SELL) - ส่วนที่เพิ่มใหม่ตามรูป
   CreateLabel("lbl_type", "Type", x1, y);
   m_combo_type.Create(0, "combo_type", 0, x2, y, x2+w_edit, y+h);
   m_combo_type.ItemAdd("BUY");
   m_combo_type.ItemAdd("SELL");
   m_combo_type.Select(0);
   m_panel.Add(m_combo_type);
   y += 45;

   //--- Calculate Button
   m_btn_calc.Create(0, "btn_calc", 0, x1, y, x2+w_edit, y+35);
   m_btn_calc.Text("CALCULATE");
   m_btn_calc.ColorBackground(clrDodgerBlue);
   m_panel.Add(m_btn_calc);
   y += 50;

   //--- Lot Size Result
   CreateLabel("lbl_lot", "Lot Size", x1, y);
   m_edit_lot.Create(0, "edit_lot", 0, x2, y, x2+w_edit, y+h);
   m_edit_lot.Text("0.00");
   m_edit_lot.Color(clrDeepSkyBlue);
   m_edit_lot.ReadOnly(true);
   m_panel.Add(m_edit_lot);
   y += 30;

   //--- SL Price
   CreateLabel("lbl_sl_prc", "SL Price", x1, y);
   m_edit_sl_price.Create(0, "edit_sl_prc", 0, x2, y, x2+w_edit, y+h);
   m_edit_sl_price.Text("-");
   m_edit_sl_price.Color(clrTomato);
   m_edit_sl_price.ReadOnly(true);
   m_panel.Add(m_edit_sl_price);
   y += 30;

   //--- TP Price
   CreateLabel("lbl_tp_prc", "TP Price", x1, y);
   m_edit_tp_price.Create(0, "edit_tp_prc", 0, x2, y, x2+w_edit, y+h);
   m_edit_tp_price.Text("-");
   m_edit_tp_price.Color(clrSpringGreen);
   m_edit_tp_price.ReadOnly(true);
   m_panel.Add(m_edit_tp_price);

   m_panel.Run();
   return(true);
}

void CreateLabel(string name, string text, int x, int y)
{
   CLabel *lbl = new CLabel;
   lbl.Create(0, name, 0, x, y, x+100, y+25);
   lbl.Text(text);
   lbl.Color(clrLightGray);
   m_panel.Add(lbl);
}

//+------------------------------------------------------------------+
//| Calculation Logic                                                 |
//+------------------------------------------------------------------+
void Calculate()
{
   double balance = StringToDouble(m_edit_balance.Text());
   double riskPercent = StringToDouble(m_edit_risk.Text());
   double slPoints = StringToDouble(m_edit_sl_points.Text());
   double entry = StringToDouble(m_edit_entry.Text());
   double rr = StringToDouble(m_edit_rr.Text());
   string type = m_combo_type.Select() == 0 ? "BUY" : "SELL";

   if(slPoints <= 0) return;

   //--- Calculate Lot Size
   double riskAmount = balance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // คำนวณ Lot โดยอิงจากมูลค่าต่อจุดของแต่ละ Symbol
   double lot = riskAmount / (slPoints * (tickValue / (tickSize / point)));
   
   // Normalize Lot ให้ตรงตามข้อกำหนดของ Broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / stepLot) * stepLot;
   if(lot < minLot) lot = 0;
   if(lot > maxLot) lot = maxLot;

   m_edit_lot.Text(DoubleToString(lot, 2));

   //--- Calculate SL/TP Prices ตามฝั่งที่เลือก (BUY/SELL)
   double slPrice, tpPrice;
   if(type == "BUY")
   {
      slPrice = entry - (slPoints * point);
      tpPrice = entry + (slPoints * rr * point);
   }
   else // SELL
   {
      slPrice = entry + (slPoints * point);
      tpPrice = entry - (slPoints * rr * point);
   }

   m_edit_sl_price.Text(DoubleToString(slPrice, _Digits));
   m_edit_tp_price.Text(DoubleToString(tpPrice, _Digits));
}

//+------------------------------------------------------------------+
//| Event Handler                                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   m_panel.ChartEvent(id, lparam, dparam, sparam);
   
   // ตรวจสอบการกดปุ่ม CALCULATE
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == m_btn_calc.Name())
   {
      Calculate();
      ChartRedraw();
   }
}

int OnInit()
{
   if(!CreatePanel()) return(INIT_FAILED);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   m_panel.Destroy(reason);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   return(rates_total);
}