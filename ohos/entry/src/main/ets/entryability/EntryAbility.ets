import { FlutterAbility } from '@ohos/flutter_ohos';
import window from '@ohos.window';

export default class EntryAbility extends FlutterAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 设置窗口全屏布局
    windowStage.loadContent('pages/Index', (): void => {
      // 窗口内容加载完成
    });
    super.onWindowStageCreate(windowStage);
  }
}
