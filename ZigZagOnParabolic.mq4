//+------------------------------------------------------------------+
//|                                              ZigZag on Parabolic |
//|                                 Copyright © 2009-2022, EarnForex |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009-2022, EarnForex"
#property link      "https://www.earnforex.com/metatrader-indicators/ZigZagOnParabolic/"
#property version   "1.02"
#property strict

#property description "ZigZag on Parabolic - an improved version of the standard MT4 indicator."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 clrAqua
#property indicator_type1  DRAW_ZIGZAG
#property indicator_label1 "Peak"
#property indicator_color2 clrAqua
#property indicator_type2  DRAW_ZIGZAG
#property indicator_label2 "Trough"
#property indicator_color3 clrBlue
#property indicator_type3  DRAW_ARROW
#property indicator_label3 "SAR"

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

void OnInit()
{
    SetIndexBuffer(0, ZigUp);
    SetIndexEmptyValue(0, 0);

    SetIndexBuffer(1, ZigDn);
    SetIndexEmptyValue(1, 0);

    SetIndexBuffer(2, SAR);
    SetIndexArrow(2, 159);
    SetIndexEmptyValue(2, 0);
}

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
    
    int counted_bars = IndicatorCounted();
    int limit = Bars - counted_bars;
    if (limit == Bars) limit -= 2; // Need a previous value too.
    
    if ((History != 0) && (limit > History)) limit = History - 1; // Normalizing with the History input parameter.

    for (int i = limit; i >= 0; i--)
    {
        static datetime LastAlertTime = 0;
    
        SAR[i] = iSAR(NULL, 0, Step, Maximum, i); // Parabolic SAR.
        
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
                h = High[i]; // New peak.
                j = rates_total - i; // Remember the bar.
            }
            if ((SAR[i + 1] <= mid[1]) && (SAR[i] > mid[0])) // Reverse of Parabolic SAR.
            {
                if (ExtremumsShift == ChartTime) shift = rates_total - j; // The maximum as it appeared on the chart.
                else shift = i; // Peak detection bar.
                ZigUp[shift] = h; // Peak.

                if ((i == 0) && (Time[0] > LastAlertTime)) // Check for alerts.
                {
                    string Text = "ZigZagOnParabolic: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - New Peak @ " + TimeToString(Time[shift]);
                    if (EnableNativeAlerts) Alert(Text);
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
            if ((SAR[i + 1] >= mid[1]) && (SAR[i] < mid[0])) // Reverse of Parabolic SAR.
            {
                if (ExtremumsShift == ChartTime) shift = rates_total - j; // The minimum as it appeared on the chart.
                else shift = i; // Trough detection bar.
                ZigDn[shift] = l; // Trough.

                if ((i == 0) && (Time[0] > LastAlertTime)) // Check for alerts.
                {
                    string Text = "ZigZagOnParabolic: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - New Trough @ " + TimeToString(Time[shift]);
                    if (EnableNativeAlerts) Alert(Text);
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