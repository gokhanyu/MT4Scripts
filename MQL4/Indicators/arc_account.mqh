//PREDICTION STARTS!


//&timePeriod=H4
string PredictionJsonUrlDefinition[] = { //timePeriod= is added parametrically
   
};

int PredictionTimeToAddList[] = {
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




enum PredictionJsonUrlSelection 
{
   ABC_TEST,
};


string PredictionAPIServerURL = "http://vps3asd.ca/API/";

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


string VectorAPIServerURL = "http://vps3asd.ca/API/";


//VECTOR ENDS