import { TradeType } from '../../common/constants/Constants';
import { relationalStore } from '@kit.ArkData';

export class TradeRecord {
  id: number = 0;
  type: TradeType = TradeType.BUY;
  assetId: number = 0;
  assetCode: string = '';
  assetName: string = '';
  quantity: number = 0;
  price: number = 0;
  fee: number = 0;
  tradeTime: number = Date.now();
  remark: string = '';
  createTime: number = Date.now();

  static getCreateSql(): string {
    return `CREATE TABLE IF NOT EXISTS trade_record (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      assetId INTEGER NOT NULL,
      assetCode TEXT NOT NULL,
      assetName TEXT NOT NULL,
      quantity REAL NOT NULL DEFAULT 0,
      price REAL NOT NULL DEFAULT 0,
      fee REAL NOT NULL DEFAULT 0,
      tradeTime INTEGER NOT NULL,
      remark TEXT,
      createTime INTEGER NOT NULL
    )`;
  }

  static toValues(trade: TradeRecord): relationalStore.ValuesBucket {
    return {
      type: trade.type,
      assetId: trade.assetId,
      assetCode: trade.assetCode,
      assetName: trade.assetName,
      quantity: trade.quantity,
      price: trade.price,
      fee: trade.fee,
      tradeTime: trade.tradeTime,
      remark: trade.remark,
      createTime: trade.createTime
    };
  }

  static fromResultSet(resultSet: relationalStore.ResultSet): TradeRecord {
    const trade = new TradeRecord();
    trade.id = resultSet.getLong(resultSet.getColumnIndex('id'));
    trade.type = resultSet.getString(resultSet.getColumnIndex('type')) as TradeType;
    trade.assetId = resultSet.getLong(resultSet.getColumnIndex('assetId'));
    trade.assetCode = resultSet.getString(resultSet.getColumnIndex('assetCode'));
    trade.assetName = resultSet.getString(resultSet.getColumnIndex('assetName'));
    trade.quantity = resultSet.getDouble(resultSet.getColumnIndex('quantity'));
    trade.price = resultSet.getDouble(resultSet.getColumnIndex('price'));
    trade.fee = resultSet.getDouble(resultSet.getColumnIndex('fee'));
    trade.tradeTime = resultSet.getLong(resultSet.getColumnIndex('tradeTime'));
    trade.remark = resultSet.getString(resultSet.getColumnIndex('remark'));
    trade.createTime = resultSet.getLong(resultSet.getColumnIndex('createTime'));
    return trade;
  }
}