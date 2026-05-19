import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.middleware';
import { broadcaster } from '../services/notificationBroadcaster';

const router = Router();
const MAX_SSE_CONNECTIONS = 500;
let activeConnections = 0;

router.get(
  '/',
  authMiddleware,
  async (req: Request, res: Response): Promise<void> => {
    if (activeConnections >= MAX_SSE_CONNECTIONS) {
      res.status(503).json({ error: 'SSE_CAPACITY_REACHED' });
      return;
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no'); // disable nginx buffering
    res.flushHeaders();

    activeConnections++;
    const companyId = req.companyId;
    const channel = `sync_company_${companyId}`;

    const heartbeat = setInterval(() => {
      if (!res.writableEnded) res.write(': heartbeat\n\n');
    }, 25_000);

    const unsubscribe = await broadcaster.subscribe(channel, () => {
      if (!res.writableEnded) res.write('data: ping\n\n');
    });

    res.write('data: connected\n\n');

    console.log(
      `[SSE] connect company=${companyId} total=${activeConnections}`,
    );

    req.on('close', () => {
      clearInterval(heartbeat);
      unsubscribe();
      activeConnections--;
      console.log(
        `[SSE] disconnect company=${companyId} total=${activeConnections}`,
      );
    });
  },
);

export { router as syncEventsRouter };
