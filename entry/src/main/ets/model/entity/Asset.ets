import { AssetType } from '../../common/constants/Constants';
import { relationalStore } from '@kit.ArkData';

export class Asset {
  id: number = 0;
  type: AssetType = AssetType.FUND;
  code: string = '';
  name: string = '';
  costPrice: number = 0;
  currentPrice: number = 0;
  quantity: number = 0;
  marketValue: number = 0;
  profitLossRatio: number = 0;
  createTime: number = Date.now();
  updateTime: number = Date.now();

  static getCreateSql(): string {
    return `CREATE TABLE IF NOT EXISTS asset (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      costPrice REAL NOT NULL DEFAULT 0,
      currentPrice REAL NOT NULL DEFAULT 0,
      quantity REAL NOT NULL DEFAULT 0,
      marketValue REAL NOT NULL DEFAULT 0,
      profitLossRatio REAL NOT NULL DEFAULT 0,
      createTime INTEGER NOT NULL,
      updateTime INTEGER NOT NULL
    )`;
  }

  static toValues(asset: Asset): relationalStore.ValuesBucket {
    return {
      type: asset.type,
      code: asset.code,
      name: asset.name,
      costPrice: asset.costPrice,
      currentPrice: asset.currentPrice,
      quantity: asset.quantity,
      marketValue: asset.marketValue,
      profitLossRatio: asset.profitLossRatio,
      createTime: asset.createTime,
      updateTime: asset.updateTime
    };
  }

  static fromResultSet(resultSet: relationalStore.ResultSet): Asset {
    const asset = new Asset();
    asset.id = resultSet.goToFirstRow() ? resultSet.getLong(resultSet.getColumnIndex('id')) : 0;
    asset.type = resultSet.getString(resultSet.getColumnIndex('type')) as AssetType;
    asset.code = resultSet.getString(resultSet.getColumnIndex('code'));
    asset.name = resultSet.getString(resultSet.getColumnIndex('name'));
    asset.costPrice = resultSet.getDouble(resultSet.getColumnIndex('costPrice'));
    asset.currentPrice = resultSet.getDouble(resultSet.getColumnIndex('currentPrice'));
    asset.quantity = resultSet.getDouble(resultSet.getColumnIndex('quantity'));
    asset.marketValue = resultSet.getDouble(resultSet.getColumnIndex('marketValue'));
    asset.profitLossRatio = resultSet.getDouble(resultSet.getColumnIndex('profitLossRatio'));
    asset.createTime = resultSet.getLong(resultSet.getColumnIndex('createTime'));
    asset.updateTime = resultSet.getLong(resultSet.getColumnIndex('updateTime'));
    return asset;
  }
}