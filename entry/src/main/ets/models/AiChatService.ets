import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

export type AiChatRole = 'system' | 'user' | 'assistant';

export interface AiChatMessage {
  role: AiChatRole;
  content: string;
}

export interface AiControlDirective {
  code: string;
  label: string;
  category: 'car' | 'light' | 'seat' | 'ambient' | 'navigation' | 'unknown';
}

export interface AiChatResult {
  rawResponse: string;
  assistantText: string;
  directive: AiControlDirective | null;
}

export interface AiChatRequest {
  apiUrl: string;
  apiKey: string;
  modelId: string;
  systemPrompt: string;
  userInput: string;
  history?: AiChatMessage[];
}

const CONTROL_DIRECTIVE_MAP: Record<string, AiControlDirective> = {
  FORWARD: { code: 'FORWARD', label: '前进', category: 'car' },
  BACKWARD: { code: 'BACKWARD', label: '后退', category: 'car' },
  LEFT: { code: 'LEFT', label: '左转', category: 'car' },
  RIGHT: { code: 'RIGHT', label: '右转', category: 'car' },
  STOP: { code: 'STOP', label: '停止', category: 'car' },
  HEADLIGHT_ON: { code: 'HEADLIGHT_ON', label: '车灯开启', category: 'light' },
  HEADLIGHT_OFF: { code: 'HEADLIGHT_OFF', label: '车灯关闭', category: 'light' },
  SEAT_VENT_ON: { code: 'SEAT_VENT_ON', label: '座椅通风开启', category: 'seat' },
  SEAT_VENT_OFF: { code: 'SEAT_VENT_OFF', label: '座椅通风关闭', category: 'seat' },
  AMBIENT_OFF: { code: 'AMBIENT_OFF', label: '氛围灯关闭', category: 'ambient' },
  AMBIENT_MIX: { code: 'AMBIENT_MIX', label: '氛围灯混色', category: 'ambient' },
  AMBIENT_RED: { code: 'AMBIENT_RED', label: '氛围灯红色', category: 'ambient' },
  SEAT_NORMAL: { code: 'SEAT_NORMAL', label: '座椅标准模式', category: 'seat' },
  SEAT_COMFORT: { code: 'SEAT_COMFORT', label: '座椅舒适模式', category: 'seat' },
  SEAT_SPORT: { code: 'SEAT_SPORT', label: '座椅运动模式', category: 'seat' },
  NAVIGATION: { code: 'NAVIGATION', label: '导航', category: 'navigation' }
};

export class AiChatService {
  async requestChat(request: AiChatRequest): Promise<AiChatResult> {
    const httpRequest = http.createHttp();
    const url = this.normalizeUrl(request.apiUrl);
    const payload = this.buildRequestBody(request);

    try {
      const rawResponse = await new Promise<string>((resolve, reject) => {
        httpRequest.request(
          url,
          {
            method: http.RequestMethod.POST,
            header: {
              Authorization: request.apiKey,
              'Content-Type': 'application/json'
            },
            extraData: JSON.stringify(payload),
            expectDataType: http.HttpDataType.STRING,
            usingCache: false,
            connectTimeout: 60000,
            readTimeout: 60000
          },
          (err: BusinessError | undefined, data: http.HttpResponse) => {
            if (err) {
              reject(new Error(this.formatError(err)));
              return;
            }

            if (data.responseCode !== 200) {
              reject(new Error(`HTTP ${data.responseCode}`));
              return;
            }

            resolve((data.result ?? '').toString());
          }
        );
      });

      const assistantText = this.extractAssistantText(rawResponse);
      return {
        rawResponse,
        assistantText,
        directive: this.parseDirective(assistantText)
      };
    } finally {
      httpRequest.destroy();
    }
  }

  private buildRequestBody(request: AiChatRequest): object {
    const messages: AiChatMessage[] = [
      {
        role: 'system',
        content: request.systemPrompt
      },
      ...(request.history ?? []).slice(-10),
      {
        role: 'user',
        content: request.userInput
      }
    ];

    return {
      model: request.modelId || '684',
      messages,
      temperature: 0.4,
      top_p: 0.8,
      max_tokens: 1024,
      stream: false
    };
  }

  private normalizeUrl(apiUrl: string): string {
    const trimmed = apiUrl.trim().replace(/\/+$/, '');
    if (trimmed.endsWith('/chat/completions')) {
      return trimmed;
    }
    return `${trimmed}/chat/completions`;
  }

  private extractAssistantText(rawResponse: string): string {
    try {
      const response = JSON.parse(rawResponse);
      const content = response?.choices?.[0]?.message?.content;
      if (typeof content === 'string' && content.trim().length > 0) {
        return content.trim();
      }

      const deltaContent = response?.choices?.[0]?.delta?.content;
      if (typeof deltaContent === 'string' && deltaContent.trim().length > 0) {
        return deltaContent.trim();
      }

      if (typeof response?.output_text === 'string' && response.output_text.trim().length > 0) {
        return response.output_text.trim();
      }

      if (typeof response?.text === 'string' && response.text.trim().length > 0) {
        return response.text.trim();
      }
    } catch (err) {
      // Fall back to raw response parsing below.
    }

    return rawResponse;
  }

  private parseDirective(text: string): AiControlDirective | null {
    const upperText = text.toUpperCase();
    const tagMatch = upperText.match(/\[([A-Z_]+)\]/);
    if (tagMatch && CONTROL_DIRECTIVE_MAP[tagMatch[1]]) {
      return CONTROL_DIRECTIVE_MAP[tagMatch[1]];
    }

    if (upperText.includes('前进') || upperText.includes('FORWARD')) {
      return CONTROL_DIRECTIVE_MAP.FORWARD;
    }
    if (upperText.includes('后退') || upperText.includes('BACKWARD')) {
      return CONTROL_DIRECTIVE_MAP.BACKWARD;
    }
    if (upperText.includes('左转') || upperText.includes('LEFT')) {
      return CONTROL_DIRECTIVE_MAP.LEFT;
    }
    if (upperText.includes('右转') || upperText.includes('RIGHT')) {
      return CONTROL_DIRECTIVE_MAP.RIGHT;
    }
    if (upperText.includes('停止') || upperText.includes('STOP')) {
      return CONTROL_DIRECTIVE_MAP.STOP;
    }
    if (upperText.includes('车灯开启') || upperText.includes('HEADLIGHT_ON')) {
      return CONTROL_DIRECTIVE_MAP.HEADLIGHT_ON;
    }
    if (upperText.includes('车灯关闭') || upperText.includes('HEADLIGHT_OFF')) {
      return CONTROL_DIRECTIVE_MAP.HEADLIGHT_OFF;
    }
    if (upperText.includes('通风开启') || upperText.includes('SEAT_VENT_ON')) {
      return CONTROL_DIRECTIVE_MAP.SEAT_VENT_ON;
    }
    if (upperText.includes('通风关闭') || upperText.includes('SEAT_VENT_OFF')) {
      return CONTROL_DIRECTIVE_MAP.SEAT_VENT_OFF;
    }
    if (upperText.includes('氛围灯关闭') || upperText.includes('AMBIENT_OFF')) {
      return CONTROL_DIRECTIVE_MAP.AMBIENT_OFF;
    }
    if (upperText.includes('氛围灯混色') || upperText.includes('AMBIENT_MIX')) {
      return CONTROL_DIRECTIVE_MAP.AMBIENT_MIX;
    }
    if (upperText.includes('氛围灯红色') || upperText.includes('AMBIENT_RED')) {
      return CONTROL_DIRECTIVE_MAP.AMBIENT_RED;
    }
    if (upperText.includes('标准模式') || upperText.includes('SEAT_NORMAL')) {
      return CONTROL_DIRECTIVE_MAP.SEAT_NORMAL;
    }
    if (upperText.includes('舒适模式') || upperText.includes('SEAT_COMFORT')) {
      return CONTROL_DIRECTIVE_MAP.SEAT_COMFORT;
    }
    if (upperText.includes('运动模式') || upperText.includes('SEAT_SPORT')) {
      return CONTROL_DIRECTIVE_MAP.SEAT_SPORT;
    }
    if (upperText.includes('导航') || upperText.includes('NAVIGATION')) {
      return CONTROL_DIRECTIVE_MAP.NAVIGATION;
    }

    return null;
  }

  private formatError(err: BusinessError): string {
    return `${err.code ?? ''} ${err.message ?? ''}`.trim();
  }
}
