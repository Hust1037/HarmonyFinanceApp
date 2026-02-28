import { TradeService, ParsedTrade } from '../service/TradeService';
import { NlpParser, ParseResult, TradeInfo } from '../ai/NlpParser';
import { TradeType } from '../common/constants/Constants';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'RecordPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct RecordPage {
  @State inputText: string = '';
  @State parseResult: ParseResult | null = null;
  @State isSubmitting: boolean = false;
  @State successMessage: string = '';
  @State showManualForm: boolean = false;
  @State manualType: TradeType = TradeType.BUY;
  @State manualAsset: string = '';
  @State manualQuantity: string = '';
  @State manualPrice: string = '';
  @State manualFee: string = '';

  build() {
    Column({ space: 0 }) {
      this.Header()
      
      Scroll() {
        Column({ space: 16 }) {
          this.NlpInputSection()
          
          if (this.parseResult && this.parseResult.success) {
            this.ParseResultSection()
          }
          
          if (this.showManualForm) {
            this.ManualFormSection()
          }
          
          if (this.successMessage) {
            this.SuccessMessage()
          }
        }
        .padding(16)
      }
      .width('100%')
      .layoutWeight(1)
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

      Text('记录交易')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button()
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showManualForm = !this.showManualForm;
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  NlpInputSection() {
    Column({ space: 12 }) {
      Text('自然语言输入')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      TextArea({ 
        placeholder: '例如：今天10点以1.05元买入1000份易方达全球成长，手续费1.5元' 
      })
        .width('100%')
        .height(120)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding(12)
        .onChange((value: string) => {
          this.inputText = value;
        })

      Row({ space: 12 }) {
        Button('解析')
          .layoutWeight(1)
          .height(44)
          .fontSize(16)
          .backgroundColor('#2196F3')
          .onClick(() => {
            this.parseText();
          })

        Button('提交')
          .layoutWeight(1)
          .height(44)
          .fontSize(16)
          .backgroundColor('#FF5722')
          .enabled(this.parseResult?.success ?? false)
          .onClick(() => {
            this.submitTrade();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  parseText(): void {
    if (!this.inputText.trim()) {
      return;
    }

    const normalizedText = NlpParser.normalizeText(this.inputText);
    this.parseResult = NlpParser.parseTradeText(normalizedText);
    
    if (this.parseResult.success) {
      hilog.info(DOMAIN, TAG, 'Parse success: %{public}s', JSON.stringify(this.parseResult));
    } else {
      hilog.warn(DOMAIN, TAG, 'Parse failed: %{public}s', this.parseResult.errorMessage);
    }
  }

  async submitTrade(): Promise<void> {
    if (!this.parseResult || !this.parseResult.success) {
      return;
    }

    try {
      this.isSubmitting = true;
      
      if (this.parseResult.type === 'DAY_TRADING' && this.parseResult.trades.length === 2) {
        const buyTrade = this.parseResult.trades.find(t => t.type === TradeType.T_BUY)!;
        const sellTrade = this.parseResult.trades.find(t => t.type === TradeType.T_SELL)!;
        
        const parsedBuy: ParsedTrade = {
          type: buyTrade.type,
          assetName: buyTrade.assetName,
          quantity: buyTrade.quantity,
          price: buyTrade.price,
          fee: buyTrade.fee,
          tradeTime: buyTrade.time.getTime(),
          remark: this.inputText
        };
        
        const parsedSell: ParsedTrade = {
          type: sellTrade.type,
          assetName: sellTrade.assetName,
          quantity: sellTrade.quantity,
          price: sellTrade.price,
          fee: sellTrade.fee,
          tradeTime: sellTrade.time.getTime(),
          remark: this.inputText
        };
        
        await TradeService.addDayTrading(parsedBuy, parsedSell);
        this.successMessage = '做T记录添加成功';
      } else {
        const trade = this.parseResult.trades[0];
        const parsedTrade: ParsedTrade = {
          type: trade.type,
          assetName: trade.assetName,
          quantity: trade.quantity,
          price: trade.price,
          fee: trade.fee,
          tradeTime: trade.time.getTime(),
          remark: this.inputText
        };
        
        await TradeService.addTrade(parsedTrade);
        this.successMessage = '交易记录添加成功';
      }
      
      this.inputText = '';
      this.parseResult = null;
      
      setTimeout(() => {
        this.successMessage = '';
        router.back();
      }, 1500);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Submit failed: %{public}s', JSON.stringify(err));
      this.successMessage = '提交失败，请重试';
    } finally {
      this.isSubmitting = false;
    }
  }

  @Builder
  ParseResultSection() {
    Column({ space: 12 }) {
      Text('解析结果')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      ForEach(this.parseResult!.trades, (trade: TradeInfo) => {
        Column({ space: 8 }) {
          Row() {
            Text('操作类型')
              .fontSize(14)
              .fontColor('#999999')
            Blank()
            Text(trade.type === TradeType.BUY ? '买入' : '卖出')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(trade.type === TradeType.BUY ? '#FF5722' : '#4CAF50')
          }
          .width('100%')

          Row() {
            Text('标的')
              .fontSize(14)
              .fontColor('#999999')
            Blank()
            Text(trade.assetName)
              .fontSize(14)
          }
          .width('100%')

          Row() {
            Text('数量')
              .fontSize(14)
              .fontColor('#999999')
            Blank()
            Text(`${trade.quantity}${trade.type.includes('T') ? '股' : '股/份'}`)
              .fontSize(14)
          }
          .width('100%')

          Row() {
            Text('价格')
              .fontSize(14)
              .fontColor('#999999')
            Blank()
            Text(`${trade.price.toFixed(2)}元`)
              .fontSize(14)
          }
          .width('100%')

          Row() {
            Text('手续费')
              .fontSize(14)
              .fontColor('#999999')
            Blank()
            Text(`${trade.fee.toFixed(2)}元`)
              .fontSize(14)
          }
          .width('100%')

          Row() {
            Text('时间')
              .fontSize(14)
              .fontColor('#999999')
            Blank()
            Text(new Date(trade.time.getTime()).toLocaleString())
              .fontSize(14)
          }
          .width('100%')
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  ManualFormSection() {
    Column({ space: 12 }) {
      Text('手动输入')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Row({ space: 12 }) {
        Button('买入')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .backgroundColor(this.manualType === TradeType.BUY ? '#FF5722' : '#FFFFFF')
          .fontColor(this.manualType === TradeType.BUY ? '#FFFFFF' : '#666666')
          .onClick(() => {
            this.manualType = TradeType.BUY;
          })
        Button('卖出')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .backgroundColor(this.manualType === TradeType.SELL ? '#4CAF50' : '#FFFFFF')
          .fontColor(this.manualType === TradeType.SELL ? '#FFFFFF' : '#666666')
          .onClick(() => {
            this.manualType = TradeType.SELL;
          })
      }
      .width('100%')

      TextInput({ placeholder: '资产名称/代码' })
        .width('100%')
        .height(44)
        .onChange((value: string) => {
          this.manualAsset = value;
        })

      TextInput({ placeholder: '数量' })
        .width('100%')
        .height(44)
        .type(InputType.Number)
        .onChange((value: string) => {
          this.manualQuantity = value;
        })

      TextInput({ placeholder: '价格' })
        .width('100%')
        .height(44)
        .type(InputType.Number)
        .onChange((value: string) => {
          this.manualPrice = value;
        })

      TextInput({ placeholder: '手续费（可选）' })
        .width('100%')
        .height(44)
        .type(InputType.Number)
        .onChange((value: string) => {
          this.manualFee = value;
        })

      Button('提交')
        .width('100%')
        .height(44)
        .fontSize(16)
        .backgroundColor('#FF5722')
        .onClick(() => {
          this.submitManualTrade();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  async submitManualTrade(): Promise<void> {
    if (!this.manualAsset || !this.manualQuantity || !this.manualPrice) {
      return;
    }

    try {
      this.isSubmitting = true;
      
      const parsedTrade: ParsedTrade = {
        type: this.manualType,
        assetName: this.manualAsset,
        quantity: parseFloat(this.manualQuantity),
        price: parseFloat(this.manualPrice),
        fee: this.manualFee ? parseFloat(this.manualFee) : 0,
        tradeTime: Date.now(),
        remark: '手动输入'
      };
      
      await TradeService.addTrade(parsedTrade);
      this.successMessage = '交易记录添加成功';
      
      this.manualAsset = '';
      this.manualQuantity = '';
      this.manualPrice = '';
      this.manualFee = '';
      
      setTimeout(() => {
        this.successMessage = '';
        router.back();
      }, 1500);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Manual submit failed: %{public}s', JSON.stringify(err));
      this.successMessage = '提交失败，请重试';
    } finally {
      this.isSubmitting = false;
    }
  }

  @Builder
  SuccessMessage() {
    Text(this.successMessage)
      .width('100%')
      .padding(16)
      .backgroundColor('#4CAF50')
      .fontColor('#FFFFFF')
      .fontSize(14)
      .textAlign(TextAlign.Center)
      .borderRadius(8)
  }
}