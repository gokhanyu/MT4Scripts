//+------------------------------------------------------------------+
//|                                     cizgi_201903_iVectorDraw.mq4 |
//|                              Copyright 2019, Dune Software Corp. |
//|                                                                  |
//+------------------------------------------------------------------+


#include <mql4-http.mqh>
#include "hash.mqh"
#include "json.mqh"


#property indicator_minimum -120
#property indicator_maximum 120
#property indicator_separate_window
//#property indicator_chart_window


#property copyright "Copyright 2019, Dune Software Corp."
#property description "Prediction Result Draw"
#property link      ""
#property version   "1.00"
#property strict

//#property indicator_buffers 1       // Number of buffers
#property indicator_color1 Red      // Color of the 1st line
#property indicator_color2 Blue     // Color of the 2nd line




//USES THIS ARRAY INSTEAD OF JsonURL
string JsonUrlDefinition[9] = { 
   
};

enum JsonUrlSelection 
  {
   EURUSD_HARD = 0,
   EURUSD_HARD_AND_SOFT = 1,
   EURUSD_SOFT = 2,
   
   AUDUSD_HARD = 3,
   AUDUSD_HARD_AND_SOFT = 4,
   AUDUSD_SOFT = 5,
   
   USDTRY_HARD = 6,
   USDTRY_HARD_AND_SOFT = 7,
   USDTRY_SOFT = 8
  };
  

input JsonUrlSelection JsonUrlType = EURUSD_HARD;
extern bool LoadFromServer = false;
input bool DEBUG = false;

extern string signifier = "Vector";
extern bool invert = false;
extern int iWindowIndex = -1;
extern int iAddScore = 0;
extern int iTimeCorrection = 2; 


string m_getData;
static datetime m_lastRunTime;
datetime m_time0;
double b0[]; double b1[];


int deinit_sub()
{
   int obj_total= ObjectsTotal();
   
   for (int i= obj_total; i>=0; i--) {
      string name= ObjectName(i);
    
      if ( StringSubstr(name,0,7+StringLen(signifier)) == "[zNly] "+signifier )
         ObjectDelete(name);
   }
   
   return(0);
}


void deinit() {
   Comment("");
   deinit_sub();
   Print("deinit");
}


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
{
   SetIndexStyle(0,DRAW_LINE,0,1);
   SetIndexBuffer(0,b0);

   SetIndexStyle(1,DRAW_LINE,0,1);
   SetIndexBuffer(1,b1);
   
   if (DEBUG)
   {
      Print("iVectorDraw Init hit.");
   }
   
   IndicatorShortName(signifier);
   IndicatorDigits(Digits);

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
      iWindowIndex = WindowFind(signifier);
      
      if (iWindowIndex == -1)
      {
         iWindowIndex = 1;
      }
   }

   if (DEBUG)
   {
      Print("Prediction Plot: " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   }
   
   double diffHour = (time[0] - m_lastRunTime) / (double)60;
   
   if (diffHour >= 0.3)
   {
      string jsonURL = JsonUrlDefinition[JsonUrlType];
      
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
      
      ParseJson(time[0]);

      m_lastRunTime = time[0];    
   }
   
   return(rates_total);
}
  


int ParseJson(datetime parseTime)
{
    if (DEBUG)
    {
      Print("Trying to parse JSON..");
    }
   
    JSONParser *parser = new JSONParser();
    JSONValue *jv = parser.parse(m_getData);
    //JSONArray *ja = parser.parseArray();
    
    if (jv == NULL) 
    {
        Print("error:"+(string)parser.getErrorCode()+parser.getErrorMessage());
    } 
    else {
    
         if (DEBUG)
         {
            Print("Json parsed as string: "+jv.toString());
         }
         
         if (jv.isObject()) {
         
            if (DEBUG)
            {
               Print("String is an JSON object.");
            }
        
            JSONObject *jo = jv;
            
            int jaaCount = jo.getInt("VectorCount");
            
            if (DEBUG)
            {
               Print("Get the VectorCount");
            }
            
            JSONArray *jaa = jo.getArray("Vectors");
            
            if (jaa.isArray() && jaaCount > 0)
            {
               int index = 0, i=0;
               
               do
               {
                  JSONObject *obje = jaa.getObject(i);
                  
                  if (DEBUG)
                  {
                     Print("Get the object");
                  }
                  
                  double valA = obje.getDouble("ValueA");
                  double valB = obje.getDouble("ValueB");
                  string timeAStr = obje.getString("TimeAStr");
                  string timeBStr = obje.getString("TimeBStr");
                  datetime timeA = StringToTime(timeAStr);
                  datetime timeB = StringToTime(timeBStr);
                        
                  string desc = obje.getString("Desc");
                  string objId = "[zNly] "+signifier+i;
                  
                  if (invert)
                  {
                     valA = valA * -1;
                     valB = valB * -1;
                  }

                  ObjectCreate(objId, OBJ_TREND, iWindowIndex, timeA+iTimeCorrection*60*60, 
                                       valA+iAddScore, timeB+iTimeCorrection*60*60, valB+iAddScore); 
                  ObjectSet(objId, OBJPROP_RAY, 0);
                  
                  if (valA > valB)
                  {
                     ObjectSet(objId, OBJPROP_COLOR, clrRed); //DOWN
                  }
                  else
                  {
                     ObjectSet(objId, OBJPROP_COLOR, clrGreen);
                  }
                 
                  ObjectSet(objId, OBJPROP_STYLE, STYLE_DOT);// Style
                  ObjectSetText(objId,desc,10,"Times New Roman",Green);

                  if (DEBUG)
                  {
                     Print(timeAStr);
                  }
                     
                  i++;
               }
               while(i<jaaCount);
               
            }
            
            if (DEBUG)
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
    
    return(0);
}


