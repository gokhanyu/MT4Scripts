// $Id: hash.mqh 125 2014-03-03 08:38:32Z ydrol $
#ifndef YDROL_HASH_MQH
#define YDROL_HASH_MQH

//#property strict

/*
   This is losely ported from a C version I have which was in turn modified from hashtable.c by Christopher Clark.
 Copyright (C) 2014, Andrew Lord (NICKNAME=lordy) <forex@NICKNAME.org.uk> 
 Copyright (C) 2002, 2004 Christopher Clark <firstname.lastname@cl.cam.ac.uk> 

 2014/02/21 - Readded PrimeNumber sizes and auto rehashing when load factor hit.
*/

      

/// Any value stored in a Hash must be a subclass of HashValue
class HashValue {
};

/// Linked list of values - there will be one list for each hash value
class HashEntry {
    public:
        string _key;
        HashValue * _val;
        HashEntry *_next;

        HashEntry() {
            _key=NULL;
            _val=NULL;
            _next=NULL;
        }

        HashEntry(string key,HashValue* val) {
            _key=key;
            _val=val;
            _next=NULL;
        }

        ~HashEntry() {
        }
};

/// Convenience class for storing strings as hash values.
class HashString : public HashValue {
    private:
        string val;
    public:
        HashString(string v) { val=v;}
        string getVal() { return val; }
};

/// Convenience class for storing doubles as hash values.
class HashDouble : public HashValue {
    private:
        double val;
    public:
        HashDouble(double v) { val=v;}
        double getVal() { return val; }
};

/// Convenience class for storing ints as hash values.
class HashInt : public HashValue {
    private:
        int val;
    public:
        HashInt(int v) { val=v;}
        int getVal() { return val; }
};

/// Convenience class for storing longs as hash values.
class HashLong : public HashValue {
    private:
        long val;
    public:
        HashLong(datetime v) { val=v;}
        long getVal() { return val; }

};

/// Convenience class for storing datetimes as hash values.
class HashDatetime : public HashValue {
    private:
        datetime val;
    public:
        HashDatetime(datetime v) { val=v;}
        datetime getVal() { return val; }
};

///
/// Hash class allows objects to be stored in a table index by strings.
/// the stored Objects must be a sub class of the HashValue class.
///
/// There are some convenience classes to hold atomic types as values HashString,HashDouble,HashInt
///
///EXAMPLE:
///
/// <pre>
/// class myClass: public HashValue {
///   public: int v;
///   myClass(int a) { v = a;}
/// };
///
/// // Create the objects as needed
///
///      myClass *a = new myClass(1);
///      myClass *b = new myClass(2);
///      myClass *c = new myClass(3);
///
/// // Then to insert into hash etc.
///
///      Hash* h = new Hash(193,true); 
///      // 'true' means when the hash will adopt the values and delete them when they are removed from the hash or when the hash is deleted.
///
///      h.hPut("a",a);
///      h.hPut("b",b);
///      h.hPut("c",c);
///
///      myClass *d = h.hGet("b");
///
///      etc.
///
/// // Iterate over hash
///    HashLoop *l
///    for (l = new HashLoop(h) ; l.hasNext() ; l.next()  ) {
///        string key = l.key();
///        MyClass *c = l.val();
///    }
///    delete l;
///
///    // Delete from hash - This will also delete 'a' because we set the 'adopt' flag on the hash.
///    h.hDel("a");
///
///    //Delete the hash - this will also delete 'b' and 'c' because of the adopt flag.
///    delete h;
/// </pre> 
class Hash2 : public HashValue {

private:
    /// Number of slots in the hashtable. 
    /// this should be approx number of elements to store. Depending on hash algorithm
    /// it may optimally be a prime or a power of two etc. but probably not important
    /// for MQL4 performance. A future optimisation might be to move the hashcode function to a DLL??
    uint _hashSlots; 

    /// Number of elements at which hash will get resized.
    int _resizeThreshold;

    /// number of things in the hash
    int _hashEntryCount;

    /// an array of linked lists (HashEntry). one for each hash value.
    /// To store an object against a string(key) - get the string hashcode, then insert pair (key,val) into the linked list for that hashcode.
    /// To fetch an object against a string(key) - get the string hashcode, get linked-list at that hashcode index, then search for the key and return the val.
    HashEntry* _buckets[];

    /// If true the hash will free(delete) values as they are removed, or at cleanup.
    bool _adoptValues;

    int _errCode;
    string _errText;

    void init(uint size,bool adoptValues)
    {
        _hashSlots = 0;
        _hashEntryCount = 0;
        clearError();
        setAdoptValues(adoptValues);

        rehash(size);
    }

    // Hash table distribution is better when size is prime, eg if hash function procduces numbers
    // that are multiples of x, then there may be grouping occuring around gcd(x,slots) gcd(2x,slots) etc
    // using a prime size helps spread the distribution.
    uint size2prime(uint size) {
        int pmax=ArraySize(_primes);
        for(int p=0 ; p<pmax; p++ ) {
            if (_primes[p] >= size) {
               return _primes[p];
            }
        }
        return size; 
    }

    /// Primes that approx double in size, used for hash table sizes to avoid gcd causing bunching
    static uint _primes[];

    /// After reviewing quite a few hash functions I settled on the one below.
    /// http://www.cse.yorku.ca/~oz/hash.html
    /// this is the bottleneck function. Shame mql hash no default hash method for objects.
    uint hash(string s)
    {

        uchar c[];
        uint h = 0;

        if (s != NULL) {
            h = 5381;
            int n = StringToCharArray(s,c);
            for(int i = 0 ; i < n ; i++ ) {
                h = ((h << 5 ) + h ) + c[i];
            }
        }
        return h % _hashSlots;
    }
    void clearError() {
        setError(0,"");
    }
    void setError(int e,string m) {
        _errCode = e;
        _errText = m;
        //error((string)e,m);
    }

public:

    /// Constructor: Create a Hash Object
    Hash2() {
        init(17,true);
    }


    /// Constructor: Create a Hash Object
    /// @param adoptValues : If true the hash destructor will <b>delete</b> all dynamically allocated hash values.
    Hash2(bool adoptValues) {
        init(17,adoptValues);
    }

    /// Constructor: Create a Hash Object
    /// @param size : Approximate size (actual size will be a larger prime number close to a power of 2)
    /// @param adoptValues : If true the hash destructor will <b>delete</b> all dynamically allocated hash values.
    Hash2(int size,bool adoptValues) {
        init(size,adoptValues);
    }

    ~Hash2() {

        // Free entries.
        for(uint i = 0 ; i< _hashSlots ; i++) {
            HashEntry *nextEntry = NULL;
            for(HashEntry *entry = _buckets[i] ; entry!= NULL ; entry = nextEntry ) 
            {
                nextEntry = entry._next;

                if (_adoptValues && entry._val != NULL && CheckPointer(entry._val) == POINTER_DYNAMIC ) {
                    delete entry._val;
                }
                delete entry;
            }
            _buckets[i] = NULL;
        }
    }

    /// Return any error that has occured. This should be used when
    /// retriving values in a Hash that may contain NULLs. hGet()
    /// methods can return NULL if not found, in which case getErrorCode
    /// will be set.
    int getErrCode() {
        return _errCode;
    }
    /// Return text of the error message.
    string getErrText() {
        return _errText;
    }

    /// If true the hash destructor will <b>delete</b> all dynamically allocated hash values.
    void setAdoptValues(bool v) {
        _adoptValues = v;
    }

    /// True if the hash destructor will <b>delete</b> all dynamically allocated hash values.
    bool getAdoptValues() {
        return _adoptValues;
    }

    private:
    uint _foundIndex;       // After find() is called is set to hashindex for name whether found or not.
    HashEntry* _foundEntry; // After find() is called  is set to the HashEntry that contains the key.
    HashEntry* _foundPrev;  // After find() is called  is set to the HashEntry before the entry
                            // (could use double linked list but requires more memory).

    /// Look for the required entry for key 'name' true if found.
    bool find(string keyName) {
    
         //Alert("finding");
        bool found = false;

        // Get the index using the hashcode of the string
        _foundIndex = hash(keyName);
        

        if (_foundIndex>_hashSlots ) {

            setError(1,"hGet: bad hashIndex="+(string)_foundIndex+" size "+(string)_hashSlots);

        } else {

            // Search the linked list determined by the index.
            
            for(HashEntry *e = _buckets[_foundIndex] ; e != NULL ; e = e._next )  {
                if (e._key == keyName) {
                    _foundEntry = e;
                    found=true;
                    break;
                }
                // Track the item before the target item in case deleting from single linked list.
                _foundPrev = e;
            }
        }

        return found;
    }

    public:

    /// This is used by the HashLoop class to get start of LinkedList at bucket[i]
    HashEntry*getEntry(int i) {
        return _buckets[i];
    }

    /// Return the number of slots/buckets (not number of elements)
    uint getSlots() {
        return _hashSlots;
    }
    /// Return the number of elements in the Hash
    int getCount() {
        return _hashEntryCount;
    }

    /// Change the hash size and re-allocate values to new buckets.
    bool rehash(uint newSize) {
        bool ret = false;
        HashEntry* oldTable[];

        uint oldSize = _hashSlots;
        newSize  = size2prime(newSize);
        //info("rehashing from "+(string)_hashSlots+" to "+(string)newSize+" "+(string)GetTickCount());

        if (newSize <= getSlots()) {
            setError(2,"rehash "+(string)newSize+" <= "+(string)_hashSlots);
        } else if (ArrayResize(_buckets,newSize) != newSize) {
            setError(3,"unable to resize ");
        } else if (ArrayResize(oldTable,oldSize) != oldSize) {
            setError(4,"unable to resize old copy ");
        } else {
            //Copy old table.
            for(uint i = 0 ; i < oldSize ; i++ ) oldTable[i] = _buckets[i];
            // Init new entries - not sure if MQL does this anyway
            for(uint i2 = 0 ; i2<newSize ; i2++ ) _buckets[i2] = NULL;

            // Move entries to new slots
            _hashSlots = newSize;
            _resizeThreshold = (int)_hashSlots / 4 * 3; // Just use the default load factor value of Javas HashTable

            // Look through all slots
            for(uint oldHashCode = 0 ; oldHashCode<oldSize ; oldHashCode++ ) {
                HashEntry *next = NULL;

                // Walk linked list
                for(HashEntry *e = oldTable[oldHashCode] ; e != NULL ; e = next )  {

                    next = e._next;

                    uint newHashCode = hash(e._key);
                    // Insert at head of new list.
                    e._next = _buckets[newHashCode];
                    _buckets[newHashCode] = e;
                }

                oldTable[oldHashCode] = NULL;
            }
            ret = true;
        }
        return ret;
    }

    /// Check if the hash contains the given key
    /// @param keyName : The key
    /// @return: true if found otherwise false
    bool hContainsKey(string keyName) {
        return find(keyName);
    }

    /// Fetch a value using string key
    ///  @return :HashValue associated with the key (or NULL if none found)
    ///  If the Hashtable contains legitimate NULL values then also check errCode()
    ///  Examples:
    ///   If not storing nulls use
    ///    obj = hash.hGet(x); if (obj != NULL) OK
    ///
    ///  If storing nulls use
    ///     obj = hash.hGet(x); if (obj != NULL || hash.errCode() == 0 ) OK
    HashValue* hGet(string keyName) {

        HashValue *obj = NULL;
        clearError();
        bool found=false;

        if (find(keyName)) {
            obj = _foundEntry._val;
        } else {
            //If Hash contains nulls then also check the errorCode=0 when retrieving
            if (!found) {
                setError(1,"not found");
            }
        }
        return obj;
    }

    /// Convenience method for getting values from a HashString value (see hPutString())
    string hGetString(string keyName) {
        string ret = NULL;
        HashString *v = hGet(keyName);
        if (v != NULL) {
            ret = v.getVal();
        }
        return ret;
    }
    /// Convenience method for getting values from a HashDouble value (see hPutDouble())
    double hGetDouble(string keyName) {
        double ret = NULL;
        HashDouble *v = hGet(keyName);
        if (v != NULL) {
            ret = v.getVal();
        }
        return ret;
    }
    /// Convenience method for getting values from a HashInt value (see hPutInt())
    int hGetInt(string keyName) {
        int ret = NULL;
        HashInt *v = hGet(keyName);
        if (v != NULL) {
            ret = v.getVal();
        }
        return ret;
    }
    /// Convenience method for getting  values from a HashLong ( see hPutLong())
    long hGetLong(string keyName) {
        long ret = NULL;
        HashLong *v = hGet(keyName);
        if (v != NULL) {
            ret = v.getVal();
        }
        return ret;
    }
    /// Convenience method for getting  values from a HashDatetime ( see hPutDatetime())
    datetime hGetDatetime(string keyName) {
        datetime ret = NULL;
        HashDatetime *v = hGet(keyName);
        if (v != NULL) {
            ret = v.getVal();
        }
        return ret;
    }

    /// Store a hash value against the <b>keyName</b> key. This will overwrite any existing
    /// value. It adoptValues is set, it will also free the value if applicable.
    /// @param keyName : key name
    /// @param obj : Value to store
    /// @return the previous value of the key or NULL if there wasnt one 
    HashValue *hPut(string keyName,HashValue *obj) {
    
        HashValue *ret = NULL;
        clearError();
         
        if (find(keyName)) {
            // Return revious value
            ret = _foundEntry._val;
            /*
            // Replace entry contents
            if (_adoptValues && _foundEntry._val != NULL && CheckPointer(_foundEntry._val) == POINTER_DYNAMIC ) {
                delete _foundEntry._val;
            }
            */
            _foundEntry._val = obj;

        } else {
            // Insert new entry at head of list
            HashEntry* e = new HashEntry(keyName,obj);
            HashEntry* first = _buckets[_foundIndex];
            e._next = first;
            _buckets[_foundIndex] = e;
            _hashEntryCount++;

            //info((string)_hashEntryCount+" vs. "+(string)_resizeThreshold);
            // Auto Resize if number of entries hits _resizeThreshold
            if (_hashEntryCount > _resizeThreshold ) {
                rehash(_hashSlots/2*3); // this will snap to the next prime
            }
        }
        return ret;
    }
    /// Store a string as hash value (HashString)
    /// @return the previous value of the key or NULL if there wasnt one 
    HashValue* hPutString(string keyName,string s) {
        HashString *v = new HashString(s);
        return hPut(keyName,v);
    }
    /// Store a double as hash value (HashDouble)
    /// @return the previous value of the key or NULL if there wasnt one 
    HashValue* hPutDouble(string keyName,double d) {
        HashDouble *v = new HashDouble(d);
        return hPut(keyName,v);
    }
    /// Store an int as hash value (HashInt)
    /// @return the previous value of the key or NULL if there wasnt one 
    HashValue* hPutInt(string keyName,int i) {
        HashInt *v = new HashInt(i);
        return hPut(keyName,v);
    }

    /// Store a datetime as hash value (HashLong)
    /// @return the previous value of the key or NULL if there wasnt one 
    HashValue* hPutLong(string keyName,long i) {
        HashLong *v = new HashLong(i);
        return hPut(keyName,v);
    }

    /// Store a datetime as hash value (HashDatetime)
    /// @return the previous value of the key or NULL if there wasnt one 
    HashValue* hPutDatetime(string keyName,datetime i) {
        HashDatetime *v = new HashDatetime(i);
        return hPut(keyName,v);
    }

    /// Delete an entry from the hash.
    bool hDel(string keyName) {

        bool found = false;
        clearError();

        if (find(keyName)) {
            HashEntry *next = _foundEntry._next;
            if (_foundPrev != NULL) {
                //Remove entry from the middle of the list.
                _foundPrev._next = next;
            } else {
                // remove from head of list
                _buckets[_foundIndex] = next;
            }

            if (_adoptValues && _foundEntry._val != NULL&& CheckPointer(_foundEntry._val) == POINTER_DYNAMIC) {
                delete _foundEntry._val;
            }
            delete _foundEntry;
            _hashEntryCount--;
            found=true;

        }
        return found;
    }
};
uint Hash2::_primes[] = {
    17, 53, 97, 193, 389,
    769, 1543, 3079, 6151,
    12289, 24593, 49157, 98317,
    196613, 393241, 786433, 1572869,
    3145739, 6291469, 12582917, 25165843,
    50331653, 100663319, 201326611, 402653189,
    805306457, 1610612741};

/// Class to iterate over a Hash using ...
/// <pre>
///   HashLoop *l
///   for (l = new HashLoop(h) ; l.hasNext() ; l.next()  ) {
///       string key = l.key();
///       MyClass *c = l.val();
///   }
///   delete l;
/// </pre>
class HashLoop {
    private:
        uint _index;
        HashEntry *_currentEntry;
        Hash2 *_hash;

    public:
        /// Create iterator for a hash - move to first item
        HashLoop(Hash2 *h) {
            setHash(h);
        }
        ~HashLoop() {};

        /// Clear current state and move to first item (if any).
        void reset() {
            _index=0;
            _currentEntry = _hash.getEntry(_index);

            // Move to first item
            if (_currentEntry == NULL) {
                next();
            }
        }

        /// Change the hash over which to iterate.
        void setHash(Hash2 *h) {
            _hash = h;
            reset();
        }

        /// Check if more items.
        bool hasNext() {
            bool ret = ( _currentEntry != NULL);
            //config("hasNext=",ret);
            return ret;
        }

        /// Move to next item.
        void next() {

            //config("next : index = ",_index);

            // Advance
            if (_currentEntry != NULL) {
                _currentEntry = _currentEntry._next;
            }

            // Keep advancing if _currentEntry is null
            while (_currentEntry==NULL) {
                _index++;
                if (_index >= _hash.getSlots() ) return ;
                _currentEntry = _hash.getEntry(_index);
            }
        }

        /// Return the key name of the current item.
        string key() {
            if (_currentEntry != NULL) {
                return _currentEntry._key;
            } else {
                return NULL;
            }
        }

        /// Return the value.
        HashValue *val() {
            if (_currentEntry != NULL) {
                return _currentEntry._val;
            } else {
                return NULL;
            }
        }

        /// Convenience functions for retriving int from a current HashInt entry
        int valInt() {
            return ((HashInt *)val()).getVal();
        }

        /// Convenience functions for retriving int from a current HashString entry
        string valString() {
            return ((HashString *)val()).getVal();
        }

        /// Convenience functions for retriving int from a current HashDouble entry
        double valDouble() {
            return ((HashDouble *)val()).getVal();
        }

        /// Convenience functions for retriving int from a current HashLong entry
        long valLong() {
            return ((HashLong *)val()).getVal();
        }
        /// Convenience functions for retriving int from a current HashDatetime entry
        datetime valDatetime() {
            return ((HashDatetime *)val()).getVal();
        }
};


#endif


// $Id: json.mqh 4 2015-06-24 13:11:09Z ydrol $
#ifndef YDROL_JSON_MQH
#define YDROL_JSON_MQH

// (C)2014 Andrew Lord forex@NICKNAME@lordy.org.uk
// Parse a JSON String - Adapted for mql4++ from my gawk implementation
// ( https://code.google.com/p/oversight/source/browse/trunk/bin/catalog/json.awk )

/*
   TODO the constants true|false|null could be represented as fixed objects.
      To do this the deleting of _hash and _array must skip these objects.

   TODO test null

   TODO Parse Unicode Escape
*/


/*
   See json_demo for examples.

 This requires the hash.mqh ( http://codebase.mql4.com/9238 , http://lordy.co.nf/hash )



 */

/// Different types of JSON Values
enum ENUM_JSON_TYPE { JSON_NULL, JSON_OBJECT , JSON_ARRAY, JSON_NUMBER, JSON_STRING , JSON_BOOL };

class JSONString ;

///
/// Generic class for all JSON types (Number, String, Bool, Array, Object )
/// It is a subclass of HashValue so it can be stored in an JSONObject hash
///
class JSONValue : public HashValue {
    private:
    ENUM_JSON_TYPE _type;

    public:
        JSONValue() {}
        ~JSONValue() {}
        ENUM_JSON_TYPE getType() { return _type; }
        void setType(ENUM_JSON_TYPE t) { _type = t; }

        /// True if JSONValue is a instance of JSONString
        bool isString() { return _type == JSON_STRING; }

        /// True if JSONValue is a instance of JSONNull 
        bool isNull() { return _type == JSON_NULL; }

        /// True if JSONValue is a instance of JSONObject
        bool isObject() { return _type == JSON_OBJECT; }

        /// True if JSONValue is a instance of JSONArray
        bool isArray() { return _type == JSON_ARRAY; }

        /// True if JSONValue is a instance of JSONNumber
        bool isNumber() { return _type == JSON_NUMBER; }

        /// True if JSONValue is a instance of JSONBool
        bool isBool() { return _type == JSON_BOOL; }

        // Override in child classes
        virtual string toString() {
            return "";
        }

        // Some convenience getters to cast to the subtype. - this is bad OO design!

        /// If this JSONValue is an instance of JSONString return the string (or cast will fail)
        string getString() { return ((JSONString *)GetPointer(this)).getString(); }

        /// If this JSONValue is an instance of JSONNumber return the double (or cast will fail)
        double getDouble() { return ((JSONNumber *)GetPointer(this)).getDouble(); }

        /// If this JSONValue is an instance of JSONNumber return the long (or cast will fail)
        long getLong() { return ((JSONNumber *)GetPointer(this)).getLong(); }

        /// If this JSONValue is an instance of JSONNumber return the int (or cast will fail)
        int getInt() { return ((JSONNumber *)GetPointer(this)).getInt(); }

        /// If this JSONValue is an instance of JSONBool return the bool (or cast will fail)
        bool getBool() { return ((JSONBool *)GetPointer(this)).getBool(); }


        /// Get the string value of the JSONValue, without Program termination
        /// @param val : String object from which value will be extracted.
        /// @param out : The string than was extracted.
        /// @return true if OK else false
        static bool getString(JSONValue *val,string &out)
        {
            if (val != NULL && val.isString()) {
                out = val.getString();
                return true;
            }
            return false;
        }
        /// Get the bool value of the JSONValue, without Program termination
        /// @param val : String object from which value will be extracted.
        /// @param out : The bool than was extracted.
        /// @return true if OK else false
        static bool getBool(JSONValue *val,bool &out)
        {
            if (val != NULL && val.isBool()) {
                out = val.getBool();
                return true;
            }
            return false;
        }
        /// Get the double value of the JSONValue, without Program termination
        /// @param val : String object from which value will be extracted.
        /// @param out : The double than was extracted.
        /// @return true if OK else false
        static bool getDouble(JSONValue *val,double &out)
        {
            if (val != NULL && val.isNumber()) {
                out = val.getDouble();
                return true;
            }
            return false;
        }
        /// Get the long value of the JSONValue, without Program termination
        /// @param val : String object from which value will be extracted.
        /// @param out : The long than was extracted.
        /// @return true if OK else false
        static bool getLong(JSONValue *val,long &out)
        {
            if (val != NULL && val.isNumber()) {
                out = val.getLong();
                return true;
            }
            return false;
        }
        /// Get the int value of the JSONValue, without Program termination
        /// @param val : String object from which value will be extracted.
        /// @param out : The int than was extracted.
        /// @return true if OK else false
        static bool getInt(JSONValue *val,int &out)
        {
            if (val != NULL && val.isNumber()) {
                out = val.getInt();
                return true;
            }
            return false;
        }
};

// -----------------------------------------

/// Class to represent a JSON String 
class JSONString : public JSONValue {
    private:
        string _string;
    public:
        JSONString(string s) {
            setString(s);
            setType(JSON_STRING);
        }
        JSONString() {
            setType(JSON_STRING);
        }
        string getString() { return _string; }
        void setString(string v) { _string = v; }
        string toString() { return StringConcatenate("\"",_string,"\""); }
};


// -----------------------------------------

/// Class to represent a JSON Bool 
class JSONBool : public JSONValue {
    private:
        bool _bool;
    public:
        JSONBool(bool b) {
            setBool(b);
            setType(JSON_BOOL);
        }
        JSONBool() {
            setType(JSON_BOOL);
        }
        bool getBool() { return _bool; }
        void setBool(bool v) { _bool = v; }
        string toString() { return (string)_bool; }

};

// -----------------------------------------

/// A JSON number may be internall replresented as either an MQL4 double or a long depending on how it was parsed. 
/// If one type is set the other is zeroed.
class JSONNumber : public JSONValue {
    private:
        long _long;
        double _dbl;
    public:
        JSONNumber(long l) {
            _long = l;
            _dbl = 0;
        }
        JSONNumber(double d) {
            _long = 0;
            _dbl = d;
        }
        /// Get the long value, (cast) from internal double if necessary.
        long getLong() {
            if (_dbl != 0) {
                return (long)_dbl;
            } else {
                return _long;
            }
        }
        /// Get the int value, (cast) from internal value.
        int getInt() {
            if (_dbl != 0) {
                return (int)_dbl;
            } else {
                return (int)_long;
            }
        }
        /// Get the double value, (cast) from internal long if necessary.
        double getDouble() 
        {
            if (_long != 0) {
                return (double)_long;
            } else {
                return _dbl;
            }
        }
        string toString() {
            // Favour the long
            if (_long != 0) {
                return (string)_long;
            } else {
                return (string)_dbl;
            }
        }
};
// -----------------------------------------


/// This class should not be necessary, but null is genrally infrequent so
/// I havent bothered to code it away yet.
class JSONNull : public JSONValue {
    public:
    JSONNull()
    {
        setType(JSON_NULL);
    }
    ~JSONNull() {}
    string toString() 
    {
        return "null";
    }
};

//forward declaration
class JSONArray ;

/// This represents a JSONObject which is represented internally as a Hash
class JSONObject : public JSONValue {
    private:
    Hash2 *_hash;
    public:
        JSONObject() {
            setType(JSON_OBJECT);
        }
        ~JSONObject() {
            if (_hash != NULL) delete _hash;
        }
        /// Lookup key and get associated string value - halt program if wrong type(cast error) or doesnt exist(null pointer)
        string getString(string key) 
        {
            return getValue(key).getString();
        }
        /// Lookup key and get associated bool value - halt program if wrong type(cast error) or doesnt exist(null pointer)
        bool getBool(string key) 
        {
            return getValue(key).getBool();
        }
        /// Lookup key and get associated double value - halt program if wrong type(cast error) or doesnt exist(null pointer)
        double getDouble(string key) 
        {
            return getValue(key).getDouble();
        }
        /// Lookup key and get associated long value - halt program if wrong type(cast error) or doesnt exist(null pointer)
        long getLong(string key) 
        {
            return getValue(key).getLong();
        }
        /// Lookup key and get associated int value - halt program if wrong type(cast error) or doesnt exist(null pointer)
        int getInt(string key) 
        {
            return getValue(key).getInt();
        }

        /// Lookup key and get associated string value, return false if failure.
        bool getString(string key,string &out)
        {
            return getString(getValue(key),out);
        }
        /// Lookup key and get associated bool value, return false if failure.
        bool getBool(string key,bool &out)
        {
            return getBool(getValue(key),out);
        }
        /// Lookup key and get associated double value, return false if failure.
        bool getDouble(string key,double &out)
        {
            return getDouble(getValue(key),out);
        }
        /// Lookup key and get associated long value, return false if failure.
        bool getLong(string key,long &out)
        {
            return getLong(getValue(key),out);
        }
        /// Lookup key and get associated int value, return false if failure.
        bool getInt(string key,int &out)
        {
            return getInt(getValue(key),out);
        }

        /// Lookup key and get associated array, NULL if not present. Cast failure if not an Array.
        JSONArray *getArray(string key) 
        {
            return getValue(key);
        }
        /// Lookup key and get associated Object, NULL if not present. Cast failure if not an Object.
        JSONObject *getObject(string key) 
        {
            return getValue(key);
        }
        /// Lookup key and get associated value - best for data whose structure might change as any type can safely be returned.
        JSONValue *getValue(string key) 
        {
            if (_hash == NULL) {
                return NULL;
            }
            return (JSONValue*)_hash.hGet(key);
        }

        /// Store the value against the specified key string - Used by the parser.
        void put(string key,JSONValue *v)
        {
            if (_hash == NULL) _hash = new Hash2();
            _hash.hPut(key,v);
        }
        string toString() {
           string s = "{";
           if (_hash != NULL) {
               HashLoop *l;
               int n=0;
               
               for(l = new HashLoop(_hash) ; l.hasNext() ; l.next() ) {
                   JSONValue *v = (JSONValue *)(l.val());
                   s = StringConcatenate(s,(++n==1?"":","),
                           "\"",l.key(),"\" : ",v.toString());
               }
               delete l;
           }
           s = s + "}";
           return s; 
        }

        /// Return the internal Hash - Used by JSONIterator
        Hash2 *getHash() {
            return _hash;
        }
};

/// This is a JSONArray which is represented internally as a MQL4 dynamic array of JSONValue * 
class JSONArray : public JSONValue {
    private:
        int _size;
        JSONValue *_array[];
    public:
        JSONArray() {
            setType(JSON_ARRAY);
        }
        ~JSONArray() {
            // clean up array
            for(int i = ArrayRange(_array,0)-1 ; i >= 0 ; i-- ) {
                if (CheckPointer(_array[i]) == POINTER_DYNAMIC ) delete _array[i];
            }
        }
        // Getters for Objects (key lookup ) --------------------------------------
        
        /// Lookup string value by array index - halt program if wrong type(cast error) or doesnt exist(null pointer)
        string getString(int index) 
        {
            return getValue(index).getString();
        }
        /// Lookup bool value by array index - halt program if wrong type(cast error) or doesnt exist(null pointer)
        bool getBool(int index) 
        {
            return getValue(index).getBool();
        }
        /// Lookup double value by array index - halt program if wrong type(cast error) or doesnt exist(null pointer)
        double getDouble(int index) 
        {
            return getValue(index).getDouble();
        }
        /// Lookup long value by array index - halt program if wrong type(cast error) or doesnt exist(null pointer)
        long getLong(int index) 
        {
            return getValue(index).getLong();
        }
        /// Lookup int value by array index - halt program if wrong type(cast error) or doesnt exist(null pointer)
        int getInt(int index) 
        {
            return getValue(index).getInt();
        }

        /// Lookup JSONString by array index. NULL if not present. Cast failure if not an Object.
        bool getString(int index,string &out)
        {
            return getString(getValue(index),out);
        }
        /// Lookup JSONBool by array index. NULL if not present. Cast failure if not an Object.
        bool getBool(int index,bool &out)
        {
            return getBool(getValue(index),out);
        }
        /// Lookup JSONNumber by array index. NULL if not present. Cast failure if not an Object.
        bool getDouble(int index,double &out)
        {
            return getDouble(getValue(index),out);
        }
        /// Lookup JSONNumber by array index. NULL if not present. Cast failure if not an Object.
        bool getLong(int index,long &out)
        {
            return getLong(getValue(index),out);
        }
        /// Lookup JSONNumber by array index. NULL if not present. Cast failure if not an Object.
        bool getInt(int index,int &out)
        {
            return getInt(getValue(index),out);
        }


        /// Lookup array child by index, NULL if not present. Cast failure if not an Array.
        JSONArray *getArray(int index) 
        {
            return getValue(index);
        }
        
        /// Lookup object child by index, NULL if not present. Cast failure if not an Array.
        JSONObject *getObject(int index) 
        {
            return getValue(index);
        }
        /// The following method allows any type to be returned. Use this when parsing unpredictable data
        JSONValue *getValue(int index) 
        {
            return _array[index];
        }

        /// Used by the Parser when building the array
        bool put(int index,JSONValue *v)
        {
            if (index >= _size) {
                int oldSize = _size;
                int newSize = ArrayResize(_array,index+1,30);
                if (newSize <= index) return false;
                _size = newSize;

                // initialise
                for(int i = oldSize ; i< newSize ; i++ ) _array[i] = NULL;
            }
            // Delete old entry if any
            if (_array[index] != NULL) delete _array[index];

            //set new entry
            _array[index] = v;

            return true;
        }

        string toString() {
           string s = "[";
           if (_size > 0) {
               s = StringConcatenate(s,_array[0].toString());
               for(int i = 1 ; i< _size ; i++ ) {
                  s = StringConcatenate(s,",",_array[i].toString());
               }
           }
           s = s + "]";
           return s; 
        }

        int size() {
            return _size;
        }
};



/// Parse JSON text using a simple recursive descent parser
/// Exmaple
/// 
/// <pre>
///    string s = "{ \"firstName\": \"John\","+
///       " \"lastName\": \"Smith\","+
///       " \"age\": 25,"+
///       " \"address\": { \"streetAddress\": \"21 2nd Street\", \"city\": \"New York\", \"state\": \"NY\", \"postalCode\": \"10021\" },"+
///       " \"phoneNumber\": [ { \"type\": \"home\", \"number\": \"212 555-1234\" }, { \"type\": \"fax\", \"number\": \"646 555-4567\" } ],"+
///       " \"gender\":{ \"type\":\"male\" }  }";
///
///    JSONParser *parser = new JSONParser();
///
///    JSONValue *jv = parser.parse(s);
///
///    if (jv == NULL) {
///
///        Print("error:"+(string)parser.getErrorCode()+parser.getErrorMessage());
///
///    } else {
///
///        Print("PARSED:"+jv.toString());
///
///        if (jv.isObject()) {
///
///            JSONObject *jo = jv;
///
///            // Direct access - will throw null pointer if wrong getter used.
///
///            Print("firstName:" + jo.getString("firstName"));
///            Print("city:" + jo.getObject("address").getString("city"));
///            Print("phone:" + jo.getArray("phoneNumber").getObject(0).getString("number"));
///
///            // Safe access in case JSON data is missing or different.
///
///            if (jo.getString("firstName",s) ) Print("firstName = "+s);
///
///            // Loop over object returning JSONValue
///
///            JSONIterator *it = new JSONIterator(jo);
///            for( ; it.hasNext() ; it.next()) {
///                Print("loop:"+it.key()+" = "+it.val().toString());
///            }
///            delete it;
///        }
///        delete jv;
///    }
///    delete parser;
/// </pre>

class JSONParser {
    private:
        /// Current parse position
        int _pos;
        /// The input string is expanded into an array of ushort (wchar)
        ushort _in[];
        /// Length of string
        int _len;
        /// The original input string
        string _instr;

        int _errCode;
        string _errMsg;

        void setError(int code=1,string msg="unknown error") {
            _errCode |= code;
            if (_errMsg == "") {
                _errMsg = "JSONParser::Error "+msg;
            } else {
                _errMsg = StringConcatenate(_errMsg,"\n",msg);
            }
        }
        
        /// Parse a JSON Object
        JSONObject *parseObject() 
        {
            JSONObject *o = new JSONObject();
            skipSpace();
            if (expect('{')) {
                    while (_errCode == 0) {
                        skipSpace();
                        if (_in[_pos] != '"') break;

                        // Read the key
                        string key = parseString();

                        if (_errCode != 0 || key == NULL) break;

                        skipSpace();

                        if (!expect(':')) break;

                        // read the value
                        JSONValue *v = parseValue();
                        if (_errCode != 0 ) break;

                        o.put(key,v);

                        skipSpace();

                        if (!expectOptional(',')) break;
                    }
                    if (!expect('}')) {
                        setError(2,"expected \" or } ");
                    }
            }
            if (_errCode != 0) {
                delete o;
                o = NULL;
            }
            return o;
        }

        bool isDigit(ushort c) {
            return (c >= '0' && c <= '9' ) || c == '+'  || c == '-'  ; 
        }

        bool isDoubleDigit(ushort c) {
            return (c >= '0' && c <= '9' ) || c == '+'  || c == '-'  || c == '.'  || c == 'e'  || c == 'E' ; 
        }

        void skipSpace() {
            while (_in[_pos] == ' ' || _in[_pos] == '\t' || _in[_pos]=='\r' || _in[_pos] == '\n' ) {
                if (_pos >= _len ) break;
                _pos++;
            }
        }

        bool expect(ushort c)
        {
            bool ret = false;
            if (c == _in[_pos]) {
                _pos++;
                ret = true;
            } else {
                setError(1,StringConcatenate("expected ",
                        ShortToString(c),"(",c,")",
                        " got ",ShortToString(_in[_pos]),"(",_in[_pos],")"));
            }
            return ret;
        }

        bool expectOptional(ushort c)
        {
            bool ret=false;
            if (c == _in[_pos]) {
                _pos++;
                ret = true;
            }
            return ret;
        }

        ushort peek() {
            return _in[_pos];
        }

        string parseString()
        {
            string ret = "";
            if(expect('"')) {
                while(true) {
                    int end=_pos;
                    while(end < _len && _in[end] != '"' && _in[end] != '\\' ) {
                        end++;
                    }

                    if (end >= _len) {
                        setError(2,"missing quote: end"+(string)end+":len"+(string)_len+":"+ShortToString(_in[_pos])+":"+StringSubstr(_instr,_pos,10)+"...");
                        break;
                    }
                    // Check if character was escaped.
                    // TODO \" \\ \/ \b \f \n \r \t \u0000
                    if (_in[end] == '\\') {
                        // Add partial string and get more
                        ret = ret + StringSubstr(_instr,_pos,end-_pos);
                        end++;
                        if (end >= _len) {
                          setError(4,"parse error after escape");
                        } else {
                            ushort c = 0;
                            switch(_in[end]) {
                                case '"':
                                case '\\':
                                case '/':
                                    c = _in[end];
                                    break;
                                case 'b': c = 8; break; // backspace - 8
                                case 'f': c = 12; break; // form feed 12
                                case 'n': c = '\n'; break;
                                case 'r': c = '\r'; break;
                                case 't': c = '\t'; break;
                                default:
                                          setError(3,"unknown escape");
                            }
                            if (c == 0) break;
                            ret = ret + ShortToString(c);
                            _pos = end+1;
                        }
                    } else if (_in[end] == '"') {
                        // End of string
                        ret = ret + StringSubstr(_instr,_pos,end-_pos);
                        _pos = end+1;
                        break;
                    }
                }
            }
            if (_errCode != 0) {
                ret = NULL;
            }
            return ret;
        }

        JSONValue *parseValue() 
        {
            JSONValue *ret = NULL;
            skipSpace();

            if (_in[_pos] == '[')  {

                ret = (JSONValue*)parseArray();

            } else if (_in[_pos] == '{')  {

                ret = (JSONValue*)parseObject();

            } else if (_in[_pos] == '"')  {

                string s = parseString();
                ret = (JSONValue*)new JSONString(s);

            } else if (isDoubleDigit(_in[_pos])) {
                bool isDoubleOnly = false;
                long l=0;
                long sign;
                // number
                int i = _pos;

                if (_in[_pos] == '-') {
                    sign = -1;
                    _pos++;
                } else if (_in[_pos] == '+') {
                    sign = 1;
                    _pos++;
                } else {
                    sign = 1;
                }

                while(i < _len && isDigit(_in[i])) {
                    l = l * 10 + ( _in[i] - '0' );
                    i++;
                }
                if (isDoubleDigit(_in[i])) {
                    // Looks like a real number;
                    while(i < _len && isDoubleDigit(_in[i])) {
                        i++;
                    }
                    string s2 = StringSubstr(_instr,_pos,i-_pos);
                    double d = sign * StringToDouble(s2);
                    ret = (JSONValue*)new JSONNumber(d); // Create a Number as double only
                } else {
                    l = sign * l;
                    ret = (JSONValue*)new JSONNumber(l); // Create a Number as a long
                }
                _pos = i;

            } else if (_in[_pos] == 't' && StringSubstr(_instr,_pos,4) == "true")  {

                ret = (JSONValue*)new JSONBool(true);
                _pos += 4;

            } else if (_in[_pos] == 'f' && StringSubstr(_instr,_pos,5) == "false")  {

                ret = (JSONValue*)new JSONBool(false);
                _pos += 5;

            } else if (_in[_pos] == 'n' && StringSubstr(_instr,_pos,4) == "null")  {

                ret = (JSONValue*)new JSONNull();
                _pos += 4;

            } else {

                setError(3,"error parsing value at position "+(string)_pos);

            }

            if (_errCode != 0 && ret != NULL ) {
                delete ret;
                ret = NULL;
            }
            return ret;
        }

        JSONArray *parseArray()
        {
            JSONArray *ret = new JSONArray();

            int index = 0;
            skipSpace();
            if (expect('[')) {
                skipSpace();
                if (peek() != ']') {
                    while (_errCode == 0) {

                        // read the value
                        JSONValue *v = parseValue();
                        if (_errCode != 0) break;

                        if (!ret.put(index++,v)) {
                            setError(3,"memory error adding "+(string)index);
                            break;
                        }

                        skipSpace();
                        if (!expectOptional(',')) break;
                        skipSpace();
                    }
                }
                if (!expect(']')) {
                    setError(2,"list: expected , or ] ");
                }
            }

            if (_errCode != 0 ) {
                delete ret;
                ret = NULL;
            }
            return ret;
        }
    public:
        int getErrorCode()
        {
            return _errCode;
        }
        string getErrorMessage()
        {
            return _errMsg;
        }
        /// Parse a sequnce of characters and return a JSONValue.
        JSONValue *parse(
                string s ///< Serialized JSON text
             )
        {
            int inLen;
            JSONValue *ret = NULL;
            StringTrimLeft(s);
            StringTrimRight(s);

            _instr = s;
            _len = StringToShortArray(_instr,_in); // nul '0' is added to length
            _pos = 0;
            _errCode = 0;
            _errMsg = "";
            inLen = StringLen(_instr);
            if (_len != inLen + 1 /* nul */ ) {
                setError(1,StringConcatenate("unable to create array ",inLen," got ",_len));
            } else {
                _len --;
                ret = parseValue();
                if (_errCode != 0) {
                    _errMsg = StringConcatenate(_errMsg," at ",_pos," [",StringSubstr(_instr,_pos,10),"...]");
                }
            }
            return ret;
        }

};

/// Class to iterate over a JSONObject (not a JSONArray)
class JSONIterator {
    private:
        HashLoop * _l;

    public:
    // Create iterator and move to first item
    JSONIterator(JSONObject *jo) 
    {
        _l = new HashLoop(jo.getHash());
    }
    ~JSONIterator() 
    {
        delete _l;
    }
    // Check if more items
    bool hasNext() 
    {
        return _l.hasNext();
    }

    // Move to next item
    void next() {
        _l.next();
    }

    // Return item
    JSONValue *val()
    {
        return (JSONValue *) (_l.val());
    }

    // Return key
    string key()
    {
        return _l.key();
    }

};

void json_demo() 
{
    string s = "{ \"firstName\": \"John\","+
       " \"lastName\": \"Smith\","+
       " \"age\": 25,"+
       " \"address\": { \"streetAddress\": \"21 2nd Street\", \"city\": \"New York\", \"state\": \"NY\", \"postalCode\": \"10021\" },"+
       " \"phoneNumber\": [ { \"type\": \"home\", \"number\": \"212 555-1234\" }, { \"type\": \"fax\", \"number\": \"646 555-4567\" } ],"+
       " \"gender\":{ \"type\":\"male\" }  }";

    JSONParser *parser = new JSONParser();
    JSONValue *jv = parser.parse(s);
    Print("json:");
    if (jv == NULL) {
        Print("error:"+(string)parser.getErrorCode()+parser.getErrorMessage());
    } else {
        Print("PARSED:"+jv.toString());
        if (jv.isObject()) {
            JSONObject *jo = jv;

            // Direct access - will throw null pointer if wrong getter used.
            Print("firstName:" + jo.getString("firstName"));
            Print("city:" + jo.getObject("address").getString("city"));
            Print("phone:" + jo.getArray("phoneNumber").getObject(0).getString("number"));

            // Safe access in case JSON data is missing or different.
            if (jo.getString("firstName",s) ) Print("firstName = "+s);

            // Loop over object returning JSONValue
            JSONIterator *it = new JSONIterator(jo);
            for( ; it.hasNext() ; it.next()) {
                Print("loop:"+it.key()+" = "+it.val().toString());
            }
            delete it;
        }
        delete jv;
    }
    delete parser;
}



#endif
