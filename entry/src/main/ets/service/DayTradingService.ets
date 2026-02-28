import { TradeRecord } from '../model/entity/TradeRecord';
import { TradeType } from '../common/constants/Constants';
import { RdbHelper } from '../database/RdbHelper';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'DayTradingService';
const DOMAIN = 0x0000;

export interface DayTradingPair {
  id: string;
  assetId: number;
  assetName: string;
  assetCode: string;
  sellTrade: TradeRecord;
  buyTrade: TradeRecord;
  profit: number;
  tradeDate: string;
}

export interface DayTradingSummary {
  totalProfit: number;
  totalTrades: number;
  winRate: number;
  avgProfit: number;
  maxProfit: number;
  maxLoss: number;
}

export class DayTradingService {
  static async createDayTradingPair(sellTrade: TradeRecord, buyTrade: TradeRecord): Promise<DayTradingPair> {
    const profit = (sellTrade.price * sellTrade.quantity - sellTrade.fee) - 
                   (buyTrade.price * buyTrade.quantity + buyTrade.fee);
    
    const tradeDate = new Date(sellTrade.tradeTime).toISOString().split('T')[0];
    
    const result: DayTradingPair = {
      id: `${sellTrade.id}_${buyTrade.id}`,
      assetId: sellTrade.assetId,
      assetName: sellTrade.assetName,
      assetCode: sellTrade.assetCode,
      sellTrade,
      buyTrade,
      profit,
      tradeDate
    };
    return result;
  }

  static async getDayTradingPairsByDate(date: string): Promise<DayTradingPair[]> {
    const startTime = new Date(date).setHours(0, 0, 0, 0);
    const endTime = new Date(date).setHours(23, 59, 59, 999);
    
    const trades = await RdbHelper.queryTradesByDateRange(startTime, endTime);
    const dayTradingTrades = trades.filter(t => t.type === TradeType.T_BUY || t.type === TradeType.T_SELL);
    
    return DayTradingService.pairDayTradingTrades(dayTradingTrades);
  }

  static async getDayTradingPairsByAsset(assetId: number, limit: number = 10): Promise<DayTradingPair[]> {
    const trades = await RdbHelper.queryTradesByAssetId(assetId);
    const dayTradingTrades = trades.filter(t => t.type === TradeType.T_BUY || t.type === TradeType.T_SELL);
    
    const pairs = await DayTradingService.pairDayTradingTrades(dayTradingTrades);
    return pairs.slice(0, limit);
  }

  static async getTodayDayTradingPairs(): Promise<DayTradingPair[]> {
    const today = new Date().toISOString().split('T')[0];
    return await DayTradingService.getDayTradingPairsByDate(today);
  }

  static async getDayTradingSummary(startTime: number, endTime: number): Promise<DayTradingSummary> {
    const trades = await RdbHelper.queryTradesByDateRange(startTime, endTime);
    const dayTradingTrades = trades.filter(t => t.type === TradeType.T_BUY || t.type === TradeType.T_SELL);
    
    const pairs = await DayTradingService.pairDayTradingTrades(dayTradingTrades);
    
    if (pairs.length === 0) {
      const emptyResult: DayTradingSummary = {
        totalProfit: 0,
        totalTrades: 0,
        winRate: 0,
        avgProfit: 0,
        maxProfit: 0,
        maxLoss: 0
      };
      return emptyResult;
    }
    
    const totalProfit = pairs.reduce((sum, p) => sum + p.profit, 0);
    const winCount = pairs.filter(p => p.profit > 0).length;
    const winRate = (winCount / pairs.length) * 100;
    const avgProfit = totalProfit / pairs.length;
    const maxProfit = Math.max(...pairs.map(p => p.profit));
    const maxLoss = Math.min(...pairs.map(p => p.profit));
    
    const summaryResult: DayTradingSummary = {
      totalProfit,
      totalTrades: pairs.length,
      winRate,
      avgProfit,
      maxProfit,
      maxLoss
    };
    return summaryResult;
  }

  static async calculateDayTradingProfit(trades: TradeRecord[]): Promise<number> {
    const pairs = await DayTradingService.pairDayTradingTrades(trades);
    return pairs.reduce((sum, p) => sum + p.profit, 0);
  }

  static async pairDayTradingTrades(trades: TradeRecord[]): Promise<DayTradingPair[]> {
    const sellTrades = trades.filter(t => t.type === TradeType.T_SELL);
    const buyTrades = trades.filter(t => t.type === TradeType.T_BUY);
    const pairs: DayTradingPair[] = [];
    
    const assetSellTrades: Map<number, TradeRecord[]> = new Map();
    const assetBuyTrades: Map<number, TradeRecord[]> = new Map();
    
    for (const trade of sellTrades) {
      if (!assetSellTrades.has(trade.assetId)) {
        assetSellTrades.set(trade.assetId, []);
      }
      assetSellTrades.get(trade.assetId)!.push(trade);
    }
    
    for (const trade of buyTrades) {
      if (!assetBuyTrades.has(trade.assetId)) {
        assetBuyTrades.set(trade.assetId, []);
      }
      assetBuyTrades.get(trade.assetId)!.push(trade);
    }
    
    for (const assetId of assetSellTrades.keys()) {
      const sells = assetSellTrades.get(assetId) || [];
      const buys = assetBuyTrades.get(assetId) || [];
      
      sells.sort((a, b) => a.tradeTime - b.tradeTime);
      buys.sort((a, b) => a.tradeTime - b.tradeTime);
      
      const minLen = Math.min(sells.length, buys.length);
      for (let i = 0; i < minLen; i++) {
        const pair = await DayTradingService.createDayTradingPair(sells[i], buys[i]);
        pairs.push(pair);
      }
    }
    
    return pairs.sort((a, b) => b.sellTrade.tradeTime - a.sellTrade.tradeTime);
  }

  static async getDayTradingProfitByDate(date: string): Promise<number> {
    const pairs = await DayTradingService.getDayTradingPairsByDate(date);
    return pairs.reduce((sum, p) => sum + p.profit, 0);
  }

  static async getRecentDayTradingPairs(limit: number = 20): Promise<DayTradingPair[]> {
    const now = Date.now();
    const startTime = now - 30 * 24 * 60 * 60 * 1000;
    
    const trades = await RdbHelper.queryTradesByDateRange(startTime, now);
    const dayTradingTrades = trades.filter(t => t.type === TradeType.T_BUY || t.type === TradeType.T_SELL);
    
    const pairs = await DayTradingService.pairDayTradingTrades(dayTradingTrades);
    return pairs.slice(0, limit);
  }

  static getProfitColor(profit: number): string {
    if (profit > 0) {
      return '#FF5722';
    } else if (profit < 0) {
      return '#4CAF50';
    }
    return '#9E9E9E';
  }

  static formatProfit(profit: number): string {
    const sign = profit >= 0 ? '+' : '';
    return `${sign}${profit.toFixed(2)}`;
  }
}