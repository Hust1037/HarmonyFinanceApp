import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DB_NAME, DB_VERSION } from '../common/constants/Constants';
import { Asset } from '../model/entity/Asset';
import { TradeRecord } from '../model/entity/TradeRecord';
import { DailyValuation } from '../model/entity/DailyValuation';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RdbHelper } from './RdbHelper';

const TAG = 'RdbManager';
const DOMAIN = 0x0000;

export class RdbManager {
  private static instance: RdbManager;
  private rdbStore: relationalStore.RdbStore | null = null;

  private constructor() {}

  static getInstance(): RdbManager {
    if (!RdbManager.instance) {
      RdbManager.instance = new RdbManager();
    }
    return RdbManager.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.rdbStore) {
      return;
    }

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    try {
      this.rdbStore = await relationalStore.getRdbStore(context, config);
      await this.createTables();
      RdbHelper.setRdbStore(this.rdbStore);
      hilog.info(DOMAIN, TAG, 'Database initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize database: %{public}s', JSON.stringify(err));
      throw new Error(JSON.stringify(err));
    }
  }

  private async createTables(): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('RdbStore not initialized');
    }

    await this.rdbStore.executeSql(Asset.getCreateSql());
    await this.rdbStore.executeSql(TradeRecord.getCreateSql());
    await this.rdbStore.executeSql(DailyValuation.getCreateSql());

    await this.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_trade_time ON trade_record(tradeTime)');
    await this.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_valuation_date ON daily_valuation(date)');
    await this.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_valuation_asset ON daily_valuation(assetId)');
  }

  getRdbStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('RdbStore not initialized. Call init() first.');
    }
    return this.rdbStore;
  }
}