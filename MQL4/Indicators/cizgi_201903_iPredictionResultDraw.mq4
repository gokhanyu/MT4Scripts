//+------------------------------------------------------------------+
//|                            cizgi_201901_PredictionResultDraw.mq4 |
//|                              Copyright 2019, Dune Software Corp. |
//|                                                                  |
//+------------------------------------------------------------------+

#include <mql4-http.mqh>
#include <Lang/Script.mqh>
#include <Collection/HashMap.mqh>
#include <Utils/File.mqh>
#include <Format/Json.mqh>
#include "hash-json2.mqh"


#property indicator_minimum -0.05
#property indicator_maximum 1.05
#property indicator_separate_window
//#property indicator_chart_window


#property copyright "Copyright 2019, Dune Software Corp."
#property description "Prediction Result Draw"
#property link      ""
#property version   "1.00"
#property strict

#property indicator_buffers 1       // Number of buffers
#property indicator_color1 Red      // Color of the 1st line
#property indicator_color2 Blue     // Color of the 2nd line



//&timePeriod=H4
string JsonUrlDefinition[] = { //timePeriod= is added parametrically
   
};

int TimeToAddList[] = {
   0,
   -3600,
   -3600,
   -3600,
   -3600,
   -3600,
   0,
   0,
   0,
   0,
   0,
   0,
   0,
   0,
   0,
   0,  
};

enum JsonUrlSelection 
{
   TS_TEST,
   ON_MODEL_20190324,
   ON_MODEL_20190331,
   ON_MODEL_20190407_H4,
   ON_MODEL_20190407_M30,
   ON_MODEL_20190414_H4,
   ON_MODEL_20190421_H4,
   ON_MODEL_20190421_M30,
   ON_MODEL_20190428_H4,
   ON_MODEL_20190428_M30,
};

enum TimeFrames
{
   UND, MN1, MN, W1, D1, H4, H1, M30, M15, M5, M1
};


//--- indicator parameters
input JsonUrlSelection JsonUrlType = ON_MODEL_20190414_H4;
input TimeFrames FileTimePeriod = H4;
extern bool LoadFromServer = false;
input datetime StartTime = D'2019.01.01 00:00';
input int AddMinutesToTimeDictionary = -1;
input bool DEBUG = false;


//--- indicator buffer
double ExtLineBuffer[];
string m_getData;
HashMap<string,int> m_dates;

int m_pastPredCount;
int m_futurePredCount;
int m_predCount;
static datetime m_lastRunTime;
datetime m_time0;


int InpMAPeriod=13;        // Period
ENUM_MA_METHOD InpMAMethod=MODE_SMA;     // Method
int            InpMAShift=-100;          // Shift




string GetTimeFrame(int lPeriod)
{
   switch(lPeriod)
   {
      case 1: return("M1");
      case 5: return("M5");
      case 15: return("M15"); 
      case 30: return("M30");
      case 60: return("H1");
      case 240: return("H4");
      case 1440: return("D1");
      case 10080: return("W1"); 
      case 43200: return("MN1"); 
   }
   
   return "UND";
}


string GetIndicatorName()
{
   string replace = EnumToString(JsonUrlType);
   StringReplace(replace, "CRAZYNAT_MODEL_", "");
   StringReplace(replace, "MOON_MODEL_", "");
   return "MOON WALKER   " + replace;
}


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
{
   IndicatorShortName(GetIndicatorName());
   IndicatorDigits(Digits);

   //--- check for input
   if(InpMAPeriod<2)
   {
      return(INIT_FAILED);
   }
     
   //--- drawing settings
   SetIndexStyle(0,DRAW_LINE);
   //SetIndexShift(0,50); //Minus index pulls back data in time, plus index shifts towards future
   //SetIndexDrawBegin(0,draw_begin);

   //--- indicator buffers mapping
   SetIndexBuffer(0,ExtLineBuffer);

   return(INIT_SUCCEEDED);
}
  
  
  
  
//+------------------------------------------------------------------+
//|  MAIN METHOD THAT TRIGGERS (ONCE AT START AND EVERY TICK)                                                  |
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
   //Alert(Period());

 
   //--- check for bars count
   if(rates_total<InpMAPeriod-1 || InpMAPeriod<2)
      return(0);
      
   //--- counting from 0 to rates_total
   ArraySetAsSeries(ExtLineBuffer, false);
   ArraySetAsSeries(close, false);
   
   // first calculation or number of bars was changed
   if(prev_calculated == 0)
   {
      ArrayInitialize(ExtLineBuffer,0);
      
      PrintFormat("(iPredictionResultDraw).. Starting up   TimeGMT(): %s    TimeCurrent(): %s    TimeGMTOffset: %i    Time0:  %s", TimeToStr(TimeGMT(), TIME_DATE|TIME_SECONDS), 
         TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS), TimeGMTOffset(),  TimeToStr(time[0], TIME_DATE|TIME_SECONDS) );
   }
   
   double diffHour = (time[0] - m_lastRunTime) / 60;
   
   if (diffHour > 1)
   {
      if (DEBUG)
      {
         Print("Prediction Plot Start:  " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      }
   
      string jsonURL = JsonUrlDefinition[JsonUrlType];
      jsonURL = jsonURL + "&fileTimePeriod=" + GetTimeFrame(Period());
      jsonURL = jsonURL + "&displayTimePeriod=" + EnumToString(FileTimePeriod);
      jsonURL = jsonURL + "&brokerTimeCurrent=" + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      jsonURL = jsonURL + "&brokerLastBarTime=" + TimeToStr(time[0], TIME_DATE|TIME_SECONDS);
      jsonURL = jsonURL + "&machineGMT=" + TimeToStr(TimeGMT(), TIME_DATE|TIME_SECONDS);
      jsonURL = jsonURL + "&timeGMTOffset=" + TimeGMTOffset();
      StringReplace(jsonURL, " ", "_");
      
      
      if (LoadFromServer)
      {
         int replaced=StringReplace(jsonURL, "", "");
      }      
      
      Print("JsonURL ", jsonURL);
      m_getData = httpGET(jsonURL);    
        
      if (DEBUG)
      {
         Print("Data is ", m_getData);
      }
      
      DrawWithExistingData(time);
      
      m_lastRunTime = time[0];    
   }
   else
   {
      DrawWithExistingData(time);
   }
   
   return(rates_total);
}


void DrawWithExistingData(const datetime &time[])
{
      PrepareDateTimeDictionary(time);
      
      ParseJson(time[0]);
      
      int shiftCount = ArraySize(time) - m_pastPredCount;

      PrintFormat("Total array size: %i    PastPrediction: %i    ShiftCount: %i", ArraySize(time), m_pastPredCount, shiftCount);
      
      SetIndexShift(0, shiftCount); //Minus index pulls back data in time, plus index shifts towards future. First parameter is the buffer index
}


void PrepareDateTimeDictionary(const datetime &time[])
{
   int arraySize = ArraySize(time);
   
   m_dates.clear(); 
   
   for (int i = 0; i < arraySize; i++)
   {
      //Print( TimeToStr(time[i]+AddMinutesToTimeDictionary, TIME_DATE|TIME_SECONDS));
      if (AddMinutesToTimeDictionary != -1)
      {
         m_dates.set(time[i]+AddMinutesToTimeDictionary, 1);
      }
      else
      {
         m_dates.set(time[i]+TimeToAddList[JsonUrlType], 1);
      }      
   }
}


int ParseJson(datetime lastTickTime)
{
    m_futurePredCount = 0;
    m_pastPredCount = 0;
    m_predCount = 0;

    Print("Trying to parse JSON.." + TimeToStr(lastTickTime, TIME_DATE|TIME_SECONDS));
   
    JSONParser *parser = new JSONParser();
    JSONValue *jv = parser.parse(m_getData);
    //JSONArray *ja = parser.parseArray();
    
    if (jv == NULL) 
    {
        Print("error:"+(string)parser.getErrorCode()+parser.getErrorMessage());
    } 
    else 
    {
         if (DEBUG)
         {
            Print("Json parsed as string: "+jv.toString());
         }
         
         if (jv.isObject()) 
         {
            Print("String is an JSON object.");
        
            JSONObject *jo = jv;
            int jaaCount = jo.getInt("ForecastCount");
            Print("Got ForecastCount");
            
            string forecastStartStr = jo.getString("ForecastStartDate");
            datetime forecastStart = StringToTime(forecastStartStr);
            ObjectCreate("VLINE"+forecastStartStr, OBJ_VLINE, 0, forecastStart, Bid);
            
            JSONArray *jaa = jo.getArray("Forecasts");
            
            if (jaa.isArray() && jaaCount > 0)
            {
               int index = 0, i=0;
               
               do
               {
                  JSONObject *obje = jaa.getObject(i);
                  
                  if (DEBUG && i==0)
                  {
                     Print("Got the array object");
                  }
                  
                  double val = obje.getDouble("Val");
                  string timeAStr = obje.getString("Time");
                  datetime timeA = StringToTime(timeAStr);
                  
                  if (timeAStr < StartTime)
                  {
                     i++;
                     continue;
                  }
                  
                  if (m_dates.contains(timeA))
                  {
                     ExtLineBuffer[m_predCount] = val;
                     m_pastPredCount++;
                     m_predCount++;
                  }
                  else if (timeA > lastTickTime)
                  {
                     ExtLineBuffer[m_predCount] = val;
                     m_futurePredCount++;
                     m_predCount++;
                  }

                  i++;
               }
               while(i < jaaCount);
            }
            
            
            Print("End iterating");            
        }
        else
        {
            JSONArray *ja = jv;
            string sm;
            ja.getObject(0).getString(1, sm);
            Print(sm);
            Print("not object");
        }
        
        delete jv;
    }
    delete parser;
    
    return 0;
}