//+------------------------------------------------------------------+
//|                    CalLot v2 - Pro Trader Panel                  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#include <Trade/Trade.mqh>
CTrade trade;

//================ PANEL STATE =================
enum MODE {BUYMODE, SELLMODE};
MODE CurrentMode = BUYMODE;

string SL_LINE="CALLOT_SL";

double RiskPercent=3.0;
double EntryPrice=0;
double SLPrice=0;
double TPPrice=0;
double Lots=0;
double RR=1.0;

datetime lastTradeBar=0;

//================ UTIL ========================
double PipValue()
{
   double tickvalue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ticksize =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return tickvalue/ticksize;
}

double CalcLot(double risk,double entry,double sl)
{
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney=balance*risk/100.0;

   double distance=MathAbs(entry-sl);
   if(distance<=0) return 0;

   double lot=riskMoney/(distance/PipValue());
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   lot=MathFloor(lot/step)*step;
   return NormalizeDouble(lot,2);
}

//================ SL LINE =====================
void CreateSLLine()
{
   if(ObjectFind(0,SL_LINE)>=0) return;

   ObjectCreate(0,SL_LINE,OBJ_HLINE,0,0,Bid-200*_Point);
   ObjectSetInteger(0,SL_LINE,OBJPROP_COLOR,clrOrangeRed);
   ObjectSetInteger(0,SL_LINE,OBJPROP_WIDTH,2);
}

//================ CALC ========================
void UpdateCalc()
{
   EntryPrice = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   SLPrice = ObjectGetDouble(0,SL_LINE,OBJPROP_PRICE);

   Lots = CalcLot(RiskPercent,EntryPrice,SLPrice);

   double dist=MathAbs(EntryPrice-SLPrice);

   if(CurrentMode==BUYMODE)
      TPPrice=EntryPrice+dist*RR;
   else
      TPPrice=EntryPrice-dist*RR;

   Comment(
      "=== CalLot v2 ===\n",
      "Mode : ",(CurrentMode==BUYMODE?"BUY LIMIT":"SELL LIMIT"),"\n",
      "Balance : ",AccountInfoDouble(ACCOUNT_BALANCE),"\n",
      "Risk % : ",RiskPercent,"\n",
      "Lot : ",Lots,"\n",
      "Entry : ",EntryPrice,"\n",
      "SL : ",SLPrice,"\n",
      "TP : ",TPPrice,"\n",
      "RR 1:",RR
   );
}

//================ GUARDS ======================
bool SpreadOK()
{
   double spread=(Ask-Bid)/_Point;
   if(spread>50) return false;
   return true;
}

bool OneTradePerBar()
{
   datetime bar=iTime(_Symbol,_Period,0);
   if(bar==lastTradeBar) return false;
   lastTradeBar=bar;
   return true;
}

//================ TRADE =======================
void PlaceOrder()
{
   if(!SpreadOK()) return;
   if(!OneTradePerBar()) return;

   if(CurrentMode==BUYMODE)
      trade.BuyLimit(Lots,EntryPrice,_Symbol,SLPrice,TPPrice);
   else
      trade.SellLimit(Lots,EntryPrice,_Symbol,SLPrice,TPPrice);
}

//================ EVENTS ======================
int OnInit()
{
   CreateSLLine();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectDelete(0,SL_LINE);
   Comment("");
}

void OnTick()
{
   UpdateCalc();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id==CHARTEVENT_KEYDOWN)
   {
      if(lparam=='B') CurrentMode=BUYMODE;
      if(lparam=='S') CurrentMode=SELLMODE;
      if(lparam=='1') RR=1.0;
      if(lparam=='2') RR=1.5;
      if(lparam=='3') RR=2.0;
      if(lparam=='O') PlaceOrder();
   }
}