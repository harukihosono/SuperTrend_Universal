//+------------------------------------------------------------------+
//|                                              SuperTrend.mq5      |
//|                                      Copyright 2011, FxGeek      |
//|                                            http://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2011, FxGeek"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   2

#property indicator_label1  "Filling"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'40,40,40', C'40,40,40'

#property indicator_label2  "SuperTrend"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrGreen, clrRed, clrNONE
#property indicator_width2  4

//--- 中央価格の計算方法を選択するenum
enum ENUM_MIDDLE_TYPE
{
   MIDDLE_OPEN,     // 始値
   MIDDLE_HIGH,     // 高値
   MIDDLE_LOW,      // 安値
   MIDDLE_CLOSE,    // 終値
   MIDDLE_HL,       // 高値+安値の平均
   MIDDLE_HLC,      // 高値+安値+終値の平均
   MIDDLE_OHLC,     // 始値+高値+安値+終値の平均
   MIDDLE_HLCC      // 高値+安値+終値x2の平均
};

input int    Periode = 10;
input double Multiplier = 3;
input bool   Show_Filling = true;         // Show as DRAW_FILLING
input ENUM_MIDDLE_TYPE MiddleType = MIDDLE_HLC;     // 中央価格の計算方法
input bool   EnableEmailAlert = false;    // メール通知
input bool   EnablePushAlert = false;     // プッシュ通知

double Filled_a[];
double Filled_b[];
double SuperTrend[];
double ColorBuffer[];
double Atr[];
double Up[];
double Down[];
double Middle[];
double trend[];

int atrHandle;
int changeOfTrend;
int flag;
int flagh;
int lastAlertBar = -1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, Filled_a, INDICATOR_DATA);
   SetIndexBuffer(1, Filled_b, INDICATOR_DATA);
   SetIndexBuffer(2, SuperTrend, INDICATOR_DATA);
   SetIndexBuffer(3, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, Atr, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, Up, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, Down, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, Middle, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, trend, INDICATOR_CALCULATIONS);

   atrHandle = iATR(_Symbol, _Period, Periode);
   //---
   return(0);
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
   //---
   int to_copy;
   if(prev_calculated > rates_total || prev_calculated < 0) to_copy = rates_total;
   else
   {
      to_copy = rates_total - prev_calculated;
      if(prev_calculated > 0) to_copy++;
   }

   if(IsStopped()) return(0);

   if(CopyBuffer(atrHandle, 0, 0, to_copy, Atr) <= 0)
   {
      Print("Getting Atr is failed! Error", GetLastError());
      return(0);
   }

   int first;
   if(prev_calculated > rates_total || prev_calculated <= 0)
   {
      first = Periode;
   }
   else
   {
      first = prev_calculated - 1;
   }

   for(int i = first; i < rates_total && !IsStopped(); i++)
   {
      // 中央価格を計算
      switch(MiddleType)
      {
         case MIDDLE_OPEN:
            Middle[i] = open[i];
            break;
         case MIDDLE_HIGH:
            Middle[i] = high[i];
            break;
         case MIDDLE_LOW:
            Middle[i] = low[i];
            break;
         case MIDDLE_CLOSE:
            Middle[i] = close[i];
            break;
         case MIDDLE_HL:
            Middle[i] = (high[i] + low[i]) / 2;
            break;
         case MIDDLE_HLC:
            Middle[i] = (high[i] + low[i] + close[i]) / 3;
            break;
         case MIDDLE_OHLC:
            Middle[i] = (open[i] + high[i] + low[i] + close[i]) / 4;
            break;
         case MIDDLE_HLCC:
            Middle[i] = (high[i] + low[i] + close[i] * 2) / 4;
            break;
      }

      Up[i] = Middle[i] + (Multiplier * Atr[i]);
      Down[i] = Middle[i] - (Multiplier * Atr[i]);

      if(close[i] > Up[i-1])
      {
         trend[i] = 1;
         if(trend[i-1] == -1) changeOfTrend = 1;
      }
      else if(close[i] < Down[i-1])
      {
         trend[i] = -1;
         if(trend[i-1] == 1) changeOfTrend = 1;
      }
      else if(trend[i-1] == 1)
      {
         trend[i] = 1;
         changeOfTrend = 0;
      }
      else if(trend[i-1] == -1)
      {
         trend[i] = -1;
         changeOfTrend = 0;
      }

      if(trend[i] < 0 && trend[i-1] > 0)
      {
         flag = 1;
      }
      else
      {
         flag = 0;
      }

      if(trend[i] > 0 && trend[i-1] < 0)
      {
         flagh = 1;
      }
      else
      {
         flagh = 0;
      }

      if(trend[i] > 0 && Down[i] < Down[i-1])
         Down[i] = Down[i-1];

      if(trend[i] < 0 && Up[i] > Up[i-1])
         Up[i] = Up[i-1];

      if(flag == 1)
         Up[i] = Middle[i] + (Multiplier * Atr[i]);

      if(flagh == 1)
         Down[i] = Middle[i] - (Multiplier * Atr[i]);

      if(trend[i] == 1)
      {
         SuperTrend[i] = Down[i];
         if(changeOfTrend == 1)
         {
            SuperTrend[i-1] = SuperTrend[i-2];
            changeOfTrend = 0;
            ColorBuffer[i] = 2.0;     // バッファ接続用
            ColorBuffer[i-1] = 2.0;   // 前のバッファ接続用
         }
         else
         {
            ColorBuffer[i] = 0.0;
         }
      }
      else if(trend[i] == -1)
      {
         SuperTrend[i] = Up[i];
         if(changeOfTrend == 1)
         {
            SuperTrend[i-1] = SuperTrend[i-2];
            changeOfTrend = 0;
            ColorBuffer[i] = 2.0;     // バッファ接続用
            ColorBuffer[i-1] = 2.0;   // 前のバッファ接続用
         }
         else
         {
            ColorBuffer[i] = 1.0;
         }
      }

      if(Show_Filling)
      {
         Filled_a[i] = SuperTrend[i];
         Filled_b[i] = close[i];
      }
      else
      {
         Filled_a[i] = EMPTY_VALUE;
         Filled_b[i] = EMPTY_VALUE;
      }

      //--- アラート送信（最新バーでトレンド転換があった場合）
      if(i == rates_total - 1 && i != lastAlertBar)
      {
         if(trend[i] == 1 && trend[i-1] == -1)
         {
            if(EnableEmailAlert || EnablePushAlert)
            {
               string symbol = _Symbol;
               string timeframe = "";
               switch(_Period)
               {
                  case PERIOD_M1:  timeframe = "M1"; break;
                  case PERIOD_M5:  timeframe = "M5"; break;
                  case PERIOD_M15: timeframe = "M15"; break;
                  case PERIOD_M30: timeframe = "M30"; break;
                  case PERIOD_H1:  timeframe = "H1"; break;
                  case PERIOD_H4:  timeframe = "H4"; break;
                  case PERIOD_D1:  timeframe = "D1"; break;
                  case PERIOD_W1:  timeframe = "W1"; break;
                  case PERIOD_MN1: timeframe = "MN1"; break;
                  default:         timeframe = IntegerToString(_Period);
               }
               string message = "SuperTrend: " + symbol + " " + timeframe + " - 上昇トレンド (Bullish)";
               if(EnableEmailAlert) SendMail("SuperTrend Alert", message);
               if(EnablePushAlert) SendNotification(message);
               lastAlertBar = i;
            }
         }
         else if(trend[i] == -1 && trend[i-1] == 1)
         {
            if(EnableEmailAlert || EnablePushAlert)
            {
               string symbol = _Symbol;
               string timeframe = "";
               switch(_Period)
               {
                  case PERIOD_M1:  timeframe = "M1"; break;
                  case PERIOD_M5:  timeframe = "M5"; break;
                  case PERIOD_M15: timeframe = "M15"; break;
                  case PERIOD_M30: timeframe = "M30"; break;
                  case PERIOD_H1:  timeframe = "H1"; break;
                  case PERIOD_H4:  timeframe = "H4"; break;
                  case PERIOD_D1:  timeframe = "D1"; break;
                  case PERIOD_W1:  timeframe = "W1"; break;
                  case PERIOD_MN1: timeframe = "MN1"; break;
                  default:         timeframe = IntegerToString(_Period);
               }
               string message = "SuperTrend: " + symbol + " " + timeframe + " - 下降トレンド (Bearish)";
               if(EnableEmailAlert) SendMail("SuperTrend Alert", message);
               if(EnablePushAlert) SendNotification(message);
               lastAlertBar = i;
            }
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
