import { Asset } from '../model/entity/Asset';
import { AssetService } from '../service/AssetService';
import { StatisticsService, AssetSummary } from '../service/StatisticsService';
import { DayTradingService } from '../service/DayTradingService';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'HomePage';
const DOMAIN = 0x0000;

@Entry
@Component
struct HomePage {
  @State summary: AssetSummary = {
    totalValue: 0,
    totalProfit: 0,
    totalProfitRatio: 0,
    stockValue: 0,
    stockProfit: 0,
    fundValue: 0,
    fundProfit: 0
  };
  @State assets: Asset[] = [];
  @State dayTradingProfit: number = 0;
  @State isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    await this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      this.isLoading = true;
      const results = await Promise.all([
        StatisticsService.getAssetSummary(),
        AssetService.getAllAssets(),
        this.getTodayDayTradingProfit()
      ]);
      this.summary = results[0] as AssetSummary;
      this.assets = results[1] as Asset[];
      this.dayTradingProfit = results[2] as number;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load data failed: %{public}s', JSON.stringify(err));
    } finally {
      this.isLoading = false;
    }
  }

  async getTodayDayTradingProfit(): Promise<number> {
    const now = Date.now();
    const todayStart = new Date().setHours(0, 0, 0, 0);
    const todayEnd = new Date().setHours(23, 59, 59, 999);
    const summary = await DayTradingService.getDayTradingSummary(todayStart, todayEnd);
    return summary.totalProfit;
  }

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        this.AssetOverviewTab()
      }
      .tabBar(this.TabBarItem('资产', $r('app.media.startIcon')))

      TabContent() {
        this.RecordTab()
      }
      .tabBar(this.TabBarItem('记录', $r('app.media.startIcon')))

      TabContent() {
        this.AnalysisTab()
      }
      .tabBar(this.TabBarItem('分析', $r('app.media.startIcon')))
    }
    .onChange((index: number) => {
      if (index === 0) {
        this.loadData();
      }
    })
  }

  @Builder
  TabBarItem(text: string, icon: Resource) {
    Column({ space: 4 }) {
      Image(icon)
        .width(24)
        .height(24)
      Text(text)
        .fontSize(12)
    }
  }

  @Builder
  AssetOverviewTab() {
    Scroll() {
      Column({ space: 16 }) {
        this.SummaryCard()
        this.DayTradingCard()
        this.AssetListCard()
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  SummaryCard() {
    Column({ space: 12 }) {
      Text('总资产')
        .fontSize(14)
        .fontColor('#999999')

      Text(`¥${this.summary.totalValue.toFixed(2)}`)
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.summary.totalProfit >= 0 ? '#FF5722' : '#4CAF50')

      Row({ space: 20 }) {
        Column({ space: 4 }) {
          Text(this.summary.totalProfit >= 0 ? '+' : '' + this.summary.totalProfit.toFixed(2))
            .fontSize(18)
            .fontColor(this.summary.totalProfit >= 0 ? '#FF5722' : '#4CAF50')
          Text('总盈亏')
            .fontSize(12)
            .fontColor('#999999')
        }

        Column({ space: 4 }) {
          Text(`${this.summary.totalProfitRatio.toFixed(2)}%`)
            .fontSize(18)
            .fontColor(this.summary.totalProfitRatio >= 0 ? '#FF5722' : '#4CAF50')
          Text('收益率')
            .fontSize(12)
            .fontColor('#999999')
        }
      }

      Row({ space: 12 }) {
        this.TypeCard('股票', this.summary.stockValue, this.summary.stockProfit)
        this.TypeCard('基金', this.summary.fundValue, this.summary.fundProfit)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  TypeCard(type: string, value: number, profit: number) {
    Column({ space: 4 }) {
      Text(type)
        .fontSize(12)
        .fontColor('#999999')
      Text(`¥${value.toFixed(2)}`)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Text((profit >= 0 ? '+' : '') + profit.toFixed(2))
        .fontSize(12)
        .fontColor(profit >= 0 ? '#FF5722' : '#4CAF50')
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor('#F8F8F8')
    .borderRadius(8)
  }

  @Builder
  DayTradingCard() {
    Row() {
      Column({ space: 4 }) {
        Text('今日做T收益')
          .fontSize(14)
          .fontColor('#999999')
        Text(DayTradingService.formatProfit(this.dayTradingProfit))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(DayTradingService.getProfitColor(this.dayTradingProfit))
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button('查看详情')
        .fontSize(14)
        .backgroundColor('#FF5722')
        .onClick(() => {
          router.pushUrl({ url: 'pages/AnalysisPage' });
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  AssetListCard() {
    Column({ space: 12 }) {
      Row() {
        Text('持仓列表')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('共' + this.assets.length + '只')
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')

      if (this.assets.length === 0) {
        Text('暂无持仓')
          .fontSize(14)
          .fontColor('#999999')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(20)
      } else {
        ForEach(this.assets.slice(0, 10), (asset: Asset) => {
          this.AssetItem(asset)
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
  AssetItem(asset: Asset) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(asset.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(asset.code)
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 4 }) {
        Text(asset.currentPrice.toFixed(2))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(`${asset.quantity.toFixed(2)}${asset.type === 'FUND' ? '份' : '股'}`)
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.End)

      Column({ space: 4 }) {
        Text(`¥${asset.marketValue.toFixed(2)}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Text((asset.profitLossRatio >= 0 ? '+' : '') + asset.profitLossRatio.toFixed(2) + '%')
          .fontSize(12)
          .fontColor(asset.profitLossRatio >= 0 ? '#FF5722' : '#4CAF50')
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F8F8F8')
    .borderRadius(8)
  }

  @Builder
  RecordTab() {
    Column({ space: 16 }) {
      Button('添加交易记录')
        .width('90%')
        .height(50)
        .fontSize(16)
        .backgroundColor('#FF5722')
        .onClick(() => {
          router.pushUrl({ url: 'pages/RecordPage' });
        })

      Button('OCR识别')
        .width('90%')
        .height(50)
        .fontSize(16)
        .backgroundColor('#2196F3')
        .onClick(() => {
          router.pushUrl({ url: 'pages/OcrPage' });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  AnalysisTab() {
    Column({ space: 16 }) {
      Text('统计分析')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text('请添加交易记录后查看分析')
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}