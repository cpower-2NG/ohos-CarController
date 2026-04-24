import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';

export interface SpeechToTextListener {
  onText?: (text: string) => void;
  onError?: (message: string) => void;
  onStateChange?: (recording: boolean) => void;
}

export class SpeechToTextService {
  private engine: speechRecognizer.SpeechRecognitionEngine | undefined = undefined;
  private listener: SpeechToTextListener | null = null;
  private recording: boolean = false;
  private sessionId: string = '';
  private retryCount: number = 0;
  private readonly maxRetryCount: number = 3;
  private readonly recognitionTimeoutMs: number = 12000;
  private timerId: number = -1;

  setListener(listener: SpeechToTextListener): void {
    this.listener = listener;
  }

  isRecording(): boolean {
    return this.recording;
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    await this.requestMicrophonePermission(context);

    this.engine = await new Promise<speechRecognizer.SpeechRecognitionEngine>((resolve, reject) => {
      const extraParam: Record<string, Object> = {
        locate: 'CN',
        recognizerMode: 'short'
      };

      const initParamsInfo: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: extraParam
      };

      speechRecognizer.createEngine(
        initParamsInfo,
        (err: BusinessError, speechRecognitionEngine: speechRecognizer.SpeechRecognitionEngine) => {
          if (err) {
            reject(new Error(this.formatBusinessError(err)));
            return;
          }
          resolve(speechRecognitionEngine);
        }
      );
    });

    this.bindRecognizerListener();
  }

  async startVoiceRecording(isRetry: boolean = false): Promise<void> {
    if (!this.engine) {
      throw new Error('语音识别引擎未初始化');
    }

    if (!isRetry) {
      this.retryCount = 0;
    }

    this.sessionId = `${new Date().getTime()}`;
    const audioParam: speechRecognizer.AudioInfo = {
      audioType: 'pcm',
      sampleRate: 16000,
      soundChannel: 1,
      sampleBit: 16
    };

    const extraParam: Record<string, Object> = {
      recognitionMode: 0,
      vadBegin: 2000,
      vadEnd: 3000,
      maxAudioDuration: 20000
    };

    const recognizerParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: audioParam,
      extraParams: extraParam
    };

    this.engine.startListening(recognizerParams);
    this.recording = true;
    this.startRecognitionTimer();
    this.listener?.onStateChange?.(true);
  }

  async stopVoiceRecording(): Promise<void> {
    if (!this.engine || !this.sessionId) {
      this.recording = false;
      this.listener?.onStateChange?.(false);
      return;
    }

    this.engine.finish(this.sessionId);
    this.recording = false;
    this.stopRecognitionTimer();
    this.listener?.onStateChange?.(false);
  }

  async cancelVoiceRecording(): Promise<void> {
    if (!this.engine || !this.sessionId) {
      this.recording = false;
      this.listener?.onStateChange?.(false);
      return;
    }

    this.engine.cancel(this.sessionId);
    this.recording = false;
    this.stopRecognitionTimer();
    this.listener?.onStateChange?.(false);
  }

  async restartVoiceRecording(): Promise<void> {
    await this.cancelVoiceRecording();
    await this.startVoiceRecording(true);
  }

  shutdown(): void {
    try {
      this.engine?.shutdown();
    } catch (err) {
      // Ignore shutdown errors for a disposed engine.
    }
    this.engine = undefined;
    this.recording = false;
    this.stopRecognitionTimer();
  }

  private bindRecognizerListener(): void {
    this.engine?.setListener({
      onStart: (_sessionId: string, _eventMessage: string) => {
        this.recording = true;
        this.listener?.onStateChange?.(true);
      },
      onResult: (_sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        if (result.result) {
          this.retryCount = 0;
          this.stopRecognitionTimer();
          this.listener?.onText?.(result.result);
        }
      },
      onComplete: (_sessionId: string, _eventMessage: string) => {
        this.recording = false;
        this.stopRecognitionTimer();
        this.listener?.onStateChange?.(false);
      },
      onError: (_sessionId: string, errorCode: number, errorMessage: string) => {
        this.recording = false;
        this.stopRecognitionTimer();
        this.listener?.onStateChange?.(false);
        void this.handleRecognitionFailure(`语音识别失败(${errorCode}): ${errorMessage}`);
      },
      onEvent: (_sessionId: string, _eventCode: number, _eventMessage: string) => {
      }
    });
  }

  private async requestMicrophonePermission(context: common.UIAbilityContext): Promise<void> {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']);
    const authResults = result.authResults ?? [];
    if (authResults.length > 0 && authResults[0] !== 0) {
      throw new Error('未获取麦克风权限');
    }
  }

  private formatBusinessError(err: BusinessError): string {
    return `${err.code ?? ''} ${err.message ?? ''}`.trim();
  }

  private startRecognitionTimer(): void {
    this.stopRecognitionTimer();
    this.timerId = setTimeout(() => {
      if (!this.recording) {
        return;
      }
      void this.handleRecognitionFailure('语音识别超时');
    }, this.recognitionTimeoutMs);
  }

  private stopRecognitionTimer(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  private async handleRecognitionFailure(reason: string): Promise<void> {
    if (this.retryCount < this.maxRetryCount) {
      this.retryCount += 1;
      this.listener?.onError?.(`${reason}，正在重试(${this.retryCount}/${this.maxRetryCount})`);
      await this.restartVoiceRecording();
      return;
    }

    this.listener?.onError?.(`${reason}，已达到最大重试次数，请重试`);
    await this.cancelVoiceRecording();
  }
}
