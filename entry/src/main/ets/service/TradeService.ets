import { TradeRecord } from '../model/entity/TradeRecord';
import { TradeType } from '../common/constants/Constants';
import { RdbHelper } from '../database/RdbHelper';
import { AssetService } from './AssetService';
import { AssetType } from '../common/constants/Constants';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TradeService';
const DOMAIN = 0x0000;

export interface ParsedTrade {
  type: TradeType;
  assetName: string;
  quantity: number;
  price: number;
  fee: number;
  tradeTime: number;
  remark: string;
}

export interface DayTradingResult {
  buyId: number;
  sellId: number;
}

export class TradeService {
  static async addTrade(trade: ParsedTrade): Promise<number> {
    let asset = await AssetService.findAssetByCode(trade.assetName);
    
    if (!asset) {
      const assetId = await AssetService.createAsset(
        AssetType.STOCK,
        trade.assetName,
        trade.assetName,
        trade.price,
        0
      );
      asset = await AssetService.getAssetById(assetId);
    }

    if (!asset) {
      throw new Error('Failed to create or find asset');
    }

    const tradeRecord = new TradeRecord();
    tradeRecord.type = trade.type;
    tradeRecord.assetId = asset.id;
    tradeRecord.assetCode = asset.code;
    tradeRecord.assetName = asset.name;
    tradeRecord.quantity = trade.quantity;
    tradeRecord.price = trade.price;
    tradeRecord.fee = trade.fee;
    tradeRecord.tradeTime = trade.tradeTime;
    tradeRecord.remark = trade.remark;

    await RdbHelper.executeTransaction(async () => {
      await RdbHelper.insertTrade(tradeRecord);
      
      if (asset) {
        switch (trade.type) {
          case TradeType.BUY:
            await AssetService.updateAssetQuantity(asset.id, trade.quantity, trade.price);
            break;
          case TradeType.SELL:
            await AssetService.updateAssetQuantity(asset.id, -trade.quantity);
            break;
          case TradeType.T_BUY:
          case TradeType.T_SELL:
            break;
        }
        
        await AssetService.updateAssetPrice(asset.id, trade.price);
      }
    });

    hilog.info(DOMAIN, TAG, 'Trade added: %{public}s', asset.name);
    return tradeRecord.id;
  }

  static async addDayTrading(buyTrade: ParsedTrade, sellTrade: ParsedTrade): Promise<DayTradingResult> {
    let asset = await AssetService.findAssetByCode(buyTrade.assetName);
    
    if (!asset) {
      const assetId = await AssetService.createAsset(
        AssetType.STOCK,
        buyTrade.assetName,
        buyTrade.assetName,
        buyTrade.price,
        0
      );
      asset = await AssetService.getAssetById(assetId);
    }

    if (!asset) {
      throw new Error('Failed to create or find asset');
    }

    const sellRecord = new TradeRecord();
    sellRecord.type = TradeType.T_SELL;
    sellRecord.assetId = asset.id;
    sellRecord.assetCode = asset.code;
    sellRecord.assetName = asset.name;
    sellRecord.quantity = sellTrade.quantity;
    sellRecord.price = sellTrade.price;
    sellRecord.fee = sellTrade.fee;
    sellRecord.tradeTime = sellTrade.tradeTime;
    sellRecord.remark = sellTrade.remark;

    const buyRecord = new TradeRecord();
    buyRecord.type = TradeType.T_BUY;
    buyRecord.assetId = asset.id;
    buyRecord.assetCode = asset.code;
    buyRecord.assetName = asset.name;
    buyRecord.quantity = buyTrade.quantity;
    buyRecord.price = buyTrade.price;
    buyRecord.fee = buyTrade.fee;
    buyRecord.tradeTime = buyTrade.tradeTime;
    buyRecord.remark = buyTrade.remark;

    await RdbHelper.executeTransaction(async () => {
      await RdbHelper.insertTrade(sellRecord);
      await RdbHelper.insertTrade(buyRecord);
      if (asset) {
        await AssetService.updateAssetPrice(asset.id, buyTrade.price);
      }
    });

    const result: DayTradingResult = { buyId: buyRecord.id, sellId: sellRecord.id };
    return result;
  }

  static async calculateDayTradingProfit(startTime: number, endTime: number): Promise<number> {
    const trades = await RdbHelper.queryTradesByDateRange(startTime, endTime);
    const dayTradingTrades = trades.filter(t => t.type === TradeType.T_BUY || t.type === TradeType.T_SELL);
    
    let totalProfit = 0;
    const buyTrades: Map<number, TradeRecord[]> = new Map();
    const sellTrades: Map<number, TradeRecord[]> = new Map();
    
    for (const trade of dayTradingTrades) {
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

  static async getTradesByAssetId(assetId: number): Promise<TradeRecord[]> {
    return await RdbHelper.queryTradesByAssetId(assetId);
  }
}