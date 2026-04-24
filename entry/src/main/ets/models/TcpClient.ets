import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface TcpClientListener {
  onConnected?: () => void;
  onClosed?: (reason: string) => void;
  onError?: (message: string) => void;
  onMessage?: (message: string) => void;
}

interface ConnectOptions {
  retries?: number;
  timeoutMs?: number;
  retryDelayMs?: number;
}

export class TcpClient {
  private client: socket.TCPSocket | null = null;
  private listener: TcpClientListener | null = null;
  private connected: boolean = false;

  setListener(listener: TcpClientListener): void {
    this.listener = listener;
  }

  isConnected(): boolean {
    return this.connected;
  }

  async connectWithRetry(ip: string, port: number, options?: ConnectOptions): Promise<void> {
    const retries = options?.retries ?? 2;
    const timeoutMs = options?.timeoutMs ?? 4000;
    const retryDelayMs = options?.retryDelayMs ?? 800;

    let lastError: string = '连接失败';
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        await this.connectOnce(ip, port, timeoutMs);
        this.connected = true;
        return;
      } catch (err) {
        lastError = this.formatError(err);
        this.listener?.onError?.(`第 ${attempt + 1} 次连接失败: ${lastError}`);
        this.disconnect();

        if (attempt < retries) {
          await this.sleep(retryDelayMs);
        }
      }
    }

    throw new Error(lastError);
  }

  async sendMessage(message: string): Promise<void> {
    if (!this.client || !this.connected) {
      throw new Error('TCP 未连接');
    }
    await this.client.send({ data: message });
  }

  disconnect(): void {
    try {
      this.client?.close();
    } catch (err) {
      // Ignore close errors when disconnecting an unstable socket.
    }
    this.client = null;
    this.connected = false;
  }

  private async connectOnce(ip: string, port: number, timeoutMs: number): Promise<void> {
    this.disconnect();
    this.client = socket.constructTCPSocketInstance();
    this.setupEventListeners(this.client);

    const connectPromise = this.client.connect({
      address: {
        address: ip,
        port: port,
        family: 1
      }
    });

    const timeoutPromise = new Promise<void>((_, reject) => {
      setTimeout(() => {
        reject(new Error(`连接超时(${timeoutMs}ms)`));
      }, timeoutMs);
    });

    await Promise.race([connectPromise as Promise<void>, timeoutPromise]);
  }

  private setupEventListeners(client: socket.TCPSocket): void {
    client.on('connect', () => {
      this.connected = true;
      this.listener?.onConnected?.();
    });

    client.on('message', (value: socket.SocketInfo) => {
      const text = this.decodeMessage(value.message);
      this.listener?.onMessage?.(text);
    });

    client.on('close', () => {
      this.connected = false;
      this.listener?.onClosed?.('连接已关闭');
    });

    client.on('error', (err: BusinessError) => {
      this.connected = false;
      this.listener?.onError?.(`Socket错误: ${this.formatError(err)}`);
    });
  }

  private decodeMessage(buffer: ArrayBuffer): string {
    const dataView = new DataView(buffer);
    let result = '';
    for (let i = 0; i < dataView.byteLength; i++) {
      result += String.fromCharCode(dataView.getUint8(i));
    }
    return result;
  }

  private formatError(err: unknown): string {
    if (typeof err === 'object' && err !== null) {
      const businessError = err as BusinessError;
      if (businessError.code !== undefined || businessError.message !== undefined) {
        return `${businessError.code ?? ''} ${businessError.message ?? ''}`.trim();
      }
    }

    if (err instanceof Error) {
      return err.message;
    }

    return `${err}`;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(() => resolve(), ms);
    });
  }
}
