# 鸿蒙个人理财 App 架构设计文档

## 1. 项目概述

### 1.1 项目简介
本项目是一款运行在 HarmonyOS（鸿蒙系统）上的个人理财记录应用，使用 ArkTS + Stage 模型开发。核心目标是帮助用户手动或半自动记录基金、股票的每日涨跌与交易操作（含做T），并支持持仓分析、截图识别、自然语言修正持仓。

### 1.2 核心功能
- 资产管理：基金、股票等金融资产的创建、更新、删除
- 交易记录：买入、卖出、做T（日内高抛低吸）等交易操作
- 持仓分析：实时持仓价值、盈亏比例、收益率统计
- 截图识别：通过OCR技术识别交易截图中的关键信息
- 自然语言处理：解析自然语言交易指令，自动生成交易记录
- 统计报表：按时间维度统计交易收益、做T收益等

## 2. 技术栈

### 2.1 开发框架
- **开发语言**: ArkTS (TypeScript的超集)
- **应用模型**: Stage模型
- **API版本**: API 10+
- **构建工具**: Hvigor

### 2.2 核心依赖
- **数据存储**: @kit.ArkData (关系型数据库)
- **OCR识别**: @kit.CoreVisionKit (文本识别)
- **日志系统**: @kit.PerformanceAnalysisKit (hilog)
- **图像处理**: @kit.ImageKit (PixelMap处理)

### 2.3 系统权限
- `ohos.permission.READ_IMAGEVIDEO`: 读取图片/视频权限（用于OCR识别）
- `ohos.permission.INTERNET`: 网络权限（预留扩展功能）

## 3. 架构设计

### 3.1 整体架构
采用**三层架构**设计模式：

```
┌─────────────────────────────────────────────────────────┐
│                     UI层 (Presentation)                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │HomePage  │ │RecordPage│ │Analysis  │ │OcrPage   │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   业务逻辑层 (Business)                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │Asset     │ │Trade     │ │DayTrading│ │Statistics│   │
│  │Service   │ │Service   │ │Service   │ │Service   │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   数据访问层 (Data)                       │
│  ┌──────────┐ ┌──────────┐                               │
│  │RdbHelper │ │RdbManager│                               │
│  └──────────┘ └──────────┘                               │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   智能处理层 (AI)                         │
│  ┌──────────┐ ┌──────────┐                               │
│  │OcrService│ │NlpParser │                               │
│  └──────────┘ └──────────┘                               │
└─────────────────────────────────────────────────────────┘
```

### 3.2 架构特点
- **分层清晰**: UI层、业务层、数据层职责明确
- **高内聚低耦合**: 各层通过接口通信，降低依赖
- **静态方法设计**: 所有Service类采用静态方法，便于调用
- **类型安全**: 使用ArkTS强类型系统，确保代码质量

## 4. 模块划分

### 4.1 目录结构
```
entry/src/main/ets/
├── ai/                    # 智能处理层
│   ├── OcrService.ets    # OCR文本识别服务
│   └── NlpParser.ets     # 自然语言解析器
├── common/                # 公共模块
│   └── constants/
│       └── Constants.ets  # 常量定义
├── database/              # 数据访问层
│   ├── RdbHelper.ets     # 关系型数据库辅助类
│   └── RdbManager.ets    # 数据库管理器
├── model/                 # 数据模型层
│   └── entity/
│       ├── Asset.ets             # 资产实体
│       ├── TradeRecord.ets       # 交易记录实体
│       └── DailyValuation.ets    # 每日估值实体
├── pages/                 # UI页面层
│   ├── Index.ets         # 首页入口
│   ├── HomePage.ets      # 主页面
│   ├── RecordPage.ets    # 记录页面
│   ├── AnalysisPage.ets  # 分析页面
│   └── OcrPage.ets       # OCR识别页面
├── service/               # 业务逻辑层
│   ├── AssetService.ets         # 资产服务
│   ├── TradeService.ets         # 交易服务
│   ├── DayTradingService.ets    # 做T服务
│   └── StatisticsService.ets    # 统计服务
├── entryability/          # 应用入口
│   └── EntryAbility.ets  # 应用能力类
└── entrybackupability/    # 备份能力
    └── EntryBackupAbility.ets
```

## 5. 数据模型

### 5.1 核心实体

#### 5.1.1 Asset (资产)
```typescript
class Asset {
  id: number;              // 资产ID
  type: AssetType;         // 资产类型 (FUND/STOCK)
  code: string;            // 资产代码
  name: string;            // 资产名称
  costPrice: number;       // 成本价
  currentPrice: number;    // 当前价
  quantity: number;        // 持仓数量
  marketValue: number;     // 市值
  profitLossRatio: number; // 盈亏比例
  createTime: number;      // 创建时间
  updateTime: number;      // 更新时间
}
```

#### 5.1.2 TradeRecord (交易记录)
```typescript
class TradeRecord {
  id: number;              // 交易ID
  type: TradeType;         // 交易类型 (BUY/SELL/T_BUY/T_SELL)
  assetId: number;         // 资产ID
  assetCode: string;       // 资产代码
  assetName: string;       // 资产名称
  quantity: number;        // 交易数量
  price: number;           // 交易价格
  fee: number;             // 手续费
  tradeTime: number;       // 交易时间
  remark: string;          // 备注
}
```

#### 5.1.3 DailyValuation (每日估值)
```typescript
class DailyValuation {
  id: number;              // 估值ID
  date: number;            // 日期
  totalAssets: number;     // 总资产
  totalProfit: number;     // 总盈亏
  profitRatio: number;     // 盈亏比例
  dayTradingProfit: number; // 做T收益
}
```

### 5.2 枚举类型

#### 5.2.1 AssetType (资产类型)
```typescript
enum AssetType {
  FUND = 'FUND',    // 基金
  STOCK = 'STOCK'   // 股票
}
```

#### 5.2.2 TradeType (交易类型)
```typescript
enum TradeType {
  BUY = 'BUY',      // 买入
  SELL = 'SELL',    // 卖出
  T_BUY = 'T_BUY',  // 做T买入
  T_SELL = 'T_SELL' // 做T卖出
}
```

#### 5.2.3 TimeRange (时间范围)
```typescript
enum TimeRange {
  WEEK = 'WEEK',      // 周
  MONTH = 'MONTH',    // 月
  QUARTER = 'QUARTER', // 季度
  YEAR = 'YEAR'       // 年
}
```

## 6. 服务层设计

### 6.1 AssetService (资产服务)

#### 6.1.1 核心功能
- 资产创建、查询、更新、删除
- 资产价格更新
- 资产数量更新
- 总资产计算

#### 6.1.2 主要方法
```typescript
class AssetService {
  // 创建资产
  static async createAsset(type, code, name, costPrice, quantity): Promise<number>
  
  // 更新资产价格
  static async updateAssetPrice(assetId, currentPrice): Promise<void>
  
  // 更新资产数量
  static async updateAssetQuantity(assetId, deltaQuantity, newCostPrice?): Promise<void>
  
  // 查询所有资产
  static async getAllAssets(): Promise<Asset[]>
  
  // 根据代码查询资产
  static async findAssetByCode(code): Promise<Asset | undefined>
  
  // 计算总资产
  static async calculateTotalAssets(): Promise<TotalAssetsResult>
}
```

### 6.2 TradeService (交易服务)

#### 6.2.1 核心功能
- 交易记录的增删改查
- 交易类型处理（买入、卖出、做T）
- 做T收益计算

#### 6.2.2 主要方法
```typescript
class TradeService {
  // 添加交易
  static async addTrade(trade): Promise<number>
  
  // 添加做T交易
  static async addDayTrading(buyTrade, sellTrade): Promise<DayTradingResult>
  
  // 查询交易记录
  static async getTradesByAsset(assetId): Promise<TradeRecord[]>
  
  // 计算做T收益
  static async calculateDayTradingProfit(startTime, endTime): Promise<number>
}
```

### 6.3 DayTradingService (做T服务)

#### 6.3.1 核心功能
- 做T交易配对
- 做T收益计算
- 做T统计分析

#### 6.3.2 主要方法
```typescript
class DayTradingService {
  // 配对做T交易
  static async pairDayTradingTrades(trades): Promise<DayTradingPair[]>
  
  // 获取指定日期的做T交易对
  static async getDayTradingPairsByDate(date): Promise<DayTradingPair[]>
  
  // 获取指定资产的做T交易对
  static async getDayTradingPairsByAsset(assetId): Promise<DayTradingPair[]>
  
  // 获取今日做T交易对
  static async getTodayDayTradingPairs(): Promise<DayTradingPair[]>
  
  // 计算做T收益
  static async calculateDayTradingProfit(trades): Promise<number>
  
  // 获取做T汇总
  static async getDayTradingSummary(startTime, endTime): Promise<DayTradingSummaryResult>
}
```

### 6.4 StatisticsService (统计服务)

#### 6.4.1 核心功能
- 收益统计
- 交易统计
- 时间维度分析

#### 6.4.2 主要方法
```typescript
class StatisticsService {
  // 获取收益汇总
  static async getProfitSummary(startTime, endTime): Promise<ProfitSummaryResult>
  
  // 获取交易统计
  static async getTradeStatistics(startTime, endTime): Promise<TradeStatisticsResult>
  
  // 获取做T汇总
  static async getDayTradingSummary(startTime, endTime): Promise<DayTradingSummaryResult>
  
  // 获取资产收益排行
  static async getAssetProfitRanking(startTime, endTime): Promise<AssetProfitRanking[]>
}
```

## 7. 智能层设计

### 7.1 OcrService (OCR服务)

#### 7.1.1 核心功能
- 图片文本识别
- 交易信息提取
- 结果解析

#### 7.1.2 主要方法
```typescript
class OcrService {
  // 从PixelMap识别文本
  static async recognizeFromPixelMap(pixelMap): Promise<OcrResult>
  
  // 从文件路径识别文本
  static async recognizeFromFile(filePath): Promise<OcrResult>
  
  // 解析OCR文本
  static parseOcrText(rawText): OcrResult
}
```

#### 7.1.3 技术实现
- 使用HarmonyOS CoreVisionKit的文本识别API
- 支持方向检测
- 提取交易关键信息（资产名称、价格、数量等）

### 7.2 NlpParser (自然语言解析器)

#### 7.2.1 核心功能
- 自然语言交易指令解析
- 交易类型识别
- 时间信息提取
- 资产信息提取

#### 7.2.2 主要方法
```typescript
class NlpParser {
  // 解析交易文本
  static parseTradeText(text): ParseResult
  
  // 检测交易类型
  static detectTradeType(text): TradeType
  
  // 提取资产名称
  static extractAssetName(text): string
  
  // 提取价格信息
  static extractPrice(text): number
  
  // 提取数量信息
  static extractQuantity(text): number
  
  // 提取时间信息
  static extractTime(text): Date
  
  // 提取手续费
  static extractFee(text): number
  
  // 判断是否为做T
  static isDayTrading(text): boolean
  
  // 解析做T交易
  static parseDayTrading(text): ParseResult
}
```

#### 7.2.3 支持的自然语言模式
- 买入："买入基金A 1000份 1.5元"
- 卖出："卖出股票B 200股 10元"
- 做T："做T 股票B 卖出200股10元 买入200股9.5元"
- 时间表达："今天"、"昨天"、"2024-01-15"、"14:30"等

## 8. 数据层设计

### 8.1 RdbManager (数据库管理器)

#### 8.1.1 核心功能
- 数据库初始化
- 数据库版本管理
- 单例模式实现

#### 8.1.2 主要方法
```typescript
class RdbManager {
  // 获取单例
  static getInstance(): RdbManager
  
  // 获取数据库实例
  async getRdbStore(): Promise<relationalStore.RdbStore>
  
  // 初始化数据库
  async init(context): Promise<void>
  
  // 关闭数据库
  async close(): Promise<void>
}
```

### 8.2 RdbHelper (数据库辅助类)

#### 8.2.1 核心功能
- 资产表操作
- 交易记录表操作
- 每日估值表操作
- 事务管理

#### 8.2.2 主要方法
```typescript
class RdbHelper {
  // 获取数据库实例
  static getRdbStore(): relationalStore.RdbStore
  
  // 资产表操作
  static async insertAsset(asset): Promise<number>
  static async updateAsset(asset): Promise<void>
  static async deleteAsset(id): Promise<void>
  static async queryAssetById(id): Promise<Asset | undefined>
  static async queryAllAssets(): Promise<Asset[]>
  
  // 交易记录表操作
  static async insertTrade(trade): Promise<number>
  static async updateTrade(trade): Promise<void>
  static async deleteTrade(id): Promise<void>
  static async queryTradeById(id): Promise<TradeRecord | undefined>
  static async queryTradesByAsset(assetId): Promise<TradeRecord[]>
  static async queryTradesByDateRange(startTime, endTime): Promise<TradeRecord[]>
  
  // 每日估值表操作
  static async insertDailyValuation(valuation): Promise<number>
  static async queryDailyValuationByDate(date): Promise<DailyValuation | undefined>
  
  // 事务管理
  static async executeTransaction(callback): Promise<void>
}
```

### 8.3 数据库表结构

#### 8.3.1 asset (资产表)
```sql
CREATE TABLE IF NOT EXISTS asset (
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
)
```

#### 8.3.2 trade (交易记录表)
```sql
CREATE TABLE IF NOT EXISTS trade (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  assetId INTEGER NOT NULL,
  assetCode TEXT NOT NULL,
  assetName TEXT NOT NULL,
  quantity REAL NOT NULL,
  price REAL NOT NULL,
  fee REAL NOT NULL DEFAULT 0,
  tradeTime INTEGER NOT NULL,
  remark TEXT,
  FOREIGN KEY (assetId) REFERENCES asset(id) ON DELETE CASCADE
)
```

#### 8.3.3 dailyValuation (每日估值表)
```sql
CREATE TABLE IF NOT EXISTS dailyValuation (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER NOT NULL UNIQUE,
  totalAssets REAL NOT NULL,
  totalProfit REAL NOT NULL,
  profitRatio REAL NOT NULL,
  dayTradingProfit REAL NOT NULL DEFAULT 0
)
```

## 9. UI层设计

### 9.1 页面结构

#### 9.1.1 Index (首页入口)
- 应用启动入口
- 路由配置

#### 9.1.2 HomePage (主页面)
- 总资产展示
- 持仓列表
- 快捷操作入口
- 收益概览

#### 9.1.3 RecordPage (记录页面)
- 交易记录表单
- 自然语言输入
- 交易类型选择
- 资产选择

#### 9.1.4 AnalysisPage (分析页面)
- 收益统计图表
- 做T收益分析
- 资产收益排行
- 时间维度筛选

#### 9.1.5 OcrPage (OCR识别页面)
- 图片选择
- OCR识别结果展示
- 交易信息确认
- 自动填充表单

### 9.2 UI组件设计

#### 9.2.1 通用组件
- AssetCard: 资产卡片
- TradeItem: 交易记录项
- StatisticCard: 统计卡片
- ChartView: 图表视图

#### 9.2.2 交互设计
- 底部导航栏
- 顶部标题栏
- 下拉刷新
- 上拉加载更多
- 对话框提示

## 10. 数据流

### 10.1 交易记录流程
```
用户输入 → NlpParser解析 → TradeService处理 → RdbHelper存储 → AssetService更新资产
```

### 10.2 OCR识别流程
```
选择图片 → OcrService识别 → 提取关键信息 → 用户确认 → 生成交易记录
```

### 10.3 统计分析流程
```
时间选择 → StatisticsService查询 → 数据聚合 → UI展示
```

### 10.4 做T交易流程
```
用户输入做T指令 → NlpParser解析 → TradeService处理 → DayTradingService配对 → 计算收益
```

## 11. 核心功能实现

### 11.1 做T（日内高抛低吸）实现

#### 11.1.1 业务逻辑
1. 用户输入做T指令（如："做T 股票B 卖出200股10元 买入200股9.5元"）
2. NlpParser解析出卖出和买入信息
3. TradeService创建两条交易记录（T_SELL和T_BUY）
4. DayTradingService配对交易记录
5. 计算做T收益：收益 = (卖出价格 - 买入价格) × 数量 - 手续费

#### 11.1.2 配对算法
```typescript
static async pairDayTradingTrades(trades: TradeRecord[]): Promise<DayTradingPair[]> {
  const sellTrades = trades.filter(t => t.type === TradeType.T_SELL);
  const buyTrades = trades.filter(t => t.type === TradeType.T_BUY);
  const pairs: DayTradingPair[] = [];
  
  // 按资产分组
  const assetSellTrades: Map<number, TradeRecord[]> = new Map();
  const assetBuyTrades: Map<number, TradeRecord[]> = new Map();
  
  // 配对逻辑
  for (const assetId of assetSellTrades.keys()) {
    const sells = assetSellTrades.get(assetId) || [];
    const buys = assetBuyTrades.get(assetId) || [];
    
    // 按时间排序并配对
    sells.sort((a, b) => a.tradeTime - b.tradeTime);
    buys.sort((a, b) => a.tradeTime - b.tradeTime);
    
    for (let i = 0; i < Math.min(sells.length, buys.length); i++) {
      const pair: DayTradingPair = {
        sellTrade: sells[i],
        buyTrade: buys[i],
        profit: (sells[i].price - buys[i].price) * sells[i].quantity - sells[i].fee - buys[i].fee
      };
      pairs.push(pair);
    }
  }
  
  return pairs.sort((a, b) => b.sellTrade.tradeTime - a.sellTrade.tradeTime);
}
```

### 11.2 自然语言处理实现

#### 11.2.1 交易类型识别
```typescript
static detectTradeType(text: string): TradeType {
  if (text.includes('做T') || text.includes('日内')) {
    return TradeType.T_SELL; // 标记为做T
  }
  if (text.includes('买入') || text.includes('买')) {
    return TradeType.BUY;
  }
  if (text.includes('卖出') || text.includes('卖')) {
    return TradeType.SELL;
  }
  return TradeType.BUY; // 默认买入
}
```

#### 11.2.2 时间提取
```typescript
static extractTime(text: string): Date {
  const now = new Date();
  let targetDate = new Date(now);
  
  // 相对时间
  if (text.includes('今天')) {
    targetDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  } else if (text.includes('昨天')) {
    targetDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
  }
  
  // 绝对时间
  const dateMatch = text.match(/(\d{4})[-年](\d{1,2})[-月](\d{1,2})/);
  if (dateMatch) {
    targetDate = new Date(parseInt(dateMatch[1]), parseInt(dateMatch[2]) - 1, parseInt(dateMatch[3]));
  }
  
  // 时间
  const timeMatch = text.match(/(\d{1,2}):(\d{2})/);
  if (timeMatch) {
    targetDate.setHours(parseInt(timeMatch[1]), parseInt(timeMatch[2]), 0, 0);
  }
  
  return targetDate;
}
```

### 11.3 OCR识别实现

#### 11.3.1 文本识别
```typescript
static async recognizeFromPixelMap(pixelMap: image.PixelMap): Promise<OcrResult> {
  try {
    const visionInfo: textRecognition.VisionInfo = {
      pixelMap: pixelMap
    };

    const textConfiguration: textRecognition.TextRecognitionConfiguration = {
      isDirectionDetectionSupported: true
    };

    const result = await textRecognition.recognizeText(visionInfo, textConfiguration);
    const rawText = result.value || '';
    
    return OcrService.parseOcrText(rawText);
  } catch (err) {
    throw new Error(err.message);
  }
}
```

#### 11.3.2 结果解析
```typescript
static parseOcrText(rawText: string): OcrResult {
  const result: OcrResult = {
    success: false,
    assetName: '',
    price: 0,
    quantity: 0,
    tradeType: TradeType.BUY,
    rawText: rawText
  };
  
  // 提取资产名称
  const nameMatch = rawText.match(/([A-Za-z\u4e00-\u9fa5]{2,10})/);
  if (nameMatch) {
    result.assetName = nameMatch[1];
  }
  
  // 提取价格
  const priceMatch = rawText.match(/(\d+\.?\d*)\s*元/);
  if (priceMatch) {
    result.price = parseFloat(priceMatch[1]);
  }
  
  // 提取数量
  const quantityMatch = rawText.match(/(\d+\.?\d*)\s*(股|份|手)/);
  if (quantityMatch) {
    result.quantity = parseFloat(quantityMatch[1]);
  }
  
  result.success = result.assetName !== '' && result.price > 0 && result.quantity > 0;
  return result;
}
```

## 12. 技术要点

### 12.1 ArkTS特性应用

#### 12.1.1 静态方法设计
- 所有Service类采用静态方法
- 避免实例化，简化调用
- 符合ArkTS静态方法规范

#### 12.1.2 类型安全
- 使用接口定义复杂类型
- 避免使用any类型
- 显式类型声明

#### 12.1.3 异步编程
- 使用async/await处理异步操作
- Promise链式调用
- 错误处理

### 12.2 数据库优化

#### 12.2.1 事务管理
```typescript
await RdbHelper.executeTransaction(async () => {
  await RdbHelper.insertTrade(tradeRecord);
  await AssetService.updateAssetPrice(asset.id, trade.price);
});
```

#### 12.2.2 索引优化
- 主键索引：id
- 唯一索引：asset.code, dailyValuation.date
- 外键索引：trade.assetId

### 12.3 性能优化

#### 12.3.1 数据缓存
- 资产列表缓存
- 交易记录分页加载
- 统计结果缓存

#### 12.3.2 懒加载
- 图片按需加载
- 列表滚动加载
- 图表延迟渲染

### 12.4 用户体验

#### 12.4.1 交互设计
- 自然语言输入
- OCR快速识别
- 实时数据更新
- 流畅动画效果

#### 12.4.2 错误处理
- 友好的错误提示
- 操作撤销功能
- 数据备份恢复

## 13. 扩展性设计

### 13.1 功能扩展
- 支持更多资产类型（债券、期货等）
- 添加数据导出功能
- 集成实时行情数据
- 添加投资组合分析

### 13.2 技术扩展
- 支持云端数据同步
- 添加数据加密功能
- 集成AI智能推荐
- 支持多设备协同

## 14. 安全性设计

### 14.1 数据安全
- 本地数据加密存储
- 敏感信息脱敏处理
- 定期数据备份

### 14.2 权限管理
- 最小权限原则
- 运行时权限申请
- 权限使用说明

## 15. 测试策略

### 15.1 单元测试
- Service层方法测试
- 数据库操作测试
- NLP解析测试

### 15.2 集成测试
- 页面交互测试
- 完整业务流程测试
- OCR识别测试

### 15.3 性能测试
- 数据库查询性能
- 大数据量处理
- 内存使用优化

## 16. 部署与发布

### 16.1 构建配置
- Debug模式：开发调试
- Release模式：生产发布
- 签名配置：应用签名

### 16.2 发布流程
- 代码审查
- 测试验证
- 版本打包
- 应用商店发布

## 17. 总结

本架构设计文档详细描述了鸿蒙个人理财App的整体架构、模块划分、技术实现和核心功能。采用三层架构设计，结合HarmonyOS的ArkTS语言和Stage模型，实现了资产管理和交易记录的核心功能，并通过OCR和NLP技术提升了用户体验。

项目具有良好的扩展性和可维护性，为后续功能扩展和技术升级提供了坚实的基础。
