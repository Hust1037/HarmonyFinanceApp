import { relationalStore } from '@kit.ArkData';
import { Asset } from '../model/entity/Asset';
import { TradeRecord } from '../model/entity/TradeRecord';
import { DailyValuation } from '../model/entity/DailyValuation';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'RdbHelper';
const DOMAIN = 0x0000;

export class RdbHelper {
  private static rdbStoreInstance: relationalStore.RdbStore | null = null;

  static setRdbStore(store: relationalStore.RdbStore): void {
    RdbHelper.rdbStoreInstance = store;
  }

  static async insertAsset(asset: Asset): Promise<number> {
    const store = RdbHelper.getStore();
    const values = Asset.toValues(asset);
    return await store.insert('asset', values);
  }

  static async updateAsset(asset: Asset): Promise<number> {
    const store = RdbHelper.getStore();
    const values = Asset.toValues(asset);
    const predicates = new relationalStore.RdbPredicates('asset');
    predicates.equalTo('id', asset.id);
    return await store.update(values, predicates);
  }

  static async queryAssetById(id: number): Promise<Asset | null> {
    const store = RdbHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('asset');
    predicates.equalTo('id', id);
    const resultSet = await store.query(predicates);
    if (resultSet.goToFirstRow()) {
      return Asset.fromResultSet(resultSet);
    }
    resultSet.close();
    return null;
  }

  static async queryAllAssets(): Promise<Asset[]> {
    const store = RdbHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('asset');
    const resultSet = await store.query(predicates);
    const assets: Asset[] = [];
    while (resultSet.goToNextRow()) {
      assets.push(Asset.fromResultSet(resultSet));
    }
    resultSet.close();
    return assets;
  }

  static async insertTrade(trade: TradeRecord): Promise<number> {
    const store = RdbHelper.getStore();
    const values = TradeRecord.toValues(trade);
    return await store.insert('trade_record', values);
  }

  static async queryTradesByAssetId(assetId: number): Promise<TradeRecord[]> {
    const store = RdbHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('trade_record');
    predicates.equalTo('assetId', assetId).orderByDesc('tradeTime');
    const resultSet = await store.query(predicates);
    const trades: TradeRecord[] = [];
    while (resultSet.goToNextRow()) {
      trades.push(TradeRecord.fromResultSet(resultSet));
    }
    resultSet.close();
    return trades;
  }

  static async queryTradesByDateRange(startTime: number, endTime: number): Promise<TradeRecord[]> {
    const store = RdbHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('trade_record');
    predicates.between('tradeTime', startTime, endTime).orderByDesc('tradeTime');
    const resultSet = await store.query(predicates);
    const trades: TradeRecord[] = [];
    while (resultSet.goToNextRow()) {
      trades.push(TradeRecord.fromResultSet(resultSet));
    }
    resultSet.close();
    return trades;
  }

  static async insertValuation(valuation: DailyValuation): Promise<number> {
    const store = RdbHelper.getStore();
    const values = DailyValuation.toValues(valuation);
    return await store.insert('daily_valuation', values);
  }

  static async queryValuationsByAssetId(assetId: number, limit: number = 30): Promise<DailyValuation[]> {
    const store = RdbHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('daily_valuation');
    predicates.equalTo('assetId', assetId).orderByDesc('date').limitAs(limit);
    const resultSet = await store.query(predicates);
    const valuations: DailyValuation[] = [];
    while (resultSet.goToNextRow()) {
      valuations.push(DailyValuation.fromResultSet(resultSet));
    }
    resultSet.close();
    return valuations.reverse();
  }

  static async executeTransaction(operations: () => Promise<void>): Promise<void> {
    const store = RdbHelper.getStore();
    try {
      await store.beginTransaction();
      await operations();
      await store.commit();
    } catch (err) {
      await store.rollBack();
      hilog.error(DOMAIN, TAG, 'Transaction failed: %{public}s', JSON.stringify(err));
      throw new Error(JSON.stringify(err));
    }
  }

  private static getStore(): relationalStore.RdbStore {
    if (!RdbHelper.rdbStoreInstance) {
      throw new Error('RdbStore not initialized. Call RdbManager.getInstance().init() first.');
    }
    return RdbHelper.rdbStoreInstance;
  }
}