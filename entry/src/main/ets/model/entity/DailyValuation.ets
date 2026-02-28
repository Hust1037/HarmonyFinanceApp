import { relationalStore } from '@kit.ArkData';

export class DailyValuation {
  id: number = 0;
  date: string = '';
  assetId: number = 0;
  assetCode: string = '';
  price: number = 0;
  changePercent: number = 0;
  createTime: number = Date.now();

  static getCreateSql(): string {
    return `CREATE TABLE IF NOT EXISTS daily_valuation (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      assetId INTEGER NOT NULL,
      assetCode TEXT NOT NULL,
      price REAL NOT NULL DEFAULT 0,
      changePercent REAL NOT NULL DEFAULT 0,
      createTime INTEGER NOT NULL,
      UNIQUE(date, assetId)
    )`;
  }

  static toValues(valuation: DailyValuation): relationalStore.ValuesBucket {
    return {
      date: valuation.date,
      assetId: valuation.assetId,
      assetCode: valuation.assetCode,
      price: valuation.price,
      changePercent: valuation.changePercent,
      createTime: valuation.createTime
    };
  }

  static fromResultSet(resultSet: relationalStore.ResultSet): DailyValuation {
    const valuation = new DailyValuation();
    valuation.id = resultSet.getLong(resultSet.getColumnIndex('id'));
    valuation.date = resultSet.getString(resultSet.getColumnIndex('date'));
    valuation.assetId = resultSet.getLong(resultSet.getColumnIndex('assetId'));
    valuation.assetCode = resultSet.getString(resultSet.getColumnIndex('assetCode'));
    valuation.price = resultSet.getDouble(resultSet.getColumnIndex('price'));
    valuation.changePercent = resultSet.getDouble(resultSet.getColumnIndex('changePercent'));
    valuation.createTime = resultSet.getLong(resultSet.getColumnIndex('createTime'));
    return valuation;
  }
}