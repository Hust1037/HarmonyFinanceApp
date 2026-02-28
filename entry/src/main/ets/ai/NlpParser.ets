import { TradeType } from '../common/constants/Constants';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'NlpParser';
const DOMAIN = 0x0000;

export interface TradeInfo {
  type: TradeType;
  assetName: string;
  quantity: number;
  price: number;
  fee: number;
  time: Date;
}

export interface ParseResult {
  success: boolean;
  type: TradeType | 'DAY_TRADING';
  trades: TradeInfo[];
  errorMessage?: string;
}

export class NlpParser {
  private static timePatterns = [
    /(\d{1,2})点(\d{1,2})/,
    /(\d{1,2})[:：](\d{1,2})/,
    /(\d{1,2})时(\d{1,2})/
  ];

  private static datePatterns = [
    /(\d{4})年(\d{1,2})月(\d{1,2})日/,
    /(\d{1,2})月(\d{1,2})日/,
    /(\d{4})-(\d{1,2})-(\d{1,2})/,
    /(\d{4})\/(\d{1,2})\/(\d{1,2})/
  ];

  private static pricePatterns = [
    /(\d+(?:\.\d+)?)\s*元/,
    /(\d+(?:\.\d+)?)\s*块/,
    /(?:价格|价位|成交价)[:：]\s*(\d+(?:\.\d+)?)/
  ];

  private static quantityPatterns = [
    /(\d+(?:\.\d+)?)\s*股/,
    /(\d+(?:\.\d+)?)\s*份/,
    /(\d+(?:\.\d+)?)\s*手/,
    /(\d+(?:\.\d+)?)\s*(?:股|份|手)?/
  ];

  private static feePatterns = [
    /手续费\s*[:：]?\s*(\d+(?:\.\d+)?)/,
    /费用\s*[:：]?\s*(\d+(?:\.\d+)?)/,
    /佣金\s*[:：]?\s*(\d+(?:\.\d+)?)/
  ];

  static parseTradeText(text: string): ParseResult {
    hilog.info(DOMAIN, TAG, 'Parsing text: %{public}s', text);

    if (NlpParser.isDayTrading(text)) {
      return NlpParser.parseDayTrading(text);
    }

    const type = NlpParser.detectTradeType(text);
    const assetName = NlpParser.extractAssetName(text);
    
    if (!assetName) {
      const failResult: ParseResult = {
        success: false,
        type: TradeType.BUY,
        trades: [],
        errorMessage: '未能识别资产名称'
      };
      return failResult;
    }

    const quantity = NlpParser.extractQuantity(text);
    const price = NlpParser.extractPrice(text);
    const fee = NlpParser.extractFee(text) || 0;
    const time = NlpParser.extractTime(text);

    if (quantity === null || price === null) {
      const failResult: ParseResult = {
        success: false,
        type: TradeType.BUY,
        trades: [],
        errorMessage: '未能识别数量或价格'
      };
      return failResult;
    }

    const tradeInfo: TradeInfo = {
      type: type,
      assetName: assetName,
      quantity: quantity,
      price: price,
      fee: fee,
      time: time
    };
    const successResult: ParseResult = {
      success: true,
      type: type,
      trades: [tradeInfo]
    };
    return successResult;
  }

  private static isDayTrading(text: string): boolean {
    return /做T|日内|高抛低吸/.test(text);
  }

  private static detectTradeType(text: string): TradeType {
    if (/卖出|卖|抛|减仓/.test(text)) {
      return TradeType.SELL;
    }
    return TradeType.BUY;
  }

  private static extractAssetName(text: string): string | null {
    const patterns = [
      /(?:买入|卖出|持有)(?:\d+(?:\.\d+)?(?:股|份|手))?\s*([^\d,，.。元块]+?)(?:\d+|\s|$)/,
      /([^\d,，.。元块]+?)(?:\d+(?:\.\d+)?)\s*(?:股|份|手)/,
      /([A-Z]{2,}\d+)/,
      /(\d{6})/
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        const name = match[1].trim();
        if (name.length > 0 && name.length < 20) {
          return name;
        }
      }
    }

    const commonStocks = ['腾讯', '阿里', '茅台', '宁德', '比亚迪', '中芯', '美团', '京东', '拼多多', '网易'];
    for (const stock of commonStocks) {
      if (text.includes(stock)) {
        return stock;
      }
    }

    return null;
  }

  private static extractQuantity(text: string): number | null {
    for (const pattern of NlpParser.quantityPatterns) {
      const match = text.match(pattern);
      if (match) {
        const quantity = parseFloat(match[1]);
        if (!isNaN(quantity) && quantity > 0) {
          return quantity;
        }
      }
    }

    const numberPattern = /(?:\s|^)(\d{3,5})(?=\s|$|股|份|手)/;
    const match = text.match(numberPattern);
    if (match) {
      const quantity = parseFloat(match[1]);
      if (!isNaN(quantity) && quantity > 0) {
        return quantity;
      }
    }

    return null;
  }

  private static extractPrice(text: string): number | null {
    for (const pattern of NlpParser.pricePatterns) {
      const match = text.match(pattern);
      if (match) {
        const price = parseFloat(match[1]);
        if (!isNaN(price) && price > 0) {
          return price;
        }
      }
    }

    const priceContextPattern = /(?:以|价格|价位|成交价|单价)[：:]?\s*(\d+(?:\.\d+)?)/;
    const match = text.match(priceContextPattern);
    if (match) {
      const price = parseFloat(match[1]);
      if (!isNaN(price) && price > 0 && price < 10000) {
        return price;
      }
    }

    return null;
  }

  private static extractFee(text: string): number | null {
    for (const pattern of NlpParser.feePatterns) {
      const match = text.match(pattern);
      if (match) {
        const fee = parseFloat(match[1]);
        if (!isNaN(fee) && fee >= 0) {
          return fee;
        }
      }
    }
    return null;
  }

  private static extractTime(text: string): Date {
    const now = new Date();
    let targetDate = new Date();
    let hour = 9;
    let minute = 30;

    for (const pattern of NlpParser.datePatterns) {
      const match = text.match(pattern);
      if (match) {
        if (match.length === 4) {
          targetDate = new Date(parseInt(match[1]), parseInt(match[2]) - 1, parseInt(match[3]));
        } else if (match.length === 3) {
          targetDate = new Date(now.getFullYear(), parseInt(match[1]) - 1, parseInt(match[2]));
        }
        break;
      }
    }
    
    for (const pattern of NlpParser.timePatterns) {
      const match = text.match(pattern);
      if (match) {
        hour = parseInt(match[1]);
        minute = parseInt(match[2]);
        break;
      }
    }

    targetDate.setHours(hour, minute, 0, 0);
    return targetDate;
  }

  private static parseDayTrading(text: string): ParseResult {
    const trades: TradeInfo[] = [];

    const assetName = NlpParser.extractAssetName(text);
    if (!assetName) {
      const failResult: ParseResult = {
        success: false,
        type: 'DAY_TRADING',
        trades: [],
        errorMessage: '做T：未能识别资产名称'
      };
      return failResult;
    }

    const sellMatch = text.match(/(?:卖|抛|出)\s*(\d+(?:\.\d+)?)\s*(?:股|份|手).*?(\d+(?:\.\d+)?)/s);
    const buyMatch = text.match(/(?:买|入|回)\s*(\d+(?:\.\d+)?)\s*(?:股|份|手).*?(\d+(?:\.\d+)?)/s);

    if (!sellMatch || !buyMatch) {
      const failResult: ParseResult = {
        success: false,
        type: 'DAY_TRADING',
        trades: [],
        errorMessage: '做T：未能识别买卖信息'
      };
      return failResult;
    }

    const sellTime = NlpParser.extractTime(text);
    const buyTime = new Date(sellTime);
    buyTime.setHours(12, 0, 0, 0);

    const sellTrade: TradeInfo = {
      type: TradeType.T_SELL,
      assetName: assetName,
      quantity: parseFloat(sellMatch[1]),
      price: parseFloat(sellMatch[2]),
      fee: NlpParser.extractFee(text) || 0,
      time: sellTime
    };
    trades.push(sellTrade);

    const buyTrade: TradeInfo = {
      type: TradeType.T_BUY,
      assetName: assetName,
      quantity: parseFloat(buyMatch[1]),
      price: parseFloat(buyMatch[2]),
      fee: NlpParser.extractFee(text) || 0,
      time: buyTime
    };
    trades.push(buyTrade);

    const successResult: ParseResult = {
      success: true,
      type: 'DAY_TRADING',
      trades: trades
    };
    return successResult;
  }

  static normalizeText(text: string): string {
    return text
      .replace(/[，。；;！!？?]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }
}