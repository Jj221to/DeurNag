//+------------------------------------------------------------------+
//|                                             FoxLogicProPlus.mq5  |
//|     Ultimate MT5 EA with Market Structure, Risk, Dashboard       |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>

input int    FastEMA = 9;
input int    SlowEMA = 21;
input int    RSIPeriod = 14;
input double RSIBuyLevel = 50;
input double RSISellLevel = 70;
input double RiskPercent = 1.0;
input double ATRMultiplierSL = 1.5;
input double ATRMultiplierTP = 2.5;
input bool   UseDynamicLot = true;
input bool   EnableDashboard = true;
input bool   EnableSessionFilter = true;
input bool   EnableNewsFilter = false;
input ENUM_TIMEFRAMES TimeframeSignal = PERIOD_M15;

CTrade trade;
int handleFastEMA, handleSlowEMA, handleRSI, handleATR;

double emaFast[], emaSlow[], rsi[], atr[];
double supportLevel = 0, resistanceLevel = 0;
string dashName = "FoxProDashboard";

enum MarketTrend {TREND_UNKNOWN=0, TREND_UP, TREND_DOWN};

//+------------------------------------------------------------------+
//| Corrected Market Structure Helpers                               |
//+------------------------------------------------------------------+
// Function to find the highest high in a range
double HighestHigh(int start, int end) {
    double max_val = 0;
    for (int i = start; i <= end; i++) {
        double val = iHigh(_Symbol, TimeframeSignal, i);
        if (val > max_val) {
            max_val = val;
        }
    }
    return max_val;
}

// Function to find the lowest low in a range
double LowestLow(int start, int end) {
    double min_val = DBL_MAX;
    for (int i = start; i <= end; i++) {
        double val = iLow(_Symbol, TimeframeSignal, i);
        if (val < min_val) {
            min_val = val;
        }
    }
    return min_val;
}

// A more robust way to detect swing highs
bool IsSwingHigh(int shift, int strength) {
    double central_high = iHigh(_Symbol, TimeframeSignal, shift);
    for (int i = 1; i <= strength; i++) {
        if (iHigh(_Symbol, TimeframeSignal, shift - i) > central_high || iHigh(_Symbol, TimeframeSignal, shift + i) > central_high) {
            return false;
        }
    }
    return true;
}

// A more robust way to detect swing lows
bool IsSwingLow(int shift, int strength) {
    double central_low = iLow(_Symbol, TimeframeSignal, shift);
    for (int i = 1; i <= strength; i++) {
        if (iLow(_Symbol, TimeframeSignal, shift - i) < central_low || iLow(_Symbol, TimeframeSignal, shift + i) < central_low) {
            return false;
        }
    }
    return true;
}

MarketTrend DetectMarketTrend() {
    // Look for the two most recent swing highs and lows
    double last_swing_high = 0, prev_swing_high = 0;
    double last_swing_low = 0, prev_swing_low = 0;
    int swing_high_count = 0;
    int swing_low_count = 0;

    for (int i = 1; i < 100 && (swing_high_count < 2 || swing_low_count < 2); i++) {
        if (swing_high_count < 2 && IsSwingHigh(i, 5)) {
            if (last_swing_high == 0) last_swing_high = iHigh(_Symbol, TimeframeSignal, i);
            else if (prev_swing_high == 0) prev_swing_high = iHigh(_Symbol, TimeframeSignal, i);
            swing_high_count++;
        }
        if (swing_low_count < 2 && IsSwingLow(i, 5)) {
            if (last_swing_low == 0) last_swing_low = iLow(_Symbol, TimeframeSignal, i);
            else if (prev_swing_low == 0) prev_swing_low = iLow(_Symbol, TimeframeSignal, i);
            swing_low_count++;
        }
    }

    // Determine trend based on the sequence of swing highs and lows
    if (last_swing_high > prev_swing_high && last_swing_low > prev_swing_low) {
        return TREND_UP;
    }
    if (last_swing_high < prev_swing_high && last_swing_low < prev_swing_low) {
        return TREND_DOWN;
    }
    return TREND_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   handleFastEMA = iMA(_Symbol, TimeframeSignal, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleSlowEMA = iMA(_Symbol, TimeframeSignal, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI     = iRSI(_Symbol, TimeframeSignal, RSIPeriod, PRICE_CLOSE);
   handleATR     = iATR(_Symbol, TimeframeSignal, 14);

   if (EnableDashboard)
      DrawDashboard("Initialized");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Dynamic lot calculation                                          |
//+------------------------------------------------------------------+
double CalcLots(double stopLossPoints)
{
   if (!UseDynamicLot || stopLossPoints <= 0)
      return 0.1;
   double risk = AccountFreeMargin() * RiskPercent / 100.0;
   double lotSize = risk / (stopLossPoints * _Point * 10);
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Trading session filter                                           |
//+------------------------------------------------------------------+
bool InSession()
{
   if (!EnableSessionFilter)
      return true;
   int hour = TimeHour(TimeLocal());
   return (hour >= 8 && hour <= 20);  // Default active session (London/NY)
}

//+------------------------------------------------------------------+
//| News filter placeholder                                          |
//+------------------------------------------------------------------+
bool PassNewsFilter()
{
   if (!EnableNewsFilter)
      return true;
   // Placeholder for future MyFxBook or ForexFactory API
   return true;
}

//+------------------------------------------------------------------+
//| Improved Support & resistance detection                          |
//+------------------------------------------------------------------+
void DetectSupportResistance() {
    // Reset levels at each tick
    supportLevel = 0;
    resistanceLevel = 0;

    // Scan for the most recent and significant S/R levels
    for (int i = 1; i < 150; i++) {
        // Look for a swing high to define a resistance level
        if (IsSwingHigh(i, 10)) { // Using a strength of 10 for significance
            double r = iHigh(_Symbol, TimeframeSignal, i);
            if (resistanceLevel == 0 || r > resistanceLevel) {
                resistanceLevel = r;
            }
        }
        // Look for a swing low to define a support level
        if (IsSwingLow(i, 10)) { // Using a strength of 10 for significance
            double s = iLow(_Symbol, TimeframeSignal, i);
            if (supportLevel == 0 || s < supportLevel) {
                supportLevel = s;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Dashboard display                                                |
//+------------------------------------------------------------------+
void DrawDashboard(string status)
{
   MarketTrend currentTrend = DetectMarketTrend();
   string trendText = "Unknown";
   if (currentTrend == TREND_UP) trendText = "Uptrend";
   if (currentTrend == TREND_DOWN) trendText = "Downtrend";

   string info = "🦊 FoxLogic Pro+ EA\\n" +
                 "EMA(" + FastEMA + "/" + SlowEMA + ") | RSI(" + RSIPeriod + ")\\n" +
                 "Risk: " + DoubleToString(RiskPercent, 1) + "% | SL/TP: ATR x " +
                 DoubleToString(ATRMultiplierSL, 1) + "/" + DoubleToString(ATRMultiplierTP, 1) + "\\n" +
                 "Support: " + DoubleToString(supportLevel, _Digits) +
                 " | Resistance: " + DoubleToString(resistanceLevel, _Digits) + "\\n" +
                 "Market Trend: " + trendText + "\\n" +
                 "Status: " + status;

   ObjectCreate(0, dashName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, dashName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, dashName, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, dashName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, dashName, OBJPROP_COLOR, clrLime);
   ObjectSetString(0, dashName, OBJPROP_TEXT, info);
}

//+------------------------------------------------------------------+
//| Refined Expert tick function                                     |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!InSession() || !PassNewsFilter())
        return;

    DetectSupportResistance();

    if (CopyBuffer(handleFastEMA, 0, 0, 2, emaFast) < 0 ||
        CopyBuffer(handleSlowEMA, 0, 0, 2, emaSlow) < 0 ||
        CopyBuffer(handleRSI, 0, 0, 1, rsi) < 0 ||
        CopyBuffer(handleATR, 0, 0, 1, atr) < 0)
        return;

    MarketTrend currentTrend = DetectMarketTrend();
    double current_price = Close[0];

    // Refined Bullish Entry:
    // 1. Market is in an uptrend.
    // 2. EMA crossover has just happened.
    // 3. RSI is above the buy level, but not overbought (e.g., < 80) to avoid buying at the peak.
    // 4. Price has pulled back to near a support level.
    bool bullish = (currentTrend == TREND_UP) &&
                   (emaFast[1] < emaSlow[1] && emaFast[0] > emaSlow[0]) &&
                   (rsi[0] > RSIBuyLevel && rsi[0] < 80) &&
                   (supportLevel > 0 && current_price >= supportLevel && (current_price - supportLevel) / _Point < (atr[0] * 0.5));

    // Refined Bearish Entry:
    // 1. Market is in a downtrend.
    // 2. EMA crossover has just happened.
    // 3. RSI is below the sell level, but not oversold (e.g., > 20) to avoid selling at the bottom.
    // 4. Price has pulled back to near a resistance level.
    bool bearish = (currentTrend == TREND_DOWN) &&
                   (emaFast[1] > emaSlow[1] && emaFast[0] < emaSlow[0]) &&
                   (rsi[0] < RSISellLevel && rsi[0] > 20) &&
                   (resistanceLevel > 0 && current_price <= resistanceLevel && (resistanceLevel - current_price) / _Point < (atr[0] * 0.5));

    double slPoints = atr[0] * ATRMultiplierSL / _Point;
    double tpPoints = atr[0] * ATRMultiplierTP / _Point;
    double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
    double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
    double lots = CalcLots(slPoints);

    if (bullish && PositionSelect(_Symbol) == false)
    {
        trade.Buy(lots, _Symbol, ask, ask - slPoints * _Point, ask + tpPoints * _Point, "FoxPro Buy");
        if (EnableDashboard) DrawDashboard("🟢 Buy Executed");
    }
    if (bearish && PositionSelect(_Symbol) == false)
    {
        trade.Sell(lots, _Symbol, bid, bid + slPoints * _Point, bid - tpPoints * _Point, "FoxPro Sell");
        if (EnableDashboard) DrawDashboard("🔴 Sell Executed");
    }
}
