//+------------------------------------------------------------------+
//|                                     cizgi_201903_iVectorDraw.mq4 |
//|                              Copyright 2019, Dune Software Corp. |
//|                                                                  |
//+------------------------------------------------------------------+


#include <mql4-http.mqh>
#include "hash.mqh"
#include "json.mqh"
#include "arc_account.mqh"


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



  

input VectorJsonUrlSelection JsonUrlType = EURUSD_HARD;
extern bool LoadFromServer = false;
input bool DEBUG = false;

extern string IndicatorIdentifier = "VECTOR";
extern bool InvertChart = false;
extern int iWindowIndex = -1; 
extern int iAddScore = 0;
extern int iTimeCorrection = 2; 


//IF Signifier could not be found through windows the index of main window is 0, and 1 is below it etc.. Type the index of the window to display vectors
//Should be better to call iWindowIndex window number
//Better to enter window index to reduce conflicts if there is more than one indicator on the window


string m_getData;
static datetime m_lastRunTime;
datetime m_time0;
double b0[]; double b1[];


int deinit_sub()
{
   int obj_total= ObjectsTotal();
   
   for (int i= obj_total; i>=0; i--) {
      string name= ObjectName(i);
    
      if ( StringSubstr(name,0,7+StringLen(IndicatorIdentifier)) == "[zNly] "+IndicatorIdentifier )
         ObjectDelete(name);
   }
   
   return(0);
}


void deinit() {
   Comment("");
   deinit_sub();
   Print("deinit");
}

string GetIndicatorName()
{
   string replace = EnumToString(JsonUrlType);
   return IndicatorIdentifier + "   " + replace;
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
   
   IndicatorShortName(GetIndicatorName());
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
      iWindowIndex = WindowFind(GetIndicatorName());
      
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
   
   if (prev_calculated == 0 || diffHour >= 0.3)
   {
      string jsonURL = VectorJsonUrlDefinition[JsonUrlType];
      
      if (LoadFromServer)
      {
         int replaced=StringReplace(jsonURL, "http://localhost/EveAPI/", VectorAPIServerURL);
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
                  string objId = "[zNly] "+IndicatorIdentifier+i;
                  
                  if (InvertChart)
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

