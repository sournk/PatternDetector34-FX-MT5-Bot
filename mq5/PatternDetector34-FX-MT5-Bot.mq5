//+------------------------------------------------------------------+
//|                                 PatternDetector34-FX-MT5-Bot.mq5 |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+

#include <Trade\AccountInfo.mqh>
#include <Trade\PositionInfo.mqh>

#include "Include\DKStdLib\Common\DKStdLib.mqh"
#include "Include\DKStdLib\License\DKLicense.mqh"
#include "Include\DKStdLib\Logger\DKLogger.mqh"
#include "Include\DKStdLib\TradingManager\CDKTrade.mqh"

#property script_show_inputs

#include <Arrays\ArrayObj.mqh>

#include "Include\DKStdLib\TradingManager\CDKPositionInfo.mqh"
#include "Include\DKStdLib\TradingManager\CDKSymbolInfo.mqh"
#include <Trade\Trade.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#include "Include\DKStdLib\Common\DKStdLib.mqh"
#include "Include\DKStdLib\Logger\DKLogger.mqh"
#include "Include\DKStdLib\NewBarDetector\DKNewBarDetector.mqh" 
//#include "Include\DKStdLib\Analysis\DKChartAnalysis.mqh"
//#include "Include\DKStdLib\Drawing\DKChartDraw.mqh"

#include "CPT34FXBot.mqh" 

enum ENUM_ARROW_POS {
  ARROW_POS_HIT,          // Возврат в уровень
  ARROW_POS_CONFIRM       // Подтверждения по MA
};


#property script_show_inputs

input  group              "0. ТОРГОВЛЯ"
input  ENUM_MM_TYPE       InpMMT                            = ENUM_MM_TYPE_FIXED_LOT;           // 0.MM.T: Money Management Type
input  double             InpMMV                            = 0.1;                              // 0.MM.L: Money Management Value
input  ulong              InpSLP                            = 2;                                // 0.SLP: Макс. проскальзование операций, пунктов
input  uint               InpSLExtraShiftPnt                = 0;                                // 0.SL.ES: Дополнительный сдвиг SL, пунктов
input  double             InpTPRR                           = 2.0;                              // 0.TP.RR: Коэффициент RR для TP
input  double             InpTSLARR                         = 1.0;                              // 0.TSL.ARR: Коэффициент RR для активации TSL (0-откл.)
input  double             InpTSLDRR                         = 1.0;                              // 0.TSL.DRR: Коэффициент RR для дистанции TSL
input  bool               InpTSLFixedTP                     = false;                            // 0.TSL.FTP: Фиксировать TP после активации TSL
input  double             InpBERatio                        = 0.5;                              // 0.BE.R: Закрыть часть позизции при активации TSL (0-откл.)
input  uint               InpSPMaxValuePnt                  = 0;                                // 0.SP.MV: Максимально допустимый спред для входа (0-откл.)

input  group              "1. НАСТРОЙКИ ПАТТЕРНОВ И УРОВНЕЙ"
input  ENUM_TIMEFRAMES    InpTFPatternDetection             = PERIOD_M5;                        // 1.01: Таймферм определения паттернов и уровней 
input  uint               InpDepthHour                      = 1;                                // 1.02: Глубина определения паттернов в прошлое, часов

input  group              "2. НАСТРОЙКИ СИГНАЛОВ"
input  ENUM_TIMEFRAMES    InpTFSignalDetection              = PERIOD_M1;                        // 2.01: Таймферм определения сигнала по паттерну 

input  group              "3. ВЕРХНИЙ УРОВЕНЬ"
input  bool               InpPattern01Active                = true;                             // 3.01: Включен
input  string             InpPattern01BarList               = "TH;TOCHL;TOCHL";                 // 3.02: Комбинации цен баров для определения уровня
input  uint               InpPattern01K                     = 50;                               // 3.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
input  uint               InpPattern01N                     = 100;                              // 3.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
input  uint               InpPattern01S                     = 120;                              // 3.05: Макс. время S, мин. (от пробития до возврата в уровень)
input  uint               InpPattern01С                     = 5;                                // 3.06: Макс. время C, мин. (от возврата до сигнала)
input  int                InpPattern01LevelShiftPoint       = 0;                                // 3.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
input  bool               InpPattern01ExtremeLevel          = false;                            // 3.08: Уровень по экстремуму паттерна (иначе по первому бару)
input  bool               InpPattern01LHLastBarCHitsExtreme = true;                             // 3.09: CLOSE пробивающего выше HIGH (если паттерн с HIGH)
input  uint               InpPattern01CheckBTRExtremeFrom   = 0;                                // 3.10: Первый № бара паттерна, где LOW д.б. выше прошлого 
input  uint               InpPattern01CheckBTRExtremeTo     = 0;                                // 3.11: Последний № бара паттерна, где LOW д.б. выше прошлого 
input  uint               InpPattern01CheckCloseFromBar     = 0;                                // 3.12: Закрытие ниже уровня начиная с № бара (0-откл)
input  uint               InpPattern01CheckCloseTolerancePnt= 0;                                // 3.13: Закрытие ниже уровня допуск (0-откл), пункт
input  bool               InpPattern01MA20Check             = true;                             // 3.14: Короткая MA: Проверить положение цены по после возврата
input  int                InpPattern01MA20Period            = 20;                               // 3.15: Короткая MA: Период
input  int                InpPattern01MA20Shift             = 0;                                // 3.16: Короткая MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern01MA20Method            = MODE_SMA;                         // 3.17: Короткая MA: Метод
input  ENUM_APPLIED_PRICE InpPattern01MA20AppliedPrice      = PRICE_CLOSE;                      // 3.18: Короткая MA: Цена
input  bool               InpPattern01MA100Check            = true;                             // 3.19: Длинная MA: Проверить направление после возврата
input  int                InpPattern01MA100Period           = 100;                              // 3.20: Длинная MA: Период
input  int                InpPattern01MA100Shift            = 0;                                // 3.21: Длинная MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern01MA100Method           = MODE_SMA;                         // 3.22: Длинная MA: Метод
input  ENUM_APPLIED_PRICE InpPattern01MA100AppliedPrice     = PRICE_CLOSE;                      // 3.23: Длинная MA: Цена
input  ENUM_ARROW_POS     InpPattern01ArrowPos              = ARROW_POS_CONFIRM;                // 3.24: Момент появления стрелки

input  group              "4. НИЖНИЙ УРОВЕНЬ"
input  bool               InpPattern02Active                = true;                             // 4.01: Включен
input  string             InpPattern02BarList               = "BL;BOCLH;BOCLH";                 // 4.02: Комбинации цен баров для определения уровня
input  uint               InpPattern02K                     = 50;                               // 4.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
input  uint               InpPattern02N                     = 100;                              // 4.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
input  uint               InpPattern02S                     = 120;                              // 4.05: Макс. время S, мин. (от пробития до возврата в уровень)
input  uint               InpPattern02С                     = 5;                                // 4.06: Макс. время C, мин. (от возврата до сигнала)
input  int                InpPattern02LevelShiftPoint       = 0;                                // 4.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
input  bool               InpPattern02ExtremeLevel          = false;                            // 4.08: Уровень по экстремуму паттерна (иначе по первому бару)
input  bool               InpPattern02LHLastBarCHitsExtreme = true;                             // 4.09: CLOSE пробивающего ниже HIGH (если паттерн с LOW)
input  uint               InpPattern02CheckBTRExtremeFrom   = 0;                                // 4.10: Первый № бара паттерна, где HIGH д.б. ниже прошлого 
input  uint               InpPattern02CheckBTRExtremeTo     = 0;                                // 4.11: Последний № бара паттерна, где HIGH д.б. ниже прошлого 
input  uint               InpPattern02CheckCloseFromBar     = 0;                                // 4.12: Закрытие выше уровня начиная с № бара (0-откл)
input  uint               InpPattern02CheckCloseTolerancePnt= 0;                                // 4.13: Закрытие выше уровня допуск (0-откл), пункт
input  bool               InpPattern02MA20Check             = true;                             // 4.14: Короткая MA: Проверить положение цены по после возврата
input  int                InpPattern02MA20Period            = 20;                               // 4.15: Короткая MA: Период
input  int                InpPattern02MA20Shift             = 0;                                // 4.16: Короткая MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern02MA20Method            = MODE_SMA;                         // 4.17: Короткая MA: Метод
input  ENUM_APPLIED_PRICE InpPattern02MA20AppliedPrice      = PRICE_CLOSE;                      // 4.18: Короткая MA: Цена
input  bool               InpPattern02MA100Check            = true;                             // 4.19: Длинная MA: Проверить направление после возврата
input  int                InpPattern02MA100Period           = 100;                              // 4.20: Длинная MA: Период
input  int                InpPattern02MA100Shift            = 0;                                // 4.21: Длинная MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern02MA100Method           = MODE_SMA;                         // 4.22: Длинная MA: Метод
input  ENUM_APPLIED_PRICE InpPattern02MA100AppliedPrice     = PRICE_CLOSE;                      // 4.23: Длинная MA: Цена
input  ENUM_ARROW_POS     InpPattern02ArrowPos              = ARROW_POS_CONFIRM;                // 4.24: Момент появления стрелки

input  group              "5. ФИЛЬТР ПО ВРЕМЕНИ"
input int                 InpTimeAddHours                   = 3;                                // 5.01: Сдвиг времени в часах
input string              InpTimeMonday_Not_Arrow           = "08:30-08:55,10:30-12:15";        // 5.02: Понедельник не торговые периоды (максимум 20 периодов)
input string              InpTimeTuesday_Not_Arrow          = "08:30-08:55,10:30-12:15";        // 5.03: Вторник не торговые периоды (максимум 20 периодов)
input string              InpTimeWednesday_Not_Arrow        = "08:30-08:55,10:30-12:15";        // 5.04: Среда не торговые периоды (максимум 20 периодов)
input string              InpTimeThursday_Not_Arrow         = "08:30-08:55,10:30-12:15";        // 5.05: Четверг не торговые периоды (максимум 20 периодов)
input string              InpTimeFriday_Not_Arrow           = "08:30-08:55,10:30-12:15";        // 5.06: Пятница не торговые периоды (максимум 20 периодов)
input string              InpTimeEveryDay_Not_Arrow         = "00:00-01:00";                    // 5.07: Не торговые периоды на каждый день (максимум 20 периодов)
input string              InpTimeEveryHour_Not_Arrow        = "00-10";                          // 5.08: Не торговые периоды на каждый час (максимум 20 периодов)

input  group              "6. ГРАФИКА"
sinput bool               InpPatternDraw                    = true;                             // 6.01A: Рисовать уровни
sinput bool               InpPatternDrawNonHit              = false;                            // 6.01B: Рисовать уровни без возврата в уровень
sinput uint               InpPattern01ArrowCode             = 233;                              // 6.02: ВЕРХ: Код символа стрелки
sinput uint               InpPattern02ArrowCode             = 234;                              // 6.03: НИЗ: Код символа стрелки
sinput uint               InpPattern01StartCode             = 167;                              // 6.04: ВЕРХ: Код символа начала и подтверждения паттерна
sinput uint               InpPattern02StartCode             = 167;                              // 6.05: НИЗ: Код символа начала и подтверждения паттерна
sinput string             InpPattern01Name                  = "ВЕРХ";                           // 6.06: ВЕРХ: Подпись линий уровня
sinput string             InpPattern02Name                  = "НИЗ";                            // 6.07: НИЗ: Подпись линий уровня
sinput color              InpPattern01Color                 = clrGreen;                         // 6.08: ВЕРХ: Цвет
sinput color              InpPattern02Color                 = clrRed;                           // 6.09: НИЗ: Цвет

input  group              "7. ПРОЧЕЕ"
sinput LogLevel           InpLL                             = LogLevel(INFO);                   // 7.01: Уровень логирования
sinput int                InpMGC                            = 20240512;                         // 7.02: Magic
       int                InpAUP                            = 32*24*60*60;                      // 10.AUP: Allowed usage period, sec
       string             InpGP                             = "PT34.FX";                        // 10.GP: Global Prefix

int                       ind_handle_pd34;
DKLogger                  logger;
CDKTrade                  trade;
CPT34FXBot                bot;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  //Check dev/test allowed period
  if (CheckExpiredAndShowMessage(InpAUP)) return(INIT_FAILED);  

  // Logger init
  logger.Name   = InpGP;
  logger.Level  = InpLL;
  logger.Format = "%name%:[%level%] %message%";
  
  Print(InpPattern02S, " ", InpPattern02С);
  if ((InpDepthHour*60 <= (InpPattern02S + InpPattern02С)) || (InpDepthHour*60 <= (InpPattern01S + InpPattern01С))) {
    string msg = "Глубина определения паттернов (1.02) должна быть больше суммы времен ожидания возврата в уровень и ожидания сигнала (*.05+*.06)";
    logger.Critical(msg, true);
    return(INIT_PARAMETERS_INCORRECT);
  }   
  
  ind_handle_pd34 = iCustom(_Symbol, _Period, "PatternDetector34-MT5-Ind", 
                        //"1. НАСТРОЙКИ ПАТТЕРНОВ И УРОВНЕЙ",
                        InpTFPatternDetection, //             = PERIOD_M5;                        // 1.01: Таймферм определения паттернов и уровней 
                        InpDepthHour, //                      = 1*32*24;                          // 1.02: Глубина определения паттернов в прошлое, часов
                        
                        //"2. НАСТРОЙКИ СИГНАЛОВ",
                        InpTFSignalDetection, //              = PERIOD_M1;                        // 2.01: Таймферм определения сигнала по паттерну 
                        
//                        InpMAShortPeriod, //                  = 20;                               // 2.01: Фильтр 1. Короткая MA: Период
//                        InpMAShortShift, //                   = 0;                                // 2.02: Фильтр 1. Короткая MA: Сдвиг
//                        InpMAShortMethod, //                  = MODE_SMA;                         // 2.03: Фильтр 1. Короткая MA: Метод
//                        InpMAShortAppliedPrice, //            = PRICE_CLOSE;                      // 2.04: Фильтр 1. Короткая MA: Цена
//
//                        InpMALongPeriod, //                   = 100;                              // 2.05: Фильтр 2. Длинная MA: Период
//                        InpMALongShift, //                    = 0;                                // 2.06: Фильтр 2. Длинная MA: Сдвиг
//                        InpMALongMethod, //                   = MODE_SMA;                         // 2.07: Фильтр 2. Длинная MA: Метод
//                        InpMALongAppliedPrice, //             = PRICE_CLOSE;                      // 2.08: Фильтр 2. Длинная MA: Цена
//                        
//                        "3. ВЕРХНИЙ УРОВЕНЬ",
                        InpPattern01Active, //                = true;                             // 3.01: Включен
                        InpPattern01BarList, //               = "TH;TOCHL;TOCHL";                 // 3.02: Комбинации цен баров для определения уровня
                        InpPattern01K, //                     = 50;                               // 3.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
                        InpPattern01N, //                     = 100;                              // 3.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
                        InpPattern01S, //                     = 120;                              // 3.05: Макс. время S, мин. (от пробития до возврата в уровень)
                        InpPattern01С, //                     = 5;                                // 3.06: Макс. время C, мин. (от возврата до сигнала)
                        InpPattern01LevelShiftPoint, //       = 0;                                // 3.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
                        InpPattern01ExtremeLevel, //          = false;                            // 3.08: Уровень по экстремуму паттерна (иначе по первому бару)
                        InpPattern01LHLastBarCHitsExtreme, // = true;                             // 3.09: CLOSE пробивающего выше HIGH (если паттерн с HIGH)
                        InpPattern01CheckBTRExtremeFrom, //   = 0;                                // 3.10: Первый № бара паттерна, где LOW д.б. выше прошлого 
                        InpPattern01CheckBTRExtremeTo, //     = 0;                                // 3.11: Последний № бара паттерна, где LOW д.б. выше прошлого 
                        InpPattern01CheckCloseFromBar, //     = 0;                                // 3.12: Начиная с бара проверить закрытие ниже уровня (0-откл)
                        InpPattern01CheckCloseTolerancePnt, //= 0;                                // 3.13: Закрытие ниже уровня допуск (0-откл), пункт
                        InpPattern01MA20Check,                                                    // 3.14: Короткая MA: Проверить положение цены по после возврата
                        InpPattern01MA20Period,                                                   // 3.15: Короткая MA: Период
                        InpPattern01MA20Shift,                                                    // 3.16: Короткая MA: Сдвиг
                        InpPattern01MA20Method,                                                   // 3.17: Короткая MA: Метод
                        InpPattern01MA20AppliedPrice,                                             // 3.18: Короткая MA: Цена
                        InpPattern01MA100Check,                                                   // 3.19: Длинная MA: Проверить направление после возврата
                        InpPattern01MA100Period,                                                  // 3.20: Длинная MA: Период
                        InpPattern01MA100Shift,                                                   // 3.21: Длинная MA: Сдвиг
                        InpPattern01MA100Method,                                                  // 3.22: Длинная MA: Метод
                        InpPattern01MA100AppliedPrice,                                            // 3.23: Длинная MA: Цена
                        InpPattern01ArrowPos,                                                     // 3.24: Момент появления стрелки
                        
                        //"4. НИЖНИЙ УРОВЕНЬ",
                        InpPattern02Active, //                = true;                             // 4.01: Включен
                        InpPattern02BarList, //               = "BL;BOCLH;BOCLH";                 // 4.02: Комбинации цен баров для определения уровня
                        InpPattern02K, //                     = 50;                               // 4.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
                        InpPattern02N, //                     = 100;                              // 4.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
                        InpPattern02S, //                     = 120;                              // 4.05: Макс. время S, мин. (от пробития до возврата в уровень)
                        InpPattern02С, //                     = 5;                                // 4.06: Макс. время C, мин. (от возврата до сигнала)
                        InpPattern02LevelShiftPoint, //       = 0;                                // 4.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
                        InpPattern02ExtremeLevel, //          = false;                            // 4.08: Уровень по экстремуму паттерна (иначе по первому бару)
                        InpPattern02LHLastBarCHitsExtreme, // = true;                             // 4.09: CLOSE пробивающего ниже HIGH (если паттерн с LOW)
                        InpPattern02CheckBTRExtremeFrom, //   = 0;                                // 4.10: Первый № бара паттерна, где HIGH д.б. ниже прошлого 
                        InpPattern02CheckBTRExtremeTo, //     = 0;                                // 4.11: Последний № бара паттерна, где HIGH д.б. ниже прошлого 
                        InpPattern02CheckCloseFromBar, //     = 0;                                // 4.12: Начиная с бара проверить закрытие выше уровня (0-откл) 
                        InpPattern02CheckCloseTolerancePnt, //
                        InpPattern02MA20Check,                                                    // 4.14: Короткая MA: Проверить положение цены по после возврата
                        InpPattern02MA20Period,                                                   // 4.15: Короткая MA: Период
                        InpPattern02MA20Shift,                                                    // 4.16: Короткая MA: Сдвиг
                        InpPattern02MA20Method,                                                   // 4.17: Короткая MA: Метод
                        InpPattern02MA20AppliedPrice,                                             // 4.18: Короткая MA: Цена
                        InpPattern02MA100Check,                                                   // 4.19: Длинная MA: Проверить направление после возврата
                        InpPattern02MA100Period,                                                  // 4.20: Длинная MA: Период
                        InpPattern02MA100Shift,                                                   // 4.21: Длинная MA: Сдвиг
                        InpPattern02MA100Method,                                                  // 4.22: Длинная MA: Метод
                        InpPattern02MA100AppliedPrice,                                            // 4.23: Длинная MA: Цена
                        InpPattern02ArrowPos,                                                     // 4.24: Момент появления стрелки
                        
                        //"5. ФИЛЬТР ПО ВРЕМЕНИ",
                        InpTimeAddHours, //                   = 3;                                // 5.01: Сдвиг времени в часах
                        InpTimeMonday_Not_Arrow, //           = "08:30-08:55,10:30-12:15";        // 5.02: Понедельник не торговые периоды (максимум 20 периодов)
                        InpTimeTuesday_Not_Arrow, //          = "08:30-08:55,10:30-12:15";        // 5.03: Вторник не торговые периоды (максимум 20 периодов)
                        InpTimeWednesday_Not_Arrow,  //       = "08:30-08:55,10:30-12:15";        // 5.04: Среда не торговые периоды (максимум 20 периодов)
                        InpTimeThursday_Not_Arrow, //         = "08:30-08:55,10:30-12:15";        // 5.05: Четверг не торговые периоды (максимум 20 периодов)
                        InpTimeFriday_Not_Arrow, //           = "08:30-08:55,10:30-12:15";        // 5.06: Пятница не торговые периоды (максимум 20 периодов)
                        InpTimeEveryDay_Not_Arrow, //         = "00:00-01:00";                    // 5.07: Не торговые периоды на каждый день (максимум 20 периодов)
                        InpTimeEveryHour_Not_Arrow, //        = "00-10";                          // 5.08: Не торговые периоды на каждый час (максимум 20 периодов)
                        
                        //"6. ГРАФИКА",
                        InpPatternDraw, //                    = true;                             // 6.01: Рисовать уровни
                        InpPatternDrawNonHit
                        //InpPattern01ArrowCode, //             = 233;                              // 6.02: ВЕРХ: Код символа стрелки
                        //InpPattern02ArrowCode  //             = 234;                              // 6.03: НИЗ: Код символа стрелки
//                        InpPattern01StartCode, //             = 167;                              // 6.04: ВЕРХ: Код символа начала и подтверждения паттерна
//                        InpPattern02StartCode, //             = 167;                              // 6.05: НИЗ: Код символа начала и подтверждения паттерна
//                        InpPattern01Name, //                  = "ВЕРХ";                           // 6.06: ВЕРХ: Подпись линий уровня
//                        InpPattern02Name, //                  = "НИЗ";                            // 6.07: НИЗ: Подпись линий уровня
//                        InpPattern01Color, //                 = clrGreen;                         // 6.08: ВЕРХ: Цвет
//                        InpPattern02Color, //                 = clrRed;                           // 6.09: Цвет символа
//                        
//                        "7. ПРОЧЕЕ",
//                        InpLogLevel //                       = LogLevel(WARN);                  // 7.01: Уровень логирования
                        ); 
                        
  if(ind_handle_pd34 < 0) {
    logger.Critical("PatternDetector23 Indicator load failed");
    return(INIT_FAILED);
  }     
  
  trade.SetExpertMagicNumber(InpMGC);
  trade.SetMarginMode();
  trade.SetTypeFillingBySymbol(Symbol());
  trade.SetDeviationInPoints(InpSLP);  
  trade.LogLevel(LOG_LEVEL_NO);
  trade.SetLogger(logger);
  
  bot.Sym = Symbol();
  bot.MMType = InpMMT;
  bot.MMValue = InpMMV;
  bot.SLExtraShiftPnt = InpSLExtraShiftPnt;
  bot.TPRR = InpTPRR;
  bot.TSLARR = InpTSLARR;
  bot.TSLDRR = InpTSLDRR;
  bot.TSLFixedTP = InpTSLFixedTP;
  bot.BERatio = InpBERatio;
  bot.SPMaxValuePnt = InpSPMaxValuePnt;

  bot.PT34IndHandle = ind_handle_pd34;
  
  bot.Trade = trade;
  bot.Magic = InpMGC;
  bot.logger = GetPointer(logger);
  
  EventSetTimer(5);
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
  bot.OnTick();
}
//+------------------------------------------------------------------+
//| OnTimer                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade() {

}
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
}
