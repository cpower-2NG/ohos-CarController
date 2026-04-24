import { AiChatMessage, AiChatResult, AiChatService, AiControlDirective } from '../models/AiChatService';

interface ChatBubble {
  role: 'user' | 'assistant';
  text: string;
}

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
  @State apiUrl: string = 'https://maas-api.cn-huabei-1.xf-yun.com/v2';
  @State apiKey: string = '';
  @State modelId: string = '684';
  @State systemPrompt: string = DEFAULT_AI_PROMPT;
  @State userInput: string = '';
  @State isLoading: boolean = false;
  @State assistantReply: string = '这里显示大模型返回内容。';
  @State directiveText: string = '未识别到控制指令';
  @State rawResponse: string = '暂无原始响应';
  @State chatBubbles: ChatBubble[] = [
    {
      role: 'assistant',
      text: '请输入问题或控制意图，例如："让车前进一点"、"打开车灯"。'
    }
  ];

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
    return `${directive.label}（${directive.code}，${directive.category}）`;
  }

  private async sendPrompt(): Promise<void> {
    const apiKey = this.apiKey.trim();
    const prompt = this.userInput.trim();

    if (!apiKey || !prompt) {
      this.directiveText = !apiKey ? '请先填写 API Key' : '请输入对话内容';
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
        apiKey: apiKey,
        modelId: this.modelId,
        systemPrompt: this.systemPrompt,
        userInput: prompt,
        history: this.chatHistory
      });

      this.assistantReply = result.assistantText;
      this.rawResponse = result.rawResponse;
      this.directiveText = this.renderDirective(result.directive);
      this.appendBubble('assistant', result.assistantText);
      this.updateHistory('assistant', result.assistantText);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : `${err}`;
      this.assistantReply = `请求失败：${message}`;
      this.directiveText = '请求失败';
      this.rawResponse = message;
      this.appendBubble('assistant', `请求失败：${message}`);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Text('AI 智能对话控制')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1D2129')

          Text('通过 HTTP 接口调用讯飞 MaaS 模型，识别控制意图并输出标准指令标签。')
            .fontSize(13)
            .fontColor('#86909C')
            .lineHeight(20)
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Text('接口配置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          TextInput({ text: this.apiUrl, placeholder: 'HTTP 接口地址' })
            .height(44)
            .fontSize(14)
            .backgroundColor('#F7F8FA')
            .borderRadius(12)
            .onChange((value: string) => {
              this.apiUrl = value;
            })

          TextInput({ text: this.apiKey, placeholder: 'API Key' })
            .type(InputType.Password)
            .height(44)
            .fontSize(14)
            .backgroundColor('#F7F8FA')
            .borderRadius(12)
            .onChange((value: string) => {
              this.apiKey = value;
            })

          TextInput({ text: this.modelId, placeholder: '服务名称 / 模型编号' })
            .height(44)
            .fontSize(14)
            .backgroundColor('#F7F8FA')
            .borderRadius(12)
            .onChange((value: string) => {
              this.modelId = value;
            })
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('系统提示词')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          TextInput({ text: this.systemPrompt, placeholder: '系统提示词' })
            .height(120)
            .fontSize(14)
            .backgroundColor('#F7F8FA')
            .borderRadius(12)
            .onChange((value: string) => {
              this.systemPrompt = value;
            })
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('对话输入')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          TextInput({ text: this.userInput, placeholder: '输入问题或控制需求' })
            .height(44)
            .fontSize(14)
            .backgroundColor('#F7F8FA')
            .borderRadius(12)
            .onChange((value: string) => {
              this.userInput = value;
            })

          Button(this.isLoading ? '发送中...' : '发送')
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor('#165DFF')
            .borderRadius(12)
            .onClick(() => {
              void this.sendPrompt();
            })
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('解析结果')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          Text(this.directiveText)
            .fontSize(14)
            .fontColor('#165DFF')
            .fontWeight(FontWeight.Medium)

          Text(this.assistantReply)
            .fontSize(13)
            .fontColor('#4E5969')
            .lineHeight(20)

          Text('原始响应')
            .fontSize(12)
            .fontColor('#86909C')

          Text(this.rawResponse)
            .fontSize(11)
            .fontColor('#86909C')
            .lineHeight(18)
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('聊天记录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          ForEach(this.chatBubbles, (item: ChatBubble, index: number) => {
            Row() {
              Column({ space: 6 }) {
                Text(item.role === 'user' ? '我' : 'AI')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(item.role === 'user' ? '#165DFF' : '#67C23A')

                Text(item.text)
                  .fontSize(13)
                  .fontColor('#1D2129')
                  .lineHeight(20)
              }
              .padding(12)
              .backgroundColor(item.role === 'user' ? '#E8F3FF' : '#F6FFED')
              .borderRadius(14)
              .width('100%')
            }
            .padding({ bottom: 8 })
          }, (item: ChatBubble, index: number) => `${item.role}-${index}`)
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
      }
      .padding(16)
      .backgroundColor('#F2F3F5')
      .width('100%')
      .alignItems(HorizontalAlign.Stretch)
    }
    .scrollBar(BarState.Off)
  }
}
