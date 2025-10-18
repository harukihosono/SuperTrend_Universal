//+------------------------------------------------------------------+
//|                                      SuperTrend_EA_Universal.mq4/5 |
//|                                     Copyright 2025, Trading       |
//|                             Compatible with MQL4 and MQL5         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Trading"
#property link      ""
#property version   "1.00"
#property strict

//--- Input parameters
input int    MagicNumber = 123456;           // マジックナンバー
input double LotSize = 0.01;                 // ロットサイズ
input int    Slippage = 10;                  // スリッページ(pips)
input int    AtrPeriod = 10;                 // ATR期間
input double Multiplier = 3.0;               // 乗数
input bool   EnableEmailAlert = false;       // メール通知
input bool   EnablePushAlert = false;        // プッシュ通知

//--- Global variables
int lastAlertBar = -1;
int lastTrendBar = -1;
double lastTrend = 0;

#ifdef __MQL5__
   #include <Trade\Trade.mqh>
   CTrade trade;
   int atrHandle;
   int indicatorHandle;
#endif

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   #ifdef __MQL5__
   //--- create ATR handle
   atrHandle = iATR(_Symbol, _Period, AtrPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return(INIT_FAILED);
   }

   //--- create custom indicator handle
   indicatorHandle = iCustom(_Symbol, _Period, "SuperTrend_Universal", AtrPeriod, Multiplier, false, false);
   if(indicatorHandle == INVALID_HANDLE)
   {
      Print("Failed to create SuperTrend indicator");
      return(INIT_FAILED);
   }
   #endif

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   #ifdef __MQL5__
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
   #endif
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- check for new bar
   static int prevBars = 0;
   #ifdef __MQL4__
   int currentBars = Bars;
   #else
   int currentBars = Bars(_Symbol, _Period);
   #endif

   if(currentBars > prevBars)
   {
      prevBars = currentBars;
      lastAlertBar = -1;
   }

   //--- get current trend from indicator
   double trendValue = GetTrendValue();
   if(trendValue == EMPTY_VALUE)
      return;

   //--- check for trend change
   bool isTrendChange = false;
   if(lastTrendBar != 0 && lastTrend != 0 && lastTrend != trendValue)
   {
      isTrendChange = true;
   }

   lastTrend = trendValue;
   lastTrendBar = 0;

   //--- if no trend change, exit
   if(!isTrendChange)
      return;

   //--- check if we already have a position
   int positionType = GetPositionType();

   //--- trend changed to uptrend (bullish)
   if(trendValue == 1)
   {
      //--- send alert
      if(lastAlertBar != 0 && (EnableEmailAlert || EnablePushAlert))
      {
         SendAlert("上昇トレンド (Bullish)");
         lastAlertBar = 0;
      }

      //--- close sell positions
      if(positionType == -1)
         CloseAllPositions();

      //--- open buy position
      if(positionType == 0)
         OpenPosition(true);
   }
   //--- trend changed to downtrend (bearish)
   else if(trendValue == -1)
   {
      //--- send alert
      if(lastAlertBar != 0 && (EnableEmailAlert || EnablePushAlert))
      {
         SendAlert("下降トレンド (Bearish)");
         lastAlertBar = 0;
      }

      //--- close buy positions
      if(positionType == 1)
         CloseAllPositions();

      //--- open sell position
      if(positionType == 0)
         OpenPosition(false);
   }
}

//+------------------------------------------------------------------+
//| Get current trend from indicator                                 |
//+------------------------------------------------------------------+
double GetTrendValue()
{
   #ifdef __MQL4__
   double trend = iCustom(NULL, 0, "SuperTrend_Universal", AtrPeriod, Multiplier, false, false, 2, 1);
   return trend;
   #else
   double trendArray[];
   ArraySetAsSeries(trendArray, true);
   if(CopyBuffer(indicatorHandle, 2, 0, 2, trendArray) < 2)
      return EMPTY_VALUE;
   return trendArray[1];
   #endif
}

//+------------------------------------------------------------------+
//| Get current position type                                        |
//| Returns: 1=buy, -1=sell, 0=no position                          |
//+------------------------------------------------------------------+
int GetPositionType()
{
   #ifdef __MQL4__
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
         return 1;
      else if(OrderType() == OP_SELL)
         return -1;
   }
   return 0;
   #else
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)
         return 1;
      else if(posType == POSITION_TYPE_SELL)
         return -1;
   }
   return 0;
   #endif
}

//+------------------------------------------------------------------+
//| Open position                                                     |
//+------------------------------------------------------------------+
void OpenPosition(bool isBuy)
{
   double lotSize = NormalizeLotSize(LotSize);
   if(lotSize == 0)
      return;

   #ifdef __MQL4__
   int ticket;
   if(isBuy)
      ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, Slippage, 0, 0, "SuperTrend EA", MagicNumber, 0, clrGreen);
   else
      ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, Slippage, 0, 0, "SuperTrend EA", MagicNumber, 0, clrRed);

   if(ticket < 0)
      Print("OrderSend failed: ", GetLastError());
   #else
   bool result;
   if(isBuy)
      result = trade.Buy(lotSize, _Symbol, 0, 0, 0, "SuperTrend EA");
   else
      result = trade.Sell(lotSize, _Symbol, 0, 0, 0, "SuperTrend EA");

   if(!result)
      Print("Trade failed: ", trade.ResultRetcode());
   #endif
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   #ifdef __MQL4__
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
      {
         if(!OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrWhite))
            Print("OrderClose failed: ", GetLastError());
      }
      else if(OrderType() == OP_SELL)
      {
         if(!OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrWhite))
            Print("OrderClose failed: ", GetLastError());
      }
   }
   #else
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      if(!trade.PositionClose(ticket))
         Print("PositionClose failed: ", trade.ResultRetcode());
   }
   #endif
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lots)
{
   #ifdef __MQL4__
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   #else
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   #endif

   if(lotStep == 0)
      lotStep = 0.01;

   lots = MathFloor(lots / lotStep) * lotStep;

   if(lots < minLot)
      lots = minLot;
   if(lots > maxLot)
      lots = maxLot;

   int lotDigits = 2;
   if(lotStep == 0.01)
      lotDigits = 2;
   else if(lotStep == 0.1)
      lotDigits = 1;
   else
      lotDigits = 0;

   return NormalizeDouble(lots, lotDigits);
}

//+------------------------------------------------------------------+
//| Send Alert Function                                              |
//+------------------------------------------------------------------+
void SendAlert(string trendType)
{
   string symbol = _Symbol;
   string timeframe = GetTimeframeName();
   string message = "SuperTrend EA: " + symbol + " " + timeframe + " - " + trendType;

   if(EnableEmailAlert)
      SendMail("SuperTrend EA Alert", message);

   if(EnablePushAlert)
      SendNotification(message);
}

//+------------------------------------------------------------------+
//| Get Timeframe Name                                               |
//+------------------------------------------------------------------+
string GetTimeframeName()
{
   #ifdef __MQL4__
   int period = Period();
   #else
   ENUM_TIMEFRAMES period = _Period;
   #endif

   switch(period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return IntegerToString(period);
   }
}
//+------------------------------------------------------------------+
