//+------------------------------------------------------------------+
//|                                                   CPT34FXBot.mqh |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+

#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

#include "Include\DKStdLib\Common\DKStdLib.mqh"
#include "Include\DKStdLib\Logger\DKLogger.mqh"
#include "Include\DKStdLib\TradingManager\CDKTrade.mqh"
#include "Include\DKStdLib\TradingManager\CDKSimplestTrailingStop.mqh"

class CPT34FXBotPos : public CObject {
public:
  ulong                    Ticket;
  double                   LevelPrice;
  double                   SLOriginal;  
  double                   TPOriginal;  
  double                   LotOriginal;  
};



class CPT34FXBot {
private:
  datetime                 LastPosBuyDT;
  datetime                 LastPosSellDT;
  datetime                 LastPosesSync;
  
  CArrayObj                Poses;
public:
  // Must be set direclty
  int                      PT34IndHandle;
  CDKTrade                 Trade;
  int                      Magic;
  DKLogger*                logger;
  string                   Sym;    
  ENUM_MM_TYPE             MMType;
  double                   MMValue;
  uint                     SLExtraShiftPnt;
  double                   TPRR;
  double                   TSLARR;
  double                   TSLDRR;
  bool                     TSLFixedTP;
  double                   BERatio;
  
  uint                     SPMaxValuePnt;
  
  uint                     SyncPosesSec;
    
  bool                     CPT34FXBot::ParseComment(const string _comment, double& _lev_price, double& _sl);
  bool                     CPT34FXBot::IsSpreadAllowed();
    
  // Signal detection
  bool                     CPT34FXBot::HasSignal(const ENUM_POSITION_TYPE _dir, double& _lev_prcie, double& _ind_sl);
  ulong                    CPT34FXBot::OpenPos(const ENUM_POSITION_TYPE _dir, const double _lev_price, double _sl);
  bool                     CPT34FXBot::PartialClose(CPositionInfo& _pos);
  ulong                    CPT34FXBot::MoveTrailingStop();
  
  bool                     CPT34FXBot::SyncPos();
  
  // Event Handlers
  void                     CPT34FXBot::OnTick(void);
  void                     CPT34FXBot::CDSADXBot(void);
};

//+------------------------------------------------------------------+
//| Parse pos comment and extract original lev_price and sl
//+------------------------------------------------------------------+
bool CPT34FXBot::ParseComment(const string _comment, double& _lev_price, double& _sl) {
  _lev_price = 0.0;
  _sl = 0.0;

  string chunks[];
  if (StringSplit(_comment, StringGetCharacter("|", 0), chunks) < 3)
    return false;
  
  _lev_price = StringToDouble(chunks[1]);
  _sl = StringToDouble(chunks[2]);
  
  return true;
}

//+------------------------------------------------------------------+
//| Check arrow signal on current bar from PT34 indicator buffer                                                                  |
//+------------------------------------------------------------------+
bool CPT34FXBot::HasSignal(const ENUM_POSITION_TYPE _dir, double& _lev_prcie, double& _ind_sl){
  double buf_arr[];
  double buf_sl[];
  int buf_arr_num = (_dir == POSITION_TYPE_BUY) ? 2 : 3;
  int buf_sl_num =  (_dir == POSITION_TYPE_BUY) ? 8 : 9;
  if (CopyBuffer(PT34IndHandle, buf_arr_num, 0, 1, buf_arr) <= 0 ||
      CopyBuffer(PT34IndHandle, buf_sl_num, 0, 1, buf_sl) <= 0)
    return false;
   
  bool res = buf_arr[0] > 0.0;
  string msg = StringFormat("%s/%d: RES=%s; DIR=%s; LEV_PRICE=%f; SL=%f", 
                             __FUNCTION__, __LINE__,
                             (res) ? "SIGNAL" : "NO_SIGNAL",
                             PositionTypeToString(_dir),
                             buf_arr[0],
                             buf_sl[0]
                             );
  logger.Assert(res, msg, INFO, msg, DEBUG);
  
  _lev_prcie = buf_arr[0];
  _ind_sl    = buf_sl[0];
  return res;      
}

//+------------------------------------------------------------------+
//| Open pos
//+------------------------------------------------------------------+
ulong CPT34FXBot::OpenPos(const ENUM_POSITION_TYPE _dir, const double _lev_price, double _sl) {
  _sl = _sl + ((_dir == POSITION_TYPE_BUY) ? -1 : +1) * PointsToPrice(Sym, SLExtraShiftPnt);
  double tp_dist = MathAbs(_sl-_lev_price);
  double tp = _lev_price + ((_dir == POSITION_TYPE_BUY) ? +1 : -1) * tp_dist * TPRR;
  double lot = CalculateLotSuper(Sym, MMType, MMValue, _lev_price, _sl);
  string comment = StringFormat("%s|%f|%f", logger.Name, _lev_price, _sl);
  
  ulong ticket = 0;
  if (_dir == POSITION_TYPE_BUY)
    ticket = Trade.Buy(lot, Sym, 0, _sl, tp, comment);
    
  if (_dir == POSITION_TYPE_SELL)
    ticket = Trade.Sell(lot, Sym, 0, _sl, tp, comment);
    
  if (ticket) {
    CPT34FXBotPos* pos = new CPT34FXBotPos;
    pos.Ticket = ticket;
    pos.LevelPrice = _lev_price;
    pos.SLOriginal = _sl;
    pos.TPOriginal = tp;
    pos.LotOriginal = lot;
    Poses.Add(pos);
  }  
    
  return ticket;
}

//+------------------------------------------------------------------+
//| Close part of pos                                                                 |
//+------------------------------------------------------------------+
bool CPT34FXBot::PartialClose(CPositionInfo& _pos) {
  double lot_to_close = MathMin(_pos.Volume(), NormalizeLot(Sym, _pos.Volume()*BERatio));
  Trade.PositionClosePartial(_pos.Ticket(), lot_to_close);
  return true;
}

//+------------------------------------------------------------------+
//| Check BE activation price and move SL to BE
//+------------------------------------------------------------------+
ulong CPT34FXBot::MoveTrailingStop() {
  CPositionInfo pos;
  CDKSimplestTrailingStop tsl;
  for (int i=0; i<Poses.Total(); i++) {
    CPT34FXBotPos* bot_pos = Poses.At(i);
    if (!pos.SelectByTicket(bot_pos.Ticket)) continue;

    if (pos.Magic()  != Magic) continue;
    if (pos.Symbol() != Sym) continue;

    double lev_price = bot_pos.LevelPrice;
    double sl = bot_pos.SLOriginal;
    
    double activation_price = lev_price + ((pos.PositionType() == POSITION_TYPE_BUY) ? +1 : -1)*MathAbs(lev_price-sl)*TSLARR;
    double tsl_dist = MathAbs(lev_price-sl)*TSLDRR;
    double pos_sl = pos.StopLoss();
    
    tsl.Init(activation_price, tsl_dist, Trade);    
    if (tsl.updateTrailingStop(true, !TSLFixedTP) == TRADE_RETCODE_DONE) // TSL's moved successfully
      if (BERatio > 0 && CompareDouble(sl, pos_sl)) // pos_sl is equal sl of int yet
        PartialClose(pos);      
  }
  
  return 0;
}

bool CPT34FXBot::SyncPos() {
  CPositionInfo pos_mkt;
  int i=0;
  while (i<Poses.Total()) {
    CPT34FXBotPos* pos_bot = Poses.At(i);
    if (!pos_mkt.SelectByTicket(pos_bot.Ticket)){
      delete pos_bot;
      Poses.Delete(i);
      continue;      
    }      
    i++;
  }
  
  for (int i=0; i<PositionsTotal(); i++) {
    if (!pos_mkt.SelectByIndex(i)) continue;
    if (pos_mkt.Symbol() != Sym) continue;
    if (pos_mkt.Magic() != Magic) continue;
    
    bool found = false;
    for (int j=0; i<Poses.Total(); j++) {
      CPT34FXBotPos* pos_bot = Poses.At(j);
      if (pos_bot.Ticket == pos_mkt.Ticket()) {
        found = true;
        break;
      }
    }
    
    double lev_price = 0.0;
    double sl = 0.0;
    if (!found && ParseComment(pos_mkt.Comment(), lev_price, sl)) {
      CPT34FXBotPos* pos_bot = new CPT34FXBotPos;
      pos_bot.Ticket = pos_mkt.Ticket();
      pos_bot.LevelPrice = lev_price;
      pos_bot.SLOriginal = sl;
      double tp_dist = MathAbs(sl-lev_price);
      pos_bot.TPOriginal = lev_price + ((pos_mkt.PositionType() == POSITION_TYPE_BUY) ? +1 : -1) * tp_dist * TPRR;
      Poses.Add(pos_bot);
    }
  }
  
  return true;
}

//+------------------------------------------------------------------+
//| Check current spread                                                                  |
//+------------------------------------------------------------------+
bool CPT34FXBot::IsSpreadAllowed() {
  CSymbolInfo sym;
  if (!sym.Name(Sym)) return false;
  if (!sym.RefreshRates()) return false;  
  
  int curr_spread = PriceToPoints(Sym, MathAbs(sym.Ask()-sym.Bid()));
  if (curr_spread>(int)SPMaxValuePnt) {
    logger.Debug(StringFormat("%s/%d: Current spread is too high: %d>%d",
                              __FUNCTION__, __LINE__,
                              curr_spread,
                              SPMaxValuePnt));
    return false;
  }
  
  return true;
}

//+------------------------------------------------------------------+
//| OnTick Handler
//+------------------------------------------------------------------+
void CPT34FXBot::OnTick(void) {
  // Move TSL and Partial close
  if (TSLARR > 0)
    MoveTrailingStop();      
    
  // Sync Poses
  if (TimeCurrent() > (LastPosesSync+SyncPosesSec)) {
    SyncPos();
    LastPosesSync = TimeCurrent();
  }
  
  // Check max spread allowed
  if (SPMaxValuePnt > 0) 
    if (!IsSpreadAllowed())
      return;

  // Open pos using signal
  double lev_price = 0.0;
  double sl = 0.0;
  datetime curr_bar_dt = iTime(Sym, PERIOD_CURRENT, 0);
  if (curr_bar_dt > LastPosBuyDT && HasSignal(POSITION_TYPE_BUY, lev_price, sl)) 
    if (OpenPos(POSITION_TYPE_BUY, lev_price, sl))
      LastPosBuyDT = curr_bar_dt;
    
  if (curr_bar_dt > LastPosSellDT && HasSignal(POSITION_TYPE_SELL, lev_price, sl)) 
    if (OpenPos(POSITION_TYPE_SELL, lev_price, sl))
      LastPosSellDT = curr_bar_dt;      
      

}

//+------------------------------------------------------------------+
//| Constructor
//+------------------------------------------------------------------+
void CPT34FXBot::CDSADXBot(void) {
  Sym = Symbol();
  LastPosBuyDT = 0;
  LastPosSellDT = 0;
  Poses.Clear();
  
  SyncPosesSec = 1*60; // Every 1 min
  LastPosesSync = 0;
}