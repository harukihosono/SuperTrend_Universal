//+------------------------------------------------------------------+
//|                                        SuperTrend_Universal.mq4/5 |
//|                                     Copyright 2025, Trading       |
//|                             Compatible with MQL4 and MQL5         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Trading"
#property link      ""
#property version   "3.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_color1 clrGreen
#property indicator_color2 clrRed
#property indicator_width1 2
#property indicator_width2 2
#property indicator_type1 DRAW_LINE
#property indicator_type2 DRAW_LINE

//--- Input parameters
input int    AtrPeriod = 10;                 // ATR期間
input double Multiplier = 3.0;               // 乗数
input bool   EnableEmailAlert = false;       // メール通知
input bool   EnablePushAlert = false;        // プッシュ通知

//--- Indicator buffers
double UpTrendBuffer[];    // 表示用：上昇トレンド（緑）
double DownTrendBuffer[];  // 表示用：下降トレンド（赤）
double UpBand[];           // 計算用：上のバンド
double DownBand[];         // 計算用：下のバンド
double TrendBuffer[];      // トレンド方向 (1=上昇, -1=下降)
double ColorBuffer[];      // 将来の拡張用

//--- Global variables
int lastAlertBar = -1;

#ifdef __MQL5__
   #define IndicatorDigits _Digits
   int atrHandle;
#endif

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
#ifdef __MQL4__
int OnInit()
#else
int OnInit()
#endif
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, UpTrendBuffer);
   SetIndexBuffer(1, DownTrendBuffer);
   SetIndexBuffer(2, UpBand);
   SetIndexBuffer(3, DownBand);
   SetIndexBuffer(4, TrendBuffer);
   SetIndexBuffer(5, ColorBuffer);

   #ifdef __MQL4__
   //--- MQL4 drawing settings
   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2, clrGreen);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2, clrRed);
   SetIndexStyle(2, DRAW_NONE);
   SetIndexStyle(3, DRAW_NONE);
   SetIndexStyle(4, DRAW_NONE);
   SetIndexStyle(5, DRAW_NONE);

   SetIndexLabel(0, "SuperTrend Up");
   SetIndexLabel(1, "SuperTrend Down");

   SetIndexEmptyValue(0, 0);
   SetIndexEmptyValue(1, 0);
   #else
   //--- MQL5 settings
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrGreen);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrRed);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);

   PlotIndexSetString(0, PLOT_LABEL, "SuperTrend Up");
   PlotIndexSetString(1, PLOT_LABEL, "SuperTrend Down");

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);

   //--- create ATR indicator handle
   atrHandle = iATR(_Symbol, _Period, AtrPeriod);
   if(atrHandle == INVALID_HANDLE)
      return(INIT_FAILED);

   ArraySetAsSeries(UpTrendBuffer, true);
   ArraySetAsSeries(DownTrendBuffer, true);
   ArraySetAsSeries(TrendBuffer, true);
   ArraySetAsSeries(ColorBuffer, true);
   #endif

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   #ifdef __MQL5__
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   #endif
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
#ifdef __MQL4__
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
   int limit;

   //--- check for new bar
   static int prevBars = 0;
   if(Bars > prevBars)
   {
      prevBars = Bars;
      lastAlertBar = -1;
   }

   //--- set limit for calculation
   if(prev_calculated == 0)
      limit = rates_total - AtrPeriod - 1;
   else
      limit = rates_total - prev_calculated;

   //--- main loop
   for(int i = limit; i >= 0; i--)
   {
      //--- calculate ATR
      double atr = iATR(NULL, 0, AtrPeriod, i);

      //--- calculate HLC/3 (middle price)
      double hlc3 = (high[i] + low[i] + close[i]) / 3.0;

      //--- calculate basic upper and lower bands
      UpBand[i] = hlc3 + (Multiplier * atr);
      DownBand[i] = hlc3 - (Multiplier * atr);

      //--- adjust bands based on previous values (trend continuation)
      if(i < rates_total - 1)
      {
         // 下のバンド調整：トレンド継続時は前回値を下回らないように
         if(DownBand[i] < DownBand[i+1] || close[i+1] < DownBand[i+1])
            DownBand[i] = DownBand[i];
         else
            DownBand[i] = DownBand[i+1];

         // 上のバンド調整：トレンド継続時は前回値を上回らないように
         if(UpBand[i] > UpBand[i+1] || close[i+1] > UpBand[i+1])
            UpBand[i] = UpBand[i];
         else
            UpBand[i] = UpBand[i+1];
      }

      //--- determine trend
      double currentTrend;

      if(i < rates_total - 1)
      {
         // トレンド判定：前回のバンド値と比較
         if(close[i] > UpBand[i+1])
            currentTrend = 1;  // 上昇トレンド
         else if(close[i] < DownBand[i+1])
            currentTrend = -1; // 下降トレンド
         else
            currentTrend = TrendBuffer[i+1]; // 前のトレンドを継続
      }
      else
      {
         currentTrend = 1;
      }

      //--- save trend
      TrendBuffer[i] = currentTrend;

      //--- set display buffers based on trend
      if(currentTrend == 1)
      {
         // 上昇トレンド：下のバンドを緑で表示
         UpTrendBuffer[i] = DownBand[i];
         DownTrendBuffer[i] = 0;
         ColorBuffer[i] = 0;  // Green

         //--- check for trend change to uptrend
         if(i == 0 && i < rates_total - 1 && TrendBuffer[i+1] == -1 && lastAlertBar != 0)
         {
            if(EnableEmailAlert || EnablePushAlert)
               SendAlert("上昇トレンド (Bullish)");
            lastAlertBar = 0;
         }
      }
      else
      {
         // 下降トレンド：上のバンドを赤で表示
         UpTrendBuffer[i] = 0;
         DownTrendBuffer[i] = UpBand[i];
         ColorBuffer[i] = 1;  // Red

         //--- check for trend change to downtrend
         if(i == 0 && i < rates_total - 1 && TrendBuffer[i+1] == 1 && lastAlertBar != 0)
         {
            if(EnableEmailAlert || EnablePushAlert)
               SendAlert("下降トレンド (Bearish)");
            lastAlertBar = 0;
         }
      }
   }

   return(rates_total);
}
#else
//--- MQL5 version
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
   int limit;
   double atrArray[];

   //--- check for new bar
   static int prevBars = 0;
   if(rates_total > prevBars)
   {
      prevBars = rates_total;
      lastAlertBar = -1;
   }

   //--- set limit for calculation
   if(prev_calculated == 0)
      limit = rates_total - AtrPeriod - 1;
   else
      limit = rates_total - prev_calculated;

   //--- prepare ATR array
   ArraySetAsSeries(atrArray, true);
   if(CopyBuffer(atrHandle, 0, 0, rates_total, atrArray) < 0)
      return(0);

   //--- main loop (MQL5 uses reversed indexing)
   for(int i = limit; i >= 0; i--)
   {
      int pos = rates_total - 1 - i;

      //--- calculate HLC/3
      double hlc3 = (high[pos] + low[pos] + close[pos]) / 3.0;

      //--- calculate basic upper and lower bands
      double basicUpperBand = hlc3 + (Multiplier * atrArray[i]);
      double basicLowerBand = hlc3 - (Multiplier * atrArray[i]);

      //--- calculate final upper and lower bands
      double finalUpperBand = basicUpperBand;
      double finalLowerBand = basicLowerBand;

      if(i < rates_total - 1)
      {
         if(DownTrendBuffer[i+1] != 0)
         {
            if(basicLowerBand > DownTrendBuffer[i+1] || close[pos] < DownTrendBuffer[i+1])
               finalLowerBand = basicLowerBand;
            else
               finalLowerBand = DownTrendBuffer[i+1];
         }

         if(UpTrendBuffer[i+1] != 0)
         {
            if(basicUpperBand < UpTrendBuffer[i+1] || close[pos] > UpTrendBuffer[i+1])
               finalUpperBand = basicUpperBand;
            else
               finalUpperBand = UpTrendBuffer[i+1];
         }
      }

      //--- determine trend
      double currentTrend;

      if(i < rates_total - 1)
      {
         if(close[pos] > finalUpperBand)
            currentTrend = 1;
         else if(close[pos] < finalLowerBand)
            currentTrend = -1;
         else
            currentTrend = TrendBuffer[i+1];
      }
      else
      {
         currentTrend = 1;
      }

      //--- save values to buffers
      TrendBuffer[i] = currentTrend;

      if(currentTrend == 1)
      {
         UpTrendBuffer[i] = finalLowerBand;
         DownTrendBuffer[i] = 0;
         ColorBuffer[i] = 0;

         //--- check for trend change
         if(i == 0 && i < rates_total - 1 && TrendBuffer[i+1] == -1 && lastAlertBar != 0)
         {
            if(EnableEmailAlert || EnablePushAlert)
               SendAlert("上昇トレンド (Bullish)");
            lastAlertBar = 0;
         }
      }
      else
      {
         UpTrendBuffer[i] = 0;
         DownTrendBuffer[i] = finalUpperBand;
         ColorBuffer[i] = 1;

         //--- check for trend change
         if(i == 0 && i < rates_total - 1 && TrendBuffer[i+1] == 1 && lastAlertBar != 0)
         {
            if(EnableEmailAlert || EnablePushAlert)
               SendAlert("下降トレンド (Bearish)");
            lastAlertBar = 0;
         }
      }
   }

   return(rates_total);
}
#endif

//+------------------------------------------------------------------+
//| Send Alert Function                                              |
//+------------------------------------------------------------------+
void SendAlert(string trendType)
{
   string symbol = _Symbol;
   string timeframe = GetTimeframeName();
   string message = "SuperTrend: " + symbol + " " + timeframe + " - " + trendType;

   if(EnableEmailAlert)
      SendMail("SuperTrend Alert", message);

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
