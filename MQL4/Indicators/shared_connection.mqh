//GLOBAL VARS


//set both to true in the server
bool GLOBAL_LOAD_FROM_SERVER = false;
bool GLOBAL_OVERRIDE_LOAD_FROM_SERVER = false;





//AlgoVectorIndicatorMessaging

string AlgoVectorIndicatorAPIServerURL = "";

string AlgoVectorIndicatorAPIDebugURL = "http://localhost:38506/";

//PREDICTION STARTS!

string PredictionAPIServerURL = "";



enum PredictionJsonUrlSelection 
{
   CRAZYNAT_MODEL_XCAMP_H4,
};



//&timePeriod=H4
//CONSTRAINT: querystring order. fileFullPath should follow normalizationType=MinMax&fileFullPath=
//_GMT ile baslayan saati kullanarak adjust eder!
string PredictionJsonUrlDefinition[] = { //timePeriod= is added parametrically

};


int PredictionTimeToAddList[] = {
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



//PREDICTION ENDS!










//VECTOR STARTS

string VectorAPIServerURL = "";

string VectorIndicatorAPIDebugURL = "http://localhost:38506/";


//USES THIS ARRAY INSTEAD OF JsonURL
string VectorJsonUrlDefinition[9] = { 

};

enum VectorJsonUrlSelection 
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


//VECTOR ENDS