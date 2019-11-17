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
#include "../shared_connection.mqh"
#include "../shared_functions.mqh"


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




enum TimeFrames
{
   UND, MN1, MN, W1, D1, H4, H1, M30, M15, M5, M1
};

enum NormalizationTypes
{
   DontTouch,
   WeeklyMinMax,  
   MinMax,
   None,
	Gaussian,
};




//--- indicator parameters
input PredictionJsonUrlSelection JsonUrlType = CRAZYNAT_MODEL_D22INVERTED_H4_WeekMinMax;
input TimeFrames FileTimePeriod = H4;
extern bool LoadFromRemoteServer = false;
extern datetime StartTime = D'2019.01.01 00:00';
extern bool ApplyTimeAdjustment = false;
extern int AddHoursToTimeDictionary = -1;
//overrides NormalizationType parameter of the WebService 
extern NormalizationTypes CustomNormalization; 
extern int iWindowIndex = -1;
extern bool DeleteServerCache = false;
extern bool DeleteClientCache = false;
extern bool ShortenProcessedMonths = true;
extern bool DEBUG_MODE = false;
extern string IndicatorIdentifier = "Prediction";




//IF IndicatorIdentifier could not be found through windows the index of main window is 0, and 1 is below it etc.. Type the index of the window to display vectors
//Should be better to call iWindowIndex window number
//Better to enter window index to reduce conflicts if there is more than one indicator on the window


//--- indicator buffer
double ExtLineBuffer[];
string m_getData; //careful this is not static and can't be
HashMap<string,int> m_dates;

int m_pastPredCount;
int m_futurePredCount;
int m_predCount;
datetime m_lastPullTime = 0;
datetime m_lastDrawTime = 0;
datetime m_time0;
bool m_firstLoad = true;


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
   string debugStr = DEBUG_MODE ? "DEBUG " : "";
   debugStr += DeleteClientCache ? " NoCliCache " : "";
   debugStr += DeleteServerCache ? " NoServCache " : "";
   return debugStr + "MOON WALKER   " + replace;
}


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
{
   IndicatorShortName(GetIndicatorName());
   IndicatorDigits(Digits);

   //--- check for input
   //if(InpMAPeriod<2)
   //{
   //   return(INIT_FAILED);
   //}
     
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
   if( iWindowIndex == -1 )
   {
      iWindowIndex = WindowFind(GetIndicatorName());
      
      if (iWindowIndex == -1)
      {
         iWindowIndex = 1;
      }
   }

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
   
   
   long diffPullHour = ((long)TimeCurrent() - (long)m_lastPullTime);
   long diffDrawHour = ((long)TimeCurrent() - (long)m_lastDrawTime);
   
   if (DeleteClientCache || prev_calculated == 0 || m_firstLoad || m_getData == NULL || diffPullHour > 3600) //1hour
   {
      if (DEBUG_MODE)
      {
         Print("Prediction Plot Start:  " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      }
   
      string jsonURL = PredictionJsonUrlDefinition[JsonUrlType];
      jsonURL = jsonURL + "&fileTimePeriod=" + EnumToString(FileTimePeriod);
      jsonURL = jsonURL + "&displayTimePeriod=" + GetTimeFrame(Period());
      jsonURL = jsonURL + "&brokerTimeCurrent=" + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      jsonURL = jsonURL + "&brokerLastBarTime=" + TimeToStr(time[0], TIME_DATE|TIME_SECONDS);
      jsonURL = jsonURL + "&machineGMT=" + TimeToStr(TimeGMT(), TIME_DATE|TIME_SECONDS);
      jsonURL = jsonURL + "&timeGMTOffset=" + TimeGMTOffset();
      jsonURL = jsonURL + "&shorten=" + (ShortenProcessedMonths ? "true" : "false");     
      
      if (DeleteServerCache)
      {
         jsonURL = jsonURL + "&deleteCache=true";
      }
      
      StringReplace(jsonURL, " ", "_");
      
      if (LoadFromRemoteServer)
      {
         int replaced=StringReplace(jsonURL, "http://localhost/EveAPI/", PredictionAPIServerURL);
      }
      
      if (CustomNormalization != DontTouch)
      {
         string norm = "&normalizationType=" + EnumToString(CustomNormalization);
         
         int normalizationTypeIndex = StringFind(jsonURL, "&normalizationType=", 0);
         
         if (normalizationTypeIndex > -1)
         {
            int fileFullPathIndex = StringFind(jsonURL, "&fileFullPath=", normalizationTypeIndex);
            
            if (fileFullPathIndex > -1)
            {
               string replaceStr = StringSubstr(jsonURL, normalizationTypeIndex, fileFullPathIndex-normalizationTypeIndex);
               int replaced=StringReplace(jsonURL, replaceStr, norm);
            }
         }
      }
      
      Print("JsonURL ", jsonURL);
      m_getData = httpGET(jsonURL);    
        
      if (DEBUG_MODE)
      {
         Print("Data is ", m_getData);
      }
      
      DrawWithExistingData(time);
      
      m_lastPullTime = TimeCurrent();
      m_lastDrawTime = TimeCurrent();
      m_firstLoad = false;
      //Print(DoubleToStr(diffHour, 7));
   }
   else if (diffDrawHour > 600) //10minutes
   {
      //Print(DoubleToStr(diffHour, 7));
      DrawWithExistingData(time);
   }
   else
   {
      //Print(DoubleToStr(diffHour, 7));
      //wait;
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
      
      m_lastDrawTime = TimeCurrent();
}


void PrepareDateTimeDictionary(const datetime &time[])
{
   int arraySize = ArraySize(time);
   
   m_dates.clear(); 
   
   for (int i = 0; i < arraySize; i++)
   {
      if (i == 0)
      {
         Print("Before: " + TimeToStr(time[i], TIME_DATE|TIME_SECONDS));
         
         if (ApplyTimeAdjustment)
            Print("After: " + TimeToStr(time[i]+AddHoursToTimeDictionary, TIME_DATE|TIME_SECONDS));
         else
            Print("After: " + TimeToStr(time[i]+PredictionTimeToAddList[JsonUrlType]*3600, TIME_DATE|TIME_SECONDS));       
      }
            
      if (ApplyTimeAdjustment)
      {
         m_dates.set(time[i]+AddHoursToTimeDictionary, 1);
      }
      else //uses default value
      {
         m_dates.set(time[i]+PredictionTimeToAddList[JsonUrlType]*3600, 1); //hour to add 3600 is equal to 1Hour
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
         if (DEBUG_MODE)
         {
            Print("Json parsed as string: "+jv.toString());
         }
         
         if (jv.isObject()) 
         {
            if (DEBUG_MODE) Print("String is an JSON object.");
        
            JSONObject *jo = jv;
            int jaaCount = jo.getInt("ForecastCount");
            if (DEBUG_MODE) Print("Got ForecastCount");
            
            string forecastStartStr = jo.getString("ForecastStartDate");
            datetime forecastStart = StringToTime(forecastStartStr);
            ObjectCreate("VLINE"+forecastStartStr, OBJ_VLINE, iWindowIndex, forecastStart, Bid);
            
            JSONArray *jaa = jo.getArray("Forecasts");
            
            if (jaa.isArray() && jaaCount > 0)
            {
               int index = 0, i=0;
               
               do
               {
                  JSONObject *obje = jaa.getObject(i);
                  
                  if (DEBUG_MODE && i==0)
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
                  
                  //Print("contains for timeAStr: " + timeAStr);
                  
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
            
            if (DEBUG_MODE)
            {
               Print("End iterating");
            }           
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