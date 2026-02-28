import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'OcrService';
const DOMAIN = 0x0000;

export interface OcrResult {
  code?: string;
  name?: string;
  quantity?: number;
  price?: number;
  changePercent?: number;
  rawText: string;
}

export class OcrService {
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
      
      hilog.info(DOMAIN, TAG, 'OCR recognized text: %{public}s', rawText);
      
      return OcrService.parseOcrText(rawText);
    } catch (err) {
      const error = err as Error;
      hilog.error(DOMAIN, TAG, 'OCR recognition failed: %{public}s', error.message);
      throw new Error(error.message);
    }
  }

  private static parseOcrText(text: string): OcrResult {
    const result: OcrResult = { rawText: text };
    
    const fundCodePattern = /(?:基金代码|代码)[:：]\s*(\d{6})/;
    const fundCodeMatch = text.match(fundCodePattern);
    if (fundCodeMatch) {
      result.code = fundCodeMatch[1];
    }

    const fundNamePattern = /(?:基金名称|名称)[:：]\s*([^\s\n]+)/;
    const fundNameMatch = text.match(fundNamePattern);
    if (fundNameMatch) {
      result.name = fundNameMatch[1];
    }

    const quantityPattern = /(?:持有份额|份额|持仓)[:：]\s*(\d+(?:\.\d+)?)/;
    const quantityMatch = text.match(quantityPattern);
    if (quantityMatch) {
      result.quantity = parseFloat(quantityMatch[1]);
    }

    const pricePattern = /(?:单位净值|净值|当前价|股价)[:：]\s*(\d+(?:\.\d+)?)/;
    const priceMatch = text.match(pricePattern);
    if (priceMatch) {
      result.price = parseFloat(priceMatch[1]);
    }

    const changePattern = /(?:涨跌幅|日涨跌)[:：]\s*([+-]?\d+(?:\.\d+)?)\s*%/;
    const changeMatch = text.match(changePattern);
    if (changeMatch) {
      result.changePercent = parseFloat(changeMatch[1]);
    }

    const stockCodePattern = /(\d{6})\s*([A-Z]+)/;
    const stockCodeMatch = text.match(stockCodePattern);
    if (stockCodeMatch) {
      result.code = stockCodeMatch[1];
    }

    return result;
  }
}
