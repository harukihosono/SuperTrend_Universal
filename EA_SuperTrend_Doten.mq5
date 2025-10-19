//+------------------------------------------------------------------+
//|                                         EA_SuperTrend_Doten.mq5 |
//|                                              Copyright 2025, LC |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, LC"
#property version   "1.00"
#property strict

//--- Input parameters
input double   LotSize = 0.1;              // Lot size
input int      Slippage = 30;              // Slippage in points
input int      MagicNumber = 123456;       // Magic number
input string   IndicatorPath = "Super Trend Indicator.ex5";  // Indicator file name

//--- SuperTrend indicator parameters
input int      Periode = 10;               // ATR Period
input double   Multiplier = 3.0;           // ATR Multiplier
input bool     Show_Filling = true;        // Show Filling
input int      MiddleType = 2;             // Middle Type (0-7, default 2=MIDDLE_HLC)

//--- Global variables
int indicatorHandle;
double signalBuffer[];
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicator handle
   indicatorHandle = iCustom(_Symbol, _Period, IndicatorPath,
                             Periode, Multiplier, Show_Filling, MiddleType);

   if(indicatorHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handle. Error code: ", GetLastError());
      return(INIT_FAILED);
   }

   ArraySetAsSeries(signalBuffer, true);

   Print("EA_SuperTrend_Doten initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);

   Print("EA_SuperTrend_Doten deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   // Get signal from indicator (buffer index 9)
   if(CopyBuffer(indicatorHandle, 9, 0, 3, signalBuffer) <= 0)
   {
      Print("Error copying signal buffer. Error code: ", GetLastError());
      return;
   }

   // Check signal on bar 1 (completed bar)
   double signal = signalBuffer[1];

   // Execute Doten strategy
   if(signal == 1)  // BUY signal
   {
      // Close all SELL positions
      CloseAllPositions(POSITION_TYPE_SELL);

      // Open BUY position if not already in BUY
      if(!HasPosition(POSITION_TYPE_BUY))
      {
         OpenPosition(ORDER_TYPE_BUY);
      }
   }
   else if(signal == -1)  // SELL signal
   {
      // Close all BUY positions
      CloseAllPositions(POSITION_TYPE_BUY);

      // Open SELL position if not already in SELL
      if(!HasPosition(POSITION_TYPE_SELL))
      {
         OpenPosition(ORDER_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasPosition(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions of specific type                             |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = Slippage;
            request.magic = MagicNumber;

            if(posType == POSITION_TYPE_BUY)
            {
               request.type = ORDER_TYPE_SELL;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            }
            else
            {
               request.type = ORDER_TYPE_BUY;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            }

            if(!OrderSend(request, result))
            {
               Print("Error closing position. Error code: ", GetLastError());
               Print("Result code: ", result.retcode, ", Deal: ", result.deal);
            }
            else
            {
               Print("Position closed successfully. Ticket: ", ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open new position                                                |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   MqlTradeCheckResult checkResult;
   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(checkResult);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.type_filling = ORDER_FILLING_FOK;

   // Try different filling modes if FOK fails
   if(!OrderCheck(request, checkResult))
   {
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderCheck(request, checkResult))
      {
         request.type_filling = ORDER_FILLING_RETURN;
      }
   }

   if(orderType == ORDER_TYPE_BUY)
   {
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      Print("Opening BUY position at ", request.price);
   }
   else
   {
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Print("Opening SELL position at ", request.price);
   }

   if(!OrderSend(request, result))
   {
      Print("Error opening position. Error code: ", GetLastError());
      Print("Result code: ", result.retcode);
   }
   else
   {
      Print("Position opened successfully. Ticket: ", result.order, ", Deal: ", result.deal);
   }
}
//+------------------------------------------------------------------+
