import pg from 'pg';
import { config } from '../config';

type Handler = () => void;

class NotificationBroadcaster {
  private client: pg.Client | null = null;
  private listeners = new Map<string, Set<Handler>>();
  private connected = false;

  async initialize(): Promise<void> {
    this.client = new pg.Client({ connectionString: config.database.url });
    await this.client.connect();
    this.connected = true;

    this.client.on('notification', (msg) => {
      const set = this.listeners.get(msg.channel);
      if (set) set.forEach((fn) => fn());
    });

    this.client.on('error', (err) => {
      console.error('[Broadcaster] pg error:', err.message);
      this.connected = false;
      setTimeout(() => this._reconnect(), 5000);
    });

    this.client.on('end', () => {
      if (this.connected) {
        this.connected = false;
        setTimeout(() => this._reconnect(), 5000);
      }
    });

    console.log('[Broadcaster] initialized');
  }

  private async _reconnect(): Promise<void> {
    try {
      const activeChannels = [...this.listeners.keys()];
      await this.initialize();
      for (const ch of activeChannels) {
        await this.client!.query(`LISTEN "${ch}"`);
      }
      console.log(
        `[Broadcaster] reconnected, re-listened to ${activeChannels.length} channels`,
      );
    } catch {
      console.error('[Broadcaster] reconnect failed — retrying in 5s');
      setTimeout(() => this._reconnect(), 5000);
    }
  }

  async subscribe(channel: string, handler: Handler): Promise<() => void> {
    if (!this.listeners.has(channel)) {
      this.listeners.set(channel, new Set());
      if (this.connected) {
        await this.client!.query(`LISTEN "${channel}"`);
      }
    }
    this.listeners.get(channel)!.add(handler);

    return async () => {
      const set = this.listeners.get(channel);
      if (!set) return;
      set.delete(handler);
      if (set.size === 0) {
        this.listeners.delete(channel);
        if (this.connected) {
          await this.client!.query(`UNLISTEN "${channel}"`);
        }
      }
    };
  }

  totalConnections(): number {
    let n = 0;
    this.listeners.forEach((s) => (n += s.size));
    return n;
  }
}

export const broadcaster = new NotificationBroadcaster();
