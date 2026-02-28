import { Asset } from '../model/entity/Asset';
import { RdbHelper } from '../database/RdbHelper';
import { AssetType } from '../common/constants/Constants';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AssetService';
const DOMAIN = 0x0000;

export interface TotalAssetsResult {
  totalValue: number;
  totalProfit: number;
}

export class AssetService {
  static async createAsset(type: AssetType, code: string, name: string, 
    costPrice: number = 0, quantity: number = 0): Promise<number> {
    const asset = new Asset();
    asset.type = type;
    asset.code = code;
    asset.name = name;
    asset.costPrice = costPrice;
    asset.quantity = quantity;
    asset.marketValue = costPrice * quantity;
    asset.profitLossRatio = 0;
    
    const id = await RdbHelper.insertAsset(asset);
    hilog.info(DOMAIN, TAG, 'Asset created: %{public}s', name);
    return id;
  }

  static async updateAssetPrice(assetId: number, currentPrice: number): Promise<void> {
    const asset = await RdbHelper.queryAssetById(assetId);
    if (asset) {
      asset.currentPrice = currentPrice;
      asset.marketValue = currentPrice * asset.quantity;
      if (asset.costPrice > 0) {
        asset.profitLossRatio = ((currentPrice - asset.costPrice) / asset.costPrice) * 100;
      }
      asset.updateTime = Date.now();
      await RdbHelper.updateAsset(asset);
    }
  }

  static async updateAssetQuantity(assetId: number, deltaQuantity: number, newCostPrice?: number): Promise<void> {
    const asset = await RdbHelper.queryAssetById(assetId);
    if (asset) {
      if (newCostPrice !== undefined) {
        const oldTotalCost = asset.costPrice * asset.quantity;
        const newTotalCost = newCostPrice * deltaQuantity;
        asset.quantity += deltaQuantity;
        if (asset.quantity > 0) {
          asset.costPrice = (oldTotalCost + newTotalCost) / asset.quantity;
        }
      } else {
        asset.quantity += deltaQuantity;
      }
      asset.marketValue = asset.currentPrice * asset.quantity;
      asset.updateTime = Date.now();
      await RdbHelper.updateAsset(asset);
    }
  }

  static async getAllAssets(): Promise<Asset[]> {
    return await RdbHelper.queryAllAssets();
  }

  static async getAssetById(id: number): Promise<Asset | null> {
    return await RdbHelper.queryAssetById(id);
  }

  static async findAssetByCode(code: string): Promise<Asset | null> {
    const assets = await RdbHelper.queryAllAssets();
    return assets.find(a => a.code === code) || null;
  }

  static async calculateTotalAssets(): Promise<TotalAssetsResult> {
    const assets = await RdbHelper.queryAllAssets();
    let totalValue = 0;
    let totalProfit = 0;
    
    for (const asset of assets) {
      totalValue += asset.marketValue;
      totalProfit += asset.marketValue - (asset.costPrice * asset.quantity);
    }
    
    const result: TotalAssetsResult = { totalValue, totalProfit };
    return result;
  }
}