import { Asset } from '../model/entity/Asset';
import { TradeRecord } from '../model/entity/TradeRecord';
import { DailyValuation } from '../model/entity/DailyValuation';
import { RdbHelper } from '../database/RdbHelper';
import { TradeType, TimeRange } from '../common/constants/Constants';

export interface AssetSummary {
  totalValue: number;
  totalProfit: number;
  totalProfitRatio: number;
  stockValue: number;
  stockProfit: number;
  fundValue: number;
  fundProfit: number;
}

export interface ProfitSummary {
  date: string;
  profit: number;
  profitRatio: number;
}

export interface ProfitMapValue {
  profit: number;
  cost: number;
}

export interface DayTradingSummaryResult {
  totalProfit: number;
  tradeCount: number;
}

export class StatisticsService {
  static async getAssetSummary(): Promise<AssetSummary> {
    const assets = await RdbHelper.queryAllAssets();
    
    let totalValue = 0;
    let totalCost = 0;
    let stockValue = 0;
    let stockCost = 0;
    let fundValue = 0;
    let fundCost = 0;
    
    for (const asset of assets) {
      const cost = asset.costPrice * asset.quantity;
      totalValue += asset.marketValue;
      totalCost += cost;
      
      if (asset.type === 'STOCK') {
        stockValue += asset.marketValue;
        stockCost += cost;
      } else {
        fundValue += asset.marketValue;
        fundCost += cost;
      }
    }
    
    const totalProfit = totalValue - totalCost;
    const totalProfitRatio = totalCost > 0 ? (totalProfit / totalCost) * 100 : 0;
    const stockProfit = stockValue - stockCost;
    const fundProfit = fundValue - fundCost;
    
    const summaryResult: AssetSummary = {
      totalValue,
      totalProfit,
      totalProfitRatio,
      stockValue,
      stockProfit,
      fundValue,
      fundProfit
    };
    return summaryResult;
  }

  static async getProfitHistory(timeRange: TimeRange): Promise<ProfitSummary[]> {
    const now = new Date();
    let startDate = new Date();
    
    switch (timeRange) {
      case TimeRange.WEEK:
        startDate.setDate(now.getDate() - 7);
        break;
      case TimeRange.MONTH:
        startDate.setMonth(now.getMonth() - 1);
        break;
      case TimeRange.QUARTER:
        startDate.setMonth(now.getMonth() - 3);
        break;
      case TimeRange.YEAR:
        startDate.setFullYear(now.getFullYear() - 1);
        break;
    }
    
    const trades = await RdbHelper.queryTradesByDateRange(startDate.getTime(), now.getTime());
    const profitMap: Map<string, ProfitMapValue> = new Map();
    
    for (const trade of trades) {
      const date = new Date(trade.tradeTime).toISOString().split('T')[0];
      if (!profitMap.has(date)) {
        const newValue: ProfitMapValue = { profit: 0, cost: 0 };
        profitMap.set(date, newValue);
      }
      
      const summary = profitMap.get(date)!;
      if (trade.type === TradeType.BUY || trade.type === TradeType.T_BUY) {
        summary.cost += trade.price * trade.quantity + trade.fee;
      } else if (trade.type === TradeType.SELL || trade.type === TradeType.T_SELL) {
        summary.profit += trade.price * trade.quantity - trade.fee;
      }
    }
    
    const summaries: ProfitSummary[] = [];
    profitMap.forEach((value, date) => {
      summaries.push({
        date,
        profit: value.profit - value.cost,
        profitRatio: value.cost > 0 ? ((value.profit - value.cost) / value.cost) * 100 : 0
      });
    });
    
    return summaries.sort((a, b) => a.date.localeCompare(b.date));
  }

  static async getTopProfitAssets(limit: number = 5): Promise<Asset[]> {
    const assets = await RdbHelper.queryAllAssets();
    return assets
      .filter(a => a.quantity > 0)
      .sort((a, b) => b.profitLossRatio - a.profitLossRatio)
      .slice(0, limit);
  }

  static async getTopLossAssets(limit: number = 5): Promise<Asset[]> {
    const assets = await RdbHelper.queryAllAssets();
    return assets
      .filter(a => a.quantity > 0)
      .sort((a, b) => a.profitLossRatio - b.profitLossRatio)
      .slice(0, limit);
  }

  static async getDayTradingSummary(startTime: number, endTime: number): Promise<DayTradingSummaryResult> {
    const trades = await RdbHelper.queryTradesByDateRange(startTime, endTime);
    const dayTradingTrades = trades.filter(t => t.type === TradeType.T_BUY || t.type === TradeType.T_SELL);
    
    const tradeCount = dayTradingTrades.length / 2;
    const totalProfit = await StatisticsService.calculateDayTradingProfit(dayTradingTrades);
    
    const result: DayTradingSummaryResult = { totalProfit, tradeCount };
    return result;
  }

  private static async calculateDayTradingProfit(trades: TradeRecord[]): Promise<number> {
    let totalProfit = 0;
    const buyTrades: Map<number, TradeRecord[]> = new Map();
    const sellTrades: Map<number, TradeRecord[]> = new Map();
    
    for (const trade of trades) {
      if (trade.type === TradeType.T_BUY) {
        if (!buyTrades.has(trade.assetId)) {
          buyTrades.set(trade.assetId, []);
        }
        buyTrades.get(trade.assetId)!.push(trade);
      } else {
        if (!sellTrades.has(trade.assetId)) {
          sellTrades.set(trade.assetId, []);
        }
        sellTrades.get(trade.assetId)!.push(trade);
      }
    }

    for (const assetId of buyTrades.keys()) {
      const assetBuys = buyTrades.get(assetId) || [];
      const assetSells = sellTrades.get(assetId) || [];
      
      const totalSellAmount = assetSells.reduce((sum, t) => sum + t.price * t.quantity - t.fee, 0);
      const totalBuyAmount = assetBuys.reduce((sum, t) => sum + t.price * t.quantity + t.fee, 0);
      
      totalProfit += totalSellAmount - totalBuyAmount;
    }

    return totalProfit;
  }
}