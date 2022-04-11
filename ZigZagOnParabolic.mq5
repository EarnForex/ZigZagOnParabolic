//+------------------------------------------------------------------+
//|                                              ZigZag on Parabolic |
//|                                 Copyright © 2009-2022, EarnForex |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009-2022, EarnForex"
#property link      "https://www.earnforex.com/metatrader-indicators/ZigZagOnParabolic/"
#property version   "1.02"

#property description "ZigZag on Parabolic - an improved version of the standard MT4 indicator."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2
#property indicator_color1  clrAqua
#property indicator_color2  clrBlue
#property indicator_type1   DRAW_ZIGZAG
#property indicator_type2   DRAW_ARROW
#property indicator_label1 "ZigZag"
#property indicator_label2 "SAR"

enum enum_extremum_position
{
    DetectionTime, // Detection time
    ChartTime // Chart time
};

input double Step = 0.02;
input double Maximum = 0.2;
input enum_extremum_position ExtremumsShift = ChartTime;
input int History = 0; // History: number of bars to look at. 0 - all.
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;

double ZigUp[],
       ZigDn[],
       SAR[];

int mySAR;

void OnInit()
{

    SetIndexBuffer(0, ZigUp, INDICATOR_DATA);
    SetIndexBuffer(1, ZigDn, INDICATOR_DATA);
    SetIndexBuffer(2, SAR, INDICATOR_DATA);

    ArraySetAsSeries(ZigUp, true);
    ArraySetAsSeries(ZigDn, true);
    ArraySetAsSeries(SAR, true);

    PlotIndexSetInteger(1, PLOT_ARROW, 159);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
    
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);

    mySAR = iSAR(NULL, 0, Step, Maximum);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &open[],
                const double &High[],
                const double &Low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    ArraySetAsSeries(High, true);
    ArraySetAsSeries(Low, true);
    ArraySetAsSeries(Time, true);

    static int j = 0; // Counter for the shift between the extremum detection and it's position.
    static bool dir = false; // Direction: false - down, true - up.
    static double h = -DBL_MAX, l = DBL_MAX; // Current extremums.

    if (prev_calculated == 0) // Recalculating everything from the beginning.
    {
        j = 0;
        dir = false;
        h = -DBL_MAX;
        l = DBL_MAX;
    }

    int counted_bars = prev_calculated;
    if (counted_bars > 0) counted_bars--;
    int limit = rates_total - counted_bars;
    if (limit == rates_total) limit -= 2; // Need a previous value too.

    if ((History != 0) && (limit > History)) limit = History - 1; // Normalizing with the History input parameter.

    int copied = CopyBuffer(mySAR, 0, 0, limit + 1, SAR);
    if (copied < limit + 1) return prev_calculated; // Parabolic SAR data buffer isn't ready yet.

    for (int i = limit; i >= 0; i--)
    {
        static datetime LastAlertTime = 0;
        double mid[2]; // Midpoint price.
        mid[0] = (High[i] + Low[i]) / 2; // Current bar.
        mid[1] = (High[i + 1] + Low[i + 1]) / 2; // Previous bar.

        int shift; // Shift between the extremum's detection bar and its actual location.

        // Initialize with zeros.
        ZigUp[i] = 0;
        ZigDn[i] = 0;

        if (dir) // Up.
        {
            if (h < High[i])
            {
                h = High[i]; // New high.
                j = rates_total - i; // Remember the bar.
            }
            if ((SAR[i + 1] <= mid[1]) && (SAR[i] > mid[0])) // Reverse of Parabolic SAR.
            {
                if (ExtremumsShift == ChartTime) shift = rates_total - j;//i + ExtremumsShift * (j + NewBar); // Shift between extremum detections and it's position.
                else shift = i;
                ZigUp[shift] = h; // Peak.

                if ((i == 0) && (Time[0] > LastAlertTime)) // Check for alerts.
                {
                    string Text = "ZigZagOnParabolic: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - New Peak @ " + TimeToString(Time[shift]);
                    string TextNative = "ZigZagOnParabolic: New Peak @ " + TimeToString(Time[shift]);
                    if (EnableNativeAlerts) Alert(TextNative);
                    if (EnableEmailAlerts) SendMail("ZigZagOnParabolic Alert", Text);
                    if (EnablePushAlerts) SendNotification(Text);
                    LastAlertTime = Time[0];
                }

                dir = false; // New direction - Down.
                l = Low[i]; // New current low.
                j = rates_total - i; // Remember the bar.
            }
        }
        else // Down.
        {
            if (l > Low[i])
            {
                l = Low[i]; // New low.
                j = rates_total - i; // Remember the bar.
            }
            if ((SAR[i + 1] >= mid[1]) && (SAR[i] < mid[0])) //Reverse of Parabolic SAR
            {
                if (ExtremumsShift == ChartTime) shift = rates_total - j; // The minimum as it appeared on the chart.
                else shift = i; // Trough detection bar.
                ZigDn[shift] = l; // Trough.

                if ((i == 0) && (Time[0] > LastAlertTime)) // Check for alerts.
                {
                    string Text = "ZigZagOnParabolic: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - New Trough @ " + TimeToString(Time[shift]);
                    string TextNative = "ZigZagOnParabolic: New Trough @ " + TimeToString(Time[shift]);
                    if (EnableNativeAlerts) Alert(TextNative);
                    if (EnableEmailAlerts) SendMail("ZigZagOnParabolic Alert", Text);
                    if (EnablePushAlerts) SendNotification(Text);
                    LastAlertTime = Time[0];
                }

                dir = true; // New direction - Up.
                h = High[i]; // New current peak.
                j = rates_total - i; // Reset the counter.
            }
        }
    }
    return rates_total;
}
//+------------------------------------------------------------------+