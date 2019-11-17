
enum IndicatorDefinition
{
   PAMA = 10,
};


//ALL URLS SHOULD START WITH PREFIX
const string LOCALHOST_URL_PREFIX = "http://localhost/EveAPI/";


string getServerURL(string localUrl, string serverUrl, string debugUrl, bool loadFromServer, bool isDebug)
{
   if (isDebug)
   {
      int replaced=StringReplace(localUrl, LOCALHOST_URL_PREFIX, debugUrl);
      return localUrl;
   }
   if (loadFromServer)
   {
      int replaced2=StringReplace(localUrl, LOCALHOST_URL_PREFIX, serverUrl);
      return localUrl;
   }
   else
   {
      return localUrl;
   }
};