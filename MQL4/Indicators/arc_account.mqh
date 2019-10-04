//PREDICTION STARTS!


//&timePeriod=H4
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
};




enum PredictionJsonUrlSelection 
{
   
};


string PredictionAPIServerURL = "http://vpsasdasdasd";

//PREDICTION ENDS!










//VECTOR STARTS


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


string VectorAPIServerURL = "http://vpsasdasdasd";


//VECTOR ENDS