import { AiChatMessage, AiChatResult, AiChatService, AiControlDirective } from '../models/AiChatService';

interface ChatBubble {
  role: 'user' | 'assistant';
  text: string;
}

const TEST_API_URL = 'https://maas-api.cn-huabei-1.xf-yun.com/v2';
const TEST_API_KEY = 'ae81d8d1b66a3d4520cd5ccf6efe429d:Y2Y5MTYxMTJkOTU3YTg2MjY4MmM5NGJh';
const TEST_MODEL_ID = '684';

const DEFAULT_AI_PROMPT = `
你是鸿蒙平衡车控制助手，回答要简洁。
当用户表达车辆控制意图时，请在回复末尾附加一个标准控制标签，标签必须使用英文大写方括号格式。
可用标签：
- [FORWARD] 前进
- [BACKWARD] 后退
- [LEFT] 左转
- [RIGHT] 右转
- [STOP] 停止
- [HEADLIGHT_ON] 车灯开启
- [HEADLIGHT_OFF] 车灯关闭
- [SEAT_VENT_ON] 座椅通风开启
- [SEAT_VENT_OFF] 座椅通风关闭
- [AMBIENT_OFF] 氛围灯关闭
- [AMBIENT_MIX] 氛围灯混色
- [AMBIENT_RED] 氛围灯红色
- [SEAT_NORMAL] 座椅标准模式
- [SEAT_COMFORT] 座椅舒适模式
- [SEAT_SPORT] 座椅运动模式
- [NAVIGATION] 导航
如果用户只是普通提问，则只做正常回答，不要编造标签。
`.trim();

@Component
export struct AiDialogPage {
  @State apiUrl: string = TEST_API_URL;
  @State apiKey: string = TEST_API_KEY;
  @State modelId: string = TEST_MODEL_ID;
  @State systemPrompt: string = DEFAULT_AI_PROMPT;
  @State userInput: string = '';
  @State isLoading: boolean = false;
  @State assistantReply: string = '这里显示大模型返回内容。';
  @State directiveText: string = '未识别到控制指令';
  @State chatBubbles: ChatBubble[] = [
    {
      role: 'assistant',
      text: '你好，我是 AI 助手。你可以直接说“让车前进一点”或“打开车灯”。'
    }
  ];
  @State showQuickActions: boolean = false;
  @State showDebugInfo: boolean = false;

  private aiService: AiChatService = new AiChatService();
  private chatHistory: AiChatMessage[] = [];

  private appendBubble(role: 'user' | 'assistant', text: string): void {
    this.chatBubbles = [...this.chatBubbles, { role, text }];
  }

  private updateHistory(role: 'user' | 'assistant', content: string): void {
    this.chatHistory = [...this.chatHistory, { role, content }].slice(-12);
  }

  private renderDirective(directive: AiControlDirective | null): string {
    if (!directive) {
      return '未识别到控制指令';
    }
    return `${directive.label}（${directive.code}）`;
  }

  private insertQuickPrompt(text: string): void {
    this.userInput = text;
    this.showQuickActions = false;
  }

  private async sendPrompt(): Promise<void> {
    const prompt = this.userInput.trim();
    if (!prompt) {
      this.directiveText = '请输入对话内容';
      return;
    }

    if (!this.apiKey.trim()) {
      this.directiveText = '请先填写 API Key';
      return;
    }

    this.isLoading = true;
    this.appendBubble('user', prompt);
    this.updateHistory('user', prompt);
    this.userInput = '';
    this.directiveText = '请求中...';

    try {
      const result: AiChatResult = await this.aiService.requestChat({
        apiUrl: this.apiUrl,
        apiKey: this.apiKey,
        modelId: this.modelId,
        systemPrompt: this.systemPrompt,
        userInput: prompt,
        history: this.chatHistory
      });

      this.assistantReply = result.assistantText;
      this.directiveText = this.renderDirective(result.directive);
      this.appendBubble('assistant', result.assistantText);
      this.updateHistory('assistant', result.assistantText);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : `${err}`;
      this.assistantReply = `请求失败：${message}`;
      this.directiveText = '请求失败';
      this.appendBubble('assistant', `请求失败：${message}`);
    } finally {
      this.isLoading = false;
    }
  }

  private buildQuickActionButton(title: string, prompt: string) {
    Button(title)
      .height(34)
      .fontSize(12)
      .fontColor('#165DFF')
      .backgroundColor('#E8F3FF')
      .borderRadius(18)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.insertQuickPrompt(prompt);
      })
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text('AI 对话')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D2129')

        Text('像普通聊天一样输入内容，系统会自动识别是否包含控制指令。')
          .fontSize(13)
          .fontColor('#86909C')
          .lineHeight(20)
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16 })

      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.chatBubbles, (item: ChatBubble, index: number) => {
            Row() {
              if (item.role === 'assistant') {
                Text('🤖')
                  .fontSize(16)
                  .width(28)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#E6F7E8')
                  .borderRadius(14)
                  .margin({ right: 8 })

                Text(item.text)
                  .fontSize(14)
                  .fontColor('#1D2129')
                  .lineHeight(20)
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor('#FFFFFF')
                  .borderRadius(16)
                  .border({ width: 1, color: '#E5E6EB' })
                  .maxLines(20)
                  .constraintSize({ minWidth: 50, maxWidth: '75%' })
              } else {
                Row() {
                  Text(item.text)
                    .fontSize(14)
                    .fontColor(Color.White)
                    .lineHeight(20)
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .backgroundColor('#165DFF')
                    .borderRadius(16)
                    .maxLines(20)
                    .constraintSize({ minWidth: 50, maxWidth: '75%' })

                  Text('👤')
                    .fontSize(16)
                    .width(28)
                    .height(28)
                    .textAlign(TextAlign.Center)
                    .backgroundColor('#DDE1E6')
                    .borderRadius(14)
                    .margin({ left: 8 })
                }
                .width('100%')
                .justifyContent(FlexAlign.End)
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }, (item: ChatBubble, index: number) => `${item.role}-${index}`)
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F2F2F7')

      if (this.showQuickActions) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            this.buildQuickActionButton('车控', '帮我控制车辆前进')
            this.buildQuickActionButton('车灯', '打开车灯')
            this.buildQuickActionButton('导航', '开始导航到目的地')
            this.buildQuickActionButton('车辆管理', '查看车辆状态')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      Column({ space: 10 }) {
        Row({ space: 8 }) {
          TextInput({ text: this.userInput, placeholder: '请输入您的问题...' })
            .height(44)
            .layoutWeight(1)
            .fontSize(15)
            .backgroundColor('#E5E5EA')
            .borderRadius(22)
            .border({ width: 0 })
            .padding({ left: 14, right: 14 })
            .onChange((value: string) => {
              this.userInput = value;
            })

          Button(this.isLoading ? '...' : '发送')
            .width(44)
            .height(44)
            .backgroundColor(this.isLoading || !this.userInput.trim() ? '#C8C8CD' : '#165DFF')
            .borderRadius(22)
            .enabled(!this.isLoading && !!this.userInput.trim())
            .onClick(() => {
              void this.sendPrompt();
            })

          Button('更多')
            .width(60)
            .height(44)
            .fontSize(13)
            .fontColor('#165DFF')
            .backgroundColor('#E8F3FF')
            .borderRadius(22)
            .onClick(() => {
              this.showQuickActions = !this.showQuickActions;
            })
        }

        if (this.showDebugInfo) {
          Column({ space: 6 }) {
            Text('调试信息')
              .fontSize(12)
              .fontColor('#86909C')

            Text(`指令识别：${this.directiveText}`)
              .fontSize(12)
              .fontColor('#4E5969')

            Text(`回复：${this.assistantReply}`)
              .fontSize(12)
              .fontColor('#4E5969')
              .lineHeight(18)
          }
          .padding({ left: 6, right: 6 })
        }
      }
      .width('100%')
      .padding({ top: 10, bottom: 16, left: 16, right: 16 })
      .backgroundColor(Color.White)
      .shadow({ radius: 0 })
      .borderRadius(0)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }
}
