import { OcrService, OcrResult } from '../ai/OcrService';
import { AssetService } from '../service/AssetService';
import { AssetType } from '../common/constants/Constants';
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'OcrPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct OcrPage {
  @State selectedImageUri: string = '';
  @State ocrResult: OcrResult | null = null;
  @State isProcessing: boolean = false;
  @State successMessage: string = '';
  @State showImage: boolean = false;

  async aboutToAppear(): Promise<void> {
    // OcrService 不需要初始化
  }

  build() {
    Column({ space: 0 }) {
      this.Header()
      
      Scroll() {
        Column({ space: 16 }) {
          this.ImageSelector()
          
          if (this.showImage && this.selectedImageUri) {
            this.ImagePreview()
          }
          
          if (this.ocrResult) {
            this.OcrResultSection()
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

      Text('OCR识别')
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
  ImageSelector() {
    Column({ space: 12 }) {
      Text('选择截图')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Row({ space: 12 }) {
        Button('相册')
          .layoutWeight(1)
          .height(44)
          .fontSize(16)
          .backgroundColor('#2196F3')
          .onClick(() => {
            this.selectFromGallery();
          })

        Button('截图')
          .layoutWeight(1)
          .height(44)
          .fontSize(16)
          .backgroundColor('#FF9800')
          .onClick(() => {
            this.takeScreenshot();
          })
      }
      .width('100%')

      Button('开始识别')
        .width('100%')
        .height(44)
        .fontSize(16)
        .backgroundColor('#FF5722')
        .enabled(this.selectedImageUri.length > 0)
        .onClick(() => {
          this.recognizeImage();
        })
    }
    .width('100%')
  }

  async selectFromGallery(): Promise<void> {
    try {
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      
      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
      
      if (photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        this.selectedImageUri = photoSelectResult.photoUris[0];
        this.showImage = true;
        this.ocrResult = null;
        this.successMessage = '';
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Select from gallery failed: %{public}s', JSON.stringify(err));
    }
  }

  takeScreenshot(): void {
    hilog.info(DOMAIN, TAG, 'Please use system screenshot function');
  }

  @Builder
  ImagePreview() {
    Column({ space: 12 }) {
      Text('已选图片')
        .fontSize(14)
        .fontColor('#999999')
        .width('100%')

      Image(this.selectedImageUri)
        .width('100%')
        .height(200)
        .objectFit(ImageFit.Contain)
        .borderRadius(8)
        .backgroundColor('#F8F8F8')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  async recognizeImage(): Promise<void> {
    if (!this.selectedImageUri) {
      return;
    }

    try {
      this.isProcessing = true;
      const imageSource = image.createImageSource(this.selectedImageUri);
      const pixelMap = await imageSource.createPixelMap();
      this.ocrResult = await OcrService.recognizeFromPixelMap(pixelMap);
      hilog.info(DOMAIN, TAG, 'OCR result: %{public}s', JSON.stringify(this.ocrResult));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Recognize failed: %{public}s', JSON.stringify(err));
      const failResult: OcrResult = {
        rawText: ''
      };
      this.ocrResult = failResult;
    } finally {
      this.isProcessing = false;
    }
  }

  @Builder
  OcrResultSection() {
    Column({ space: 12 }) {
      Text('识别结果')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      if (this.ocrResult!.code) {
        this.ResultItem('基金代码', this.ocrResult!.code)
      }
      
      if (this.ocrResult!.name) {
        this.ResultItem('基金名称', this.ocrResult!.name)
      }
      
      if (this.ocrResult!.quantity) {
        this.ResultItem('持有份额', this.ocrResult!.quantity.toString())
      }
      
      if (this.ocrResult!.price) {
        this.ResultItem('当前净值', this.ocrResult!.price.toFixed(4))
      }
      
      if (this.ocrResult!.changePercent !== undefined) {
        this.ResultItem('涨跌幅', 
          (this.ocrResult!.changePercent >= 0 ? '+' : '') + this.ocrResult!.changePercent.toFixed(2) + '%', 
          this.ocrResult!.changePercent >= 0 ? '#FF5722' : '#4CAF50')
      }

      if (this.ocrResult!.rawText) {
        Column({ space: 4 }) {
          Text('原始文本')
            .fontSize(12)
            .fontColor('#999999')
          Text(this.ocrResult!.rawText.substring(0, 200) + 
               (this.ocrResult!.rawText.length > 200 ? '...' : ''))
            .fontSize(12)
            .fontColor('#666666')
            .maxLines(5)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
      }

      Button('保存到资产')
        .width('100%')
        .height(44)
        .fontSize(16)
        .backgroundColor('#FF5722')
        .onClick(() => {
          this.saveToAsset();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  ResultItem(label: string, value: string, color: string = '#333333') {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#999999')
      Blank()
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#F8F8F8')
    .borderRadius(8)
  }

  async saveToAsset(): Promise<void> {
    if (!this.ocrResult || !this.ocrResult.code) {
      return;
    }

    try {
      const existingAsset = await AssetService.findAssetByCode(this.ocrResult.code);
      
      if (existingAsset) {
        if (this.ocrResult.price) {
          await AssetService.updateAssetPrice(existingAsset.id, this.ocrResult.price);
          this.successMessage = '资产价格已更新';
        } else {
          this.successMessage = '资产已存在';
        }
      } else {
        const assetId = await AssetService.createAsset(
          AssetType.FUND,
          this.ocrResult.code,
          this.ocrResult.name || this.ocrResult.code,
          this.ocrResult.price || 0,
          this.ocrResult.quantity || 0
        );
        this.successMessage = '资产已创建';
      }
      
      setTimeout(() => {
        this.successMessage = '';
        router.back();
      }, 1500);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save to asset failed: %{public}s', JSON.stringify(err));
      this.successMessage = '保存失败，请重试';
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