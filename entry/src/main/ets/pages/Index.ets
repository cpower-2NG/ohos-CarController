import { TcpClient } from '../models/TcpClient';

type CarAction = 'forward' | 'backward' | 'left' | 'right' | 'stop';

const CAR_COMMANDS: Record<CarAction, string> = {
  forward: '$1,0,0,0,0,0,0,0,0,0#',
  backward: '$2,0,0,0,0,0,0,0,0,0#',
  left: '$3,0,0,0,0,0,0,0,0,0#',
  right: '$4,0,0,0,0,0,0,0,0,0#',
  stop: '$0,0,0,0,0,0,0,0,0,0#'
};

@Component
struct VehicleControlPage {
  @State serverIp: string = '192.168.43.1';
  @State serverPort: string = '8080';
  @State connectionState: string = '未连接';
  @State connectionColor: string = '#F56C6C';
  @State lastCommand: string = '暂无指令';
  @State lastCommandCode: string = '未发送';
  @State lastServerMessage: string = '暂无回包';
  @State connectionTip: string = '输入平衡车服务端 IP 和端口，点击连接后即可发送控制指令。';
  @State speed: number = 35;

  private tcpClient: TcpClient = new TcpClient();
  private commandHistory: string[] = ['等待连接后发送指令'];

  aboutToAppear(): void {
    this.tcpClient.setListener({
      onConnected: () => {
        this.updateConnection(true, `已连接到 ${this.serverIp}:${this.serverPort}`);
      },
      onClosed: (reason: string) => {
        this.updateConnection(false, reason);
      },
      onError: (message: string) => {
        this.connectionTip = message;
      },
      onMessage: (message: string) => {
        this.lastServerMessage = message;
        this.commandHistory = [`${this.formatTime()}  ACK ${message}`, ...this.commandHistory].slice(0, 6);
      }
    });
  }

  aboutToDisappear(): void {
    this.tcpClient.disconnect();
  }

  private pushCommand(command: string, code?: string): void {
    this.lastCommand = command;
    this.lastCommandCode = code ?? '未发送';
    const detail = code ? `${command}  ${code}` : command;
    this.commandHistory = [`${this.formatTime()}  ${detail}`, ...this.commandHistory].slice(0, 6);
  }

  private formatTime(): string {
    const now = new Date();
    const pad = (value: number): string => `${value}`.padStart(2, '0');
    return `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
  }

  private updateConnection(connected: boolean, tip: string): void {
    this.connectionState = connected ? '已连接' : '未连接';
    this.connectionColor = connected ? '#67C23A' : '#F56C6C';
    this.connectionTip = tip;
  }

  private async connect(): Promise<void> {
    try {
      const port = Number(this.serverPort);
      if (Number.isNaN(port) || port <= 0 || port > 65535) {
        this.updateConnection(false, '端口不合法，请输入 1-65535');
        return;
      }

      this.updateConnection(false, '连接中...');
      await this.tcpClient.connectWithRetry(this.serverIp, port, {
        retries: 2,
        timeoutMs: 4000,
        retryDelayMs: 800
      });

      this.pushCommand(`连接成功 ${this.serverIp}:${this.serverPort}`);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : `${err}`;
      this.updateConnection(false, `连接失败：${message}`);
      this.pushCommand('连接失败');
    }
  }

  private disconnect(): void {
    this.tcpClient.disconnect();
    this.updateConnection(false, '已断开连接，可重新连接。');
    this.pushCommand('已断开连接');
  }

  private async sendAction(action: CarAction, label: string): Promise<void> {
    const code = CAR_COMMANDS[action];
    if (!this.tcpClient.isConnected()) {
      this.updateConnection(false, '请先连接平衡车服务端。');
      this.pushCommand(`${label} 发送失败`, code);
      return;
    }

    try {
      await this.tcpClient.sendMessage(`${code}\r\n`);
      this.pushCommand(label, code);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : `${err}`;
      this.updateConnection(false, `发送失败：${message}`);
      this.pushCommand(`${label} 发送失败`, code);
    }
  }

  @Builder
  directionButton(label: string, action: CarAction) {
    Button(label)
      .layoutWeight(1)
      .height(52)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor('#165DFF')
      .borderRadius(16)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          void this.sendAction(action, label);
        }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          void this.sendAction('stop', '停止');
        }
      })
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 10 }) {
          Text('车辆运动控制')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1D2129')

          Text('方向键按下发送方向指令，松开发送停止指令。')
            .fontSize(13)
            .fontColor('#86909C')
            .lineHeight(20)
        }
        .alignItems(HorizontalAlign.Start)

        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text('连接状态').fontSize(12).fontColor('#86909C')
            Text(this.connectionState)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.connectionColor)
          }
          .layoutWeight(1)
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(18)

          Column({ space: 6 }) {
            Text('当前速度').fontSize(12).fontColor('#86909C')
            Text(`${this.speed}%`)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#165DFF')
          }
          .layoutWeight(1)
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(18)
        }

        Column({ space: 12 }) {
          Text('连接参数')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          Text(this.connectionTip)
            .fontSize(12)
            .fontColor('#86909C')

          Row({ space: 12 }) {
            TextInput({ text: this.serverIp, placeholder: '服务端 IP' })
              .layoutWeight(2)
              .height(44)
              .fontSize(14)
              .backgroundColor('#F7F8FA')
              .borderRadius(12)
              .onChange((value: string) => {
                this.serverIp = value;
              })

            TextInput({ text: this.serverPort, placeholder: '端口' })
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .backgroundColor('#F7F8FA')
              .borderRadius(12)
              .type(InputType.Number)
              .onChange((value: string) => {
                this.serverPort = value;
              })
          }

          Row({ space: 12 }) {
            Button('连接')
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor('#165DFF')
              .borderRadius(12)
              .onClick(() => {
                void this.connect();
              })

            Button('断开')
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontColor('#165DFF')
              .backgroundColor('#E8F3FF')
              .borderRadius(12)
              .onClick(() => this.disconnect())
          }
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('车辆运动控制')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          Column({ space: 12 }) {
            Button('前进 ↑')
              .width('44%')
              .height(52)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#165DFF')
              .borderRadius(16)
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  void this.sendAction('forward', '前进');
                }
                if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  void this.sendAction('stop', '停止');
                }
              })

            Row({ space: 12 }) {
              this.directionButton('左转 ↰', 'left')
              this.directionButton('右转 ↱', 'right')
            }

            Button('后退 ↓')
              .width('44%')
              .height(52)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#165DFF')
              .borderRadius(16)
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  void this.sendAction('backward', '后退');
                }
                if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  void this.sendAction('stop', '停止');
                }
              })

            Button('急停')
              .width('44%')
              .height(50)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#F56C6C')
              .backgroundColor('#FFF1F0')
              .borderRadius(16)
              .onClick(() => {
                void this.sendAction('stop', '停止');
              })
          }
          .alignItems(HorizontalAlign.Center)
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('服务端回包')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          Text(this.lastServerMessage)
            .fontSize(14)
            .fontColor('#165DFF')
            .fontWeight(FontWeight.Medium)
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('速度调节')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          Slider({ value: this.speed, min: 0, max: 100, step: 1 })
            .blockColor('#165DFF')
            .trackColor('#E5E6EB')
            .selectedColor('#165DFF')
            .showTips(true)
            .onChange((value: number) => {
              this.speed = value;
            })

          Text(`当前速度档位：${this.speed}%`)
            .fontSize(12)
            .fontColor('#86909C')
        }
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)

        Column({ space: 12 }) {
          Text('最近指令')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2129')

          Text(this.lastCommand)
            .fontSize(14)
            .fontColor('#165DFF')
            .fontWeight(FontWeight.Medium)

          Text(this.lastCommandCode)
            .fontSize(12)
            .fontColor('#86909C')

          ForEach(this.commandHistory, (item: string) => {
            Text(item)
              .fontSize(12)
              .fontColor('#4E5969')
              .padding({ top: 2, bottom: 2 })
          }, (item: string) => item)
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

@Component
struct PlaceholderPage {
  @Prop title: string;
  @Prop description: string;

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2129')

      Text(this.description)
        .fontSize(14)
        .fontColor('#86909C')
        .lineHeight(20)

      Text('后续会在这里继续补齐地图、AI对话、语音识别与设置页面。')
        .fontSize(12)
        .fontColor('#4E5969')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(24)
    .backgroundColor('#F2F3F5')
  }
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  @Builder
  tabBarItem(icon: string, label: string, index: number) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(20)

      Text(label)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? '#165DFF' : '#86909C')
    }
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        VehicleControlPage()
      }
      .tabBar(this.tabBarItem('🚗', '车控', 0))

      TabContent() {
        PlaceholderPage({
          title: '地图导航',
          description: '这里预留地图导航页面入口。'
        })
      }
      .tabBar(this.tabBarItem('🗺️', '地图', 1))

      TabContent() {
        PlaceholderPage({
          title: 'AI 对话',
          description: '这里预留 AI 智能对话页面入口。'
        })
      }
      .tabBar(this.tabBarItem('🤖', 'AI', 2))

      TabContent() {
        PlaceholderPage({
          title: '设置',
          description: '这里预留设备、账号与调试配置页面入口。'
        })
      }
      .tabBar(this.tabBarItem('⚙️', '设置', 3))
    }
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .barMode(BarMode.Fixed)
    .backgroundColor('#F2F3F5')
    .width('100%')
    .height('100%')
  }
}
