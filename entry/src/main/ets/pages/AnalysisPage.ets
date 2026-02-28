import { StatisticsService, ProfitSummary, AssetSummary } from '../service/StatisticsService';
import { DayTradingService, DayTradingPair, DayTradingSummary } from '../service/DayTradingService';
import { TimeRange } from '../common/constants/Constants';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AnalysisPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct AnalysisPage {
  @State selectedTimeRange: TimeRange = TimeRange.MONTH;
  @State profitHistory: ProfitSummary[] = [];
  @State dayTradingSummary: DayTradingSummary = {
    totalProfit: 0,
    totalTrades: 0,
    winRate: 0,
    avgProfit: 0,
    maxProfit: 0,
    maxLoss: 0
  };
  @State recentDayTrading: DayTradingPair[] = [];
  @State isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    await this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      this.isLoading = true;
      const results = await Promise.all([
        StatisticsService.getProfitHistory(this.selectedTimeRange),
        this.getDayTradingSummary(),
        DayTradingService.getRecentDayTradingPairs(10)
      ]);
      this.profitHistory = results[0] as ProfitSummary[];
      this.dayTradingSummary = results[1] as DayTradingSummary;
      this.recentDayTrading = results[2] as DayTradingPair[];
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load data failed: %{public}s', JSON.stringify(err));
    } finally {
      this.isLoading = false;
    }
  }

  async getDayTradingSummary(): Promise<DayTradingSummary> {
    const now = Date.now();
    let startTime = now - 30 * 24 * 60 * 60 * 1000;
    
    switch (this.selectedTimeRange) {
      case TimeRange.WEEK:
        startTime = now - 7 * 24 * 60 * 60 * 1000;
        break;
      case TimeRange.MONTH:
        startTime = now - 30 * 24 * 60 * 60 * 1000;
        break;
      case TimeRange.QUARTER:
        startTime = now - 90 * 24 * 60 * 60 * 1000;
        break;
      case TimeRange.YEAR:
        startTime = now - 365 * 24 * 60 * 60 * 1000;
        break;
    }
    
    return await DayTradingService.getDayTradingSummary(startTime, now);
  }

  build() {
    Column({ space: 0 }) {
      this.Header()
      
      if (this.isLoading) {
        this.LoadingView()
      } else {
        Scroll() {
          Column({ space: 16 }) {
            this.TimeRangeSelector()
            this.ProfitChart()
            this.DayTradingSummary()
            this.RecentDayTradingList()
          }
          .padding(16)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  Header() {
    Row() {
      Button()
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })

      Text('持仓分析')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button()
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  LoadingView() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(50)
        .height(50)
        .color('#FF5722')
      Text('加载中...')
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TimeRangeSelector() {
    Row({ space: 8 }) {
      this.TimeRangeButton('周', TimeRange.WEEK)
      this.TimeRangeButton('月', TimeRange.MONTH)
      this.TimeRangeButton('季', TimeRange.QUARTER)
      this.TimeRangeButton('年', TimeRange.YEAR)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
  }

  @Builder
  TimeRangeButton(label: string, range: TimeRange) {
    Button(label)
      .fontSize(14)
      .backgroundColor(this.selectedTimeRange === range ? '#FF5722' : '#FFFFFF')
      .fontColor(this.selectedTimeRange === range ? '#FFFFFF' : '#666666')
      .borderRadius(20)
      .height(36)
      .onClick(() => {
        this.selectedTimeRange = range;
        this.loadData();
      })
  }

  @Builder
  ProfitChart() {
    Column({ space: 12 }) {
      Text('收益曲线')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      if (this.profitHistory.length === 0) {
        Text('暂无数据')
          .fontSize(14)
          .fontColor('#999999')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(40)
      } else {
        this.SimpleChart()
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  SimpleChart() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column()
        .width('100%')
        .height(200)
        .backgroundColor('#F8F8F8')

      Row({ space: 0 }) {
        ForEach(this.profitHistory, (item: ProfitSummary, index: number) => {
          Column({ space: 4 }) {
            Column()
              .width(8)
              .height(this.calculateBarHeight(item.profit))
              .backgroundColor(item.profit >= 0 ? '#FF5722' : '#4CAF50')
              .borderRadius(4)
            
            Text(item.date.substring(5))
              .fontSize(10)
              .fontColor('#999999')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 24 })
    }
    .width('100%')
    .height(200)
  }

  calculateBarHeight(profit: number): string {
    const maxProfit = Math.max(...this.profitHistory.map(p => Math.abs(p.profit)));
    if (maxProfit === 0) {
      return '10%';
    }
    const height = (Math.abs(profit) / maxProfit) * 100;
    return Math.max(10, Math.min(80, height)) + '%';
  }

  @Builder
  DayTradingSummary() {
    Column({ space: 12 }) {
      Text('做T统计')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Row({ space: 16 }) {
        this.StatItem('总收益', this.dayTradingSummary.totalProfit.toFixed(2), '#FF5722')
        this.StatItem('交易次数', this.dayTradingSummary.totalTrades.toString(), '#666666')
        this.StatItem('胜率', this.dayTradingSummary.winRate.toFixed(1) + '%', '#2196F3')
      }

      Row({ space: 16 }) {
        this.StatItem('平均收益', this.dayTradingSummary.avgProfit.toFixed(2), '#FF9800')
        this.StatItem('最大盈利', this.dayTradingSummary.maxProfit.toFixed(2), '#FF5722')
        this.StatItem('最大亏损', this.dayTradingSummary.maxLoss.toFixed(2), '#4CAF50')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  StatItem(label: string, value: string, color: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(12)
        .fontColor('#999999')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecentDayTradingList() {
    Column({ space: 12 }) {
      Row() {
        Text('近期做T记录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`共${this.recentDayTrading.length}笔`)
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')

      if (this.recentDayTrading.length === 0) {
        Text('暂无做T记录')
          .fontSize(14)
          .fontColor('#999999')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(20)
      } else {
        ForEach(this.recentDayTrading, (pair: DayTradingPair) => {
          this.DayTradingItem(pair)
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  DayTradingItem(pair: DayTradingPair) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(pair.assetName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(pair.assetCode)
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 4 }) {
        Text(pair.tradeDate)
          .fontSize(14)
          .fontColor('#666666')
        Text(`${pair.sellTrade.quantity}${pair.assetName.includes('基金') ? '份' : '股'}`)
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.End)

      Column({ space: 4 }) {
        Text(DayTradingService.formatProfit(pair.profit))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(DayTradingService.getProfitColor(pair.profit))
        Text(`${pair.sellTrade.price.toFixed(2)}→${pair.buyTrade.price.toFixed(2)}`)
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F8F8F8')
    .borderRadius(8)
  }
}