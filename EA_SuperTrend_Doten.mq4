//+------------------------------------------------------------------+
//|                                         EA_SuperTrend_Doten.mq4 |
//|                                              Copyright 2025, LC |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, LC"
#property version   "1.00"
#property strict

//--- Input parameters
extern double   LotSize = 0.1;              // Lot size
extern int      Slippage = 30;              // Slippage in points
extern int      MagicNumber = 123456;       // Magic number
extern string   IndicatorPath = "Super Trend Indicator";  // Indicator file name

//--- SuperTrend indicator parameters
extern int      Periode = 10;               // ATR Period
extern double   Multiplier = 3.0;           // ATR Multiplier
extern bool     Show_Filling = true;        // Show Filling
extern int      MiddleType = 2;             // Middle Type (0-7, default 2=MIDDLE_HLC)

//--- Global variables
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA_SuperTrend_Doten initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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

   // Get signal from indicator (buffer index 8)
   double signal = iCustom(_Symbol, _Period, IndicatorPath,
                          Periode, Multiplier, Show_Filling, MiddleType,
                          8, 1);  // Buffer 8, Bar 1

   // Execute Doten strategy
   if(signal == 1)  // BUY signal
   {
      // Close all SELL positions
      CloseAllPositions(OP_SELL);

      // Open BUY position if not already in BUY
      if(!HasPosition(OP_BUY))
      {
         OpenPosition(OP_BUY);
      }
   }
   else if(signal == -1)  // SELL signal
   {
      // Close all BUY positions
      CloseAllPositions(OP_BUY);

      // Open SELL position if not already in SELL
      if(!HasPosition(OP_SELL))
      {
         OpenPosition(OP_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasPosition(int orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == _Symbol &&
            OrderMagicNumber() == MagicNumber &&
            OrderType() == orderType)
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
void CloseAllPositions(int orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == _Symbol &&
            OrderMagicNumber() == MagicNumber &&
            OrderType() == orderType)
         {
            double closePrice;
            color clr;

            if(orderType == OP_BUY)
            {
               closePrice = Bid;
               clr = clrRed;
            }
            else
            {
               closePrice = Ask;
               clr = clrBlue;
            }

            if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clr))
            {
               Print("Error closing position. Error code: ", GetLastError());
            }
            else
            {
               Print("Position closed successfully. Ticket: ", OrderTicket());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open new position                                                |
//+------------------------------------------------------------------+
void OpenPosition(int orderType)
{
   double openPrice;
   color clr;
   string orderTypeName;

   if(orderType == OP_BUY)
   {
      openPrice = Ask;
      clr = clrGreen;
      orderTypeName = "BUY";
   }
   else
   {
      openPrice = Bid;
      clr = clrRed;
      orderTypeName = "SELL";
   }

   Print("Opening ", orderTypeName, " position at ", openPrice);

   int ticket = OrderSend(_Symbol, orderType, LotSize, openPrice, Slippage,
                         0, 0, "SuperTrend Doten", MagicNumber, 0, clr);

   if(ticket < 0)
   {
      Print("Error opening position. Error code: ", GetLastError());
   }
   else
   {
      Print("Position opened successfully. Ticket: ", ticket);
   }
}
//+------------------------------------------------------------------+
