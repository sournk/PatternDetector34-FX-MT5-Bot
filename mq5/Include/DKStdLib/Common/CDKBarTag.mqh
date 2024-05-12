//+------------------------------------------------------------------+
//|                                                    CDKBarTag.mqh |
//|                                                  Denis Kislitsyn |
//|                                               http:/kislitsyn.me |
//+------------------------------------------------------------------+

#include "DKStdLib.mqh" 

class CDKBarTag {
protected:
  string                _Sym;
  ENUM_TIMEFRAMES       _TF;
  int                   _Index;  
  datetime              _Time;  
  double                _Value;
 
public:
  void                  CDKBarTag::CDKBarTag(void);
  void                  CDKBarTag::CDKBarTag(const string aSymbol, const ENUM_TIMEFRAMES aTF);
  void                  CDKBarTag::CDKBarTag(const string aSymbol, const ENUM_TIMEFRAMES aTF, const int aIndex, const double aValue=0);
  void                  CDKBarTag::CDKBarTag(const string aSymbol, const ENUM_TIMEFRAMES aTF, const datetime aTime, const double aValue=0);
  void                  CDKBarTag::Init(const string aSymbol, const ENUM_TIMEFRAMES aTF);
  void                  CDKBarTag::Init(const string aSymbol, const ENUM_TIMEFRAMES aTF, const int aIndex, const double aValue=0);
  void                  CDKBarTag::Init(const string aSymbol, const ENUM_TIMEFRAMES aTF, const datetime aTime, const double aValue=0);  
  
  string                CDKBarTag::__repr__();
  string                CDKBarTag::__repr__(const bool aShortFormat=false);
  
  int                   CDKBarTag::SetTime(const datetime aTime, const bool aExact=false);
  int                   CDKBarTag::SetTimeAndValue(const datetime aTime, const double aValue, const bool aExact=false);
  void                  CDKBarTag::SetIndex(const int aIndex);  
  void                  CDKBarTag::SetIndexAndValue(const int aIndex, const double aValue);  
  int                   CDKBarTag::UpdateIndex(const bool aExact = false);
  void                  CDKBarTag::SetValue(const double aValue);  
  
  int                   CDKBarTag::GetIndex(const bool aUpdate=false, const bool aExact = false);
  datetime              CDKBarTag::GetTime();  
  double                CDKBarTag::GetValue();
};

void CDKBarTag::CDKBarTag(void) {
  _Sym = "";
  _TF = PERIOD_CURRENT;
  _Index = -1;
  _Time = 0;
  _Value = 0;
}

void CDKBarTag::CDKBarTag(const string aSymbol, const ENUM_TIMEFRAMES aTF) {
  _Sym = aSymbol;
  _TF = aTF;
  _Index = -1;
  _Time = 0;
  _Value = 0;
}

void CDKBarTag::CDKBarTag(const string aSymbol, const ENUM_TIMEFRAMES aTF, const int aIndex, const double aValue=0) {
  _Sym = aSymbol;
  _TF = aTF;
  _Value = aValue;
  SetIndex(aIndex);
}

void CDKBarTag::CDKBarTag(const string aSymbol, const ENUM_TIMEFRAMES aTF, const datetime aTime, const double aValue=0) {
  _Sym = aSymbol;
  _TF = aTF;
  _Value = aValue;
  SetTime(aTime);
}

void CDKBarTag::Init(const string aSymbol, const ENUM_TIMEFRAMES aTF) {
  _Sym = aSymbol;
  _TF = aTF;
  _Index = -1;
  _Time = 0;
  _Value = 0;
}

void CDKBarTag::Init(const string aSymbol, const ENUM_TIMEFRAMES aTF, const int aIndex, const double aValue=0) {
  _Sym = aSymbol;
  _TF = aTF;
  _Value = aValue;
  SetIndex(aIndex);
}

void CDKBarTag::Init(const string aSymbol, const ENUM_TIMEFRAMES aTF, const datetime aTime, const double aValue=0) {
  _Sym = aSymbol;
  _TF = aTF;
  _Value = aValue;
  SetTime(aTime);
}

string  CDKBarTag::__repr__() {
  return StringFormat("BT(%s,%s,%s/%d,%f)",
                      _Sym,
                      TimeframeToString(_TF),
                      TimeToStringNA(_Time),
                      _Index,
                      _Value
                      );
}

string CDKBarTag::__repr__(const bool aShortFormat=false) {
  return StringFormat("BT(%s/%d,%f)",
                      TimeToStringNA(_Time),
                      _Index,
                      _Value
                      );
}

void CDKBarTag::SetIndex(const int aIndex) {
  _Index = aIndex;
  _Time = iTime(_Sym, _TF, _Index);
}

void CDKBarTag::SetIndexAndValue(const int aIndex, const double aValue) {
  _Value = aValue;
  SetIndex(aIndex);
}

int CDKBarTag::SetTime(const datetime aTime, const bool aExact = false) {
  _Time = aTime;
  _Index = iBarShift(_Sym, _TF, _Time, aExact);
  if (_Index < 0) _Time = 0;
  
  return _Index;
}

int CDKBarTag::SetTimeAndValue(const datetime aTime, const double aValue, const bool aExact=false) {
  _Value = aValue;
  return SetTime(aTime, aExact);
}

int CDKBarTag::UpdateIndex(const bool aExact = false) {
  return SetTime(_Time, aExact);  
}

void CDKBarTag::SetValue(const double aValue) {
  _Value = aValue;
}

int CDKBarTag::GetIndex(const bool aUpdate=false, const bool aExact = false){
  if (aUpdate) UpdateIndex(aExact);
  return _Index;
}

datetime CDKBarTag::GetTime() {
  return _Time;
}

double CDKBarTag::GetValue() {
  return _Value;
}