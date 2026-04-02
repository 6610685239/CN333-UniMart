/**
 * Unit Tests สำหรับ Notification System — UniMart Iteration 2
 *
 * Task 8.1: GET /api/notifications/:userId — ดึงรายการแจ้งเตือน (Req 5.3)
 * Task 8.2: PATCH /api/notifications/:id/read — อ่านแจ้งเตือน (Req 5.3, 5.4)
 * Task 8.3: GET /api/notifications/:userId/unread-count — จำนวนยังไม่อ่าน (Req 5.6)
 * Task 8.4: PATCH /api/notifications/:userId/settings — ตั้งค่าแจ้งเตือน (Req 5.5)
 * Task 8.5: Notification Helper — createNotification (Req 5.1, 5.2, 5.5)
 */

const request = require('supertest');

// --- Supabase mock setup ---
const mockSupabaseFrom = jest.fn();

jest.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    from: (...args) => mockSupabaseFrom(...args)
  })
}));

// --- Prisma mock setup ---
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: { findMany: jest.fn().mockResolvedValue([]) },
    product: { findMany: jest.fn(), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
    transaction: { findUnique: jest.fn(), create: jest.fn(), findMany: jest.fn(), update: jest.fn() },
    review: { create: jest.fn(), findMany: jest.fn(), aggregate: jest.fn() },
    meetingPoint: { findMany: jest.fn() },
    users: { findUnique: jest.fn() },
    $transaction: jest.fn()
  }))
}));

jest.mock('axios');

// Helper to build chainable Supabase mock
function buildChain(overrides = {}) {
  const chain = {
    select: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    neq: jest.fn().mockReturnThis(),
    order: jest.fn().mockReturnThis(),
    single: jest.fn().mockResolvedValue({ data: null, error: null }),
    range: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    ...overrides
  };
  // Make chainable methods return chain
  for (const key of Object.keys(chain)) {
    if (typeof chain[key] === 'function' && !overrides[key]) {
      // keep overrides as-is
    }
  }
  return chain;
}

const { app, createNotification, sendFcmNotification } = require('../server');

beforeEach(() => {
  jest.clearAllMocks();
});

// ==========================================
// Task 8.1: GET /api/notifications/:userId
// ==========================================
describe('GET /api/notifications/:userId', () => {
  test('returns notifications sorted by createdAt descending (Req 5.3)', async () => {
    const mockNotifications = [
      { id: 'n1', user_id: 'user-1', type: 'chat_message', title: 'ข้อความใหม่', body: 'สวัสดี', data: {}, is_read: false, created_at: '2025-01-02T00:00:00Z' },
      { id: 'n2', user_id: 'user-1', type: 'transaction_update', title: 'สถานะเปลี่ยน', body: 'ยืนยันแล้ว', data: {}, is_read: true, created_at: '2025-01-01T00:00:00Z' }
    ];

    const chain = buildChain();
    chain.order.mockReturnValue({ data: mockNotifications, error: null });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).get('/api/notifications/user-1');

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
    expect(res.body[0].id).toBe('n1');
    expect(res.body[0].isRead).toBe(false);
    expect(res.body[1].id).toBe('n2');
    expect(res.body[1].isRead).toBe(true);
  });

  test('returns empty array when user has no notifications', async () => {
    const chain = buildChain();
    chain.order.mockReturnValue({ data: [], error: null });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).get('/api/notifications/user-no-notif');

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('returns 500 on supabase error', async () => {
    const chain = buildChain();
    chain.order.mockReturnValue({ data: null, error: { message: 'DB error' } });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).get('/api/notifications/user-1');

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });

  test('maps snake_case to camelCase in response', async () => {
    const chain = buildChain();
    chain.order.mockReturnValue({
      data: [{ id: 'n1', user_id: 'u1', type: 'chat_message', title: 'T', body: 'B', data: { roomId: '123' }, is_read: false, created_at: '2025-01-01T00:00:00Z' }],
      error: null
    });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).get('/api/notifications/u1');

    expect(res.status).toBe(200);
    expect(res.body[0]).toHaveProperty('userId', 'u1');
    expect(res.body[0]).toHaveProperty('isRead', false);
    expect(res.body[0]).toHaveProperty('createdAt');
    expect(res.body[0]).not.toHaveProperty('user_id');
    expect(res.body[0]).not.toHaveProperty('is_read');
  });
});

// ==========================================
// Task 8.2: PATCH /api/notifications/:id/read
// ==========================================
describe('PATCH /api/notifications/:id/read', () => {
  test('marks notification as read (Req 5.3, 5.4)', async () => {
    const updatedNotif = { id: 'n1', user_id: 'u1', type: 'chat_message', title: 'T', body: 'B', data: {}, is_read: true, created_at: '2025-01-01T00:00:00Z' };

    const chain = buildChain();
    chain.single.mockResolvedValue({ data: updatedNotif, error: null });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).patch('/api/notifications/n1/read');

    expect(res.status).toBe(200);
    expect(res.body.isRead).toBe(true);
    expect(res.body.id).toBe('n1');
  });

  test('returns 404 when notification not found', async () => {
    const chain = buildChain();
    chain.single.mockResolvedValue({ data: null, error: { code: 'PGRST116', message: 'not found' } });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).patch('/api/notifications/nonexistent/read');

    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test('returns 500 on supabase error', async () => {
    const chain = buildChain();
    chain.single.mockResolvedValue({ data: null, error: { code: 'OTHER', message: 'DB error' } });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).patch('/api/notifications/n1/read');

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

// ==========================================
// Task 8.3: GET /api/notifications/:userId/unread-count
// ==========================================
describe('GET /api/notifications/:userId/unread-count', () => {
  test('returns count of unread notifications (Req 5.6)', async () => {
    // The route chains: .select().eq('user_id', userId).eq('is_read', false)
    // We need the second .eq() to return the final result
    const chain = buildChain();
    let eqCallCount = 0;
    chain.eq.mockImplementation(() => {
      eqCallCount++;
      if (eqCallCount >= 2) {
        return { count: 5, error: null };
      }
      return chain;
    });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).get('/api/notifications/user-1/unread-count');

    expect(res.status).toBe(200);
    expect(res.body.unreadCount).toBe(5);
  });

  test('returns 0 when no unread notifications', async () => {
    const chain = buildChain();
    let eqCallCount = 0;
    chain.eq.mockImplementation(() => {
      eqCallCount++;
      if (eqCallCount >= 2) {
        return { count: 0, error: null };
      }
      return chain;
    });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).get('/api/notifications/user-1/unread-count');

    expect(res.status).toBe(200);
    expect(res.body.unreadCount).toBe(0);
  });

  test('returns 500 on supabase error', async () => {
    const chain = buildChain();
    let eqCallCount = 0;
    chain.eq.mockImplementation(() => {
      eqCallCount++;
      if (eqCallCount >= 2) {
        return { count: null, error: { message: 'DB error' } };
      }
      return chain;
    });
    mockSupabaseFrom.mockReturnValue(chain);

    const res = await request(app).get('/api/notifications/user-1/unread-count');

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

// ==========================================
// Task 8.4: PATCH /api/notifications/:userId/settings
// ==========================================
describe('PATCH /api/notifications/:userId/settings', () => {
  test('creates new settings when none exist (Req 5.5)', async () => {
    const newSettings = { id: 's1', user_id: 'user-1', push_enabled: true, chat_notifications: true, transaction_notifications: false, fcm_token: 'token123', updated_at: '2025-01-01T00:00:00Z' };

    // First call: check existing (notifications table for other routes may be called first)
    // The route calls from('notification_settings') twice: once to check existing, once to insert
    let callCount = 0;
    mockSupabaseFrom.mockImplementation((table) => {
      callCount++;
      if (table === 'notification_settings') {
        const chain = buildChain();
        if (callCount === 1) {
          // First call: select existing → not found
          chain.single.mockResolvedValue({ data: null, error: null });
        } else {
          // Second call: insert new
          chain.single.mockResolvedValue({ data: newSettings, error: null });
        }
        return chain;
      }
      return buildChain();
    });

    const res = await request(app)
      .patch('/api/notifications/user-1/settings')
      .send({ push_enabled: true, chat_notifications: true, transaction_notifications: false, fcm_token: 'token123' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('user_id', 'user-1');
  });

  test('updates existing settings (Req 5.5)', async () => {
    const updatedSettings = { id: 's1', user_id: 'user-1', push_enabled: false, chat_notifications: true, transaction_notifications: true, fcm_token: 'new-token', updated_at: '2025-01-02T00:00:00Z' };

    let callCount = 0;
    mockSupabaseFrom.mockImplementation((table) => {
      callCount++;
      if (table === 'notification_settings') {
        const chain = buildChain();
        if (callCount === 1) {
          // First call: select existing → found
          chain.single.mockResolvedValue({ data: { id: 's1' }, error: null });
        } else {
          // Second call: update
          chain.single.mockResolvedValue({ data: updatedSettings, error: null });
        }
        return chain;
      }
      return buildChain();
    });

    const res = await request(app)
      .patch('/api/notifications/user-1/settings')
      .send({ push_enabled: false, fcm_token: 'new-token' });

    expect(res.status).toBe(200);
  });

  test('returns 500 on supabase error', async () => {
    mockSupabaseFrom.mockImplementation(() => {
      const chain = buildChain();
      chain.single.mockResolvedValue({ data: null, error: { message: 'DB error' } });
      return chain;
    });

    const res = await request(app)
      .patch('/api/notifications/user-1/settings')
      .send({ push_enabled: false });

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

// ==========================================
// Task 8.5: createNotification helper
// ==========================================
describe('createNotification helper', () => {
  test('always saves notification to database (Req 5.1, 5.2)', async () => {
    const mockNotif = { id: 'n1', user_id: 'u1', type: 'chat_message', title: 'T', body: 'B', data: {}, is_read: false, created_at: '2025-01-01T00:00:00Z' };

    let callCount = 0;
    mockSupabaseFrom.mockImplementation((table) => {
      callCount++;
      const chain = buildChain();
      if (table === 'notifications') {
        chain.single.mockResolvedValue({ data: mockNotif, error: null });
      } else if (table === 'notification_settings') {
        // No settings → push_enabled defaults to true but no fcm_token
        chain.single.mockResolvedValue({ data: null, error: null });
      }
      return chain;
    });

    const result = await createNotification('u1', 'chat_message', 'T', 'B', {});

    expect(result).toEqual(mockNotif);
  });

  test('saves notification even when push is disabled (Req 5.5)', async () => {
    const mockNotif = { id: 'n2', user_id: 'u2', type: 'transaction_update', title: 'T', body: 'B', data: {}, is_read: false, created_at: '2025-01-01T00:00:00Z' };

    mockSupabaseFrom.mockImplementation((table) => {
      const chain = buildChain();
      if (table === 'notifications') {
        chain.single.mockResolvedValue({ data: mockNotif, error: null });
      } else if (table === 'notification_settings') {
        chain.single.mockResolvedValue({
          data: { push_enabled: false, fcm_token: 'token', chat_notifications: true, transaction_notifications: true },
          error: null
        });
      }
      return chain;
    });

    const result = await createNotification('u2', 'transaction_update', 'T', 'B', {});

    expect(result).toEqual(mockNotif);
    expect(result.id).toBe('n2');
  });

  test('throws error when insert fails', async () => {
    mockSupabaseFrom.mockImplementation(() => {
      const chain = buildChain();
      chain.single.mockResolvedValue({ data: null, error: { message: 'Insert failed' } });
      return chain;
    });

    await expect(createNotification('u1', 'chat_message', 'T', 'B', {})).rejects.toEqual({ message: 'Insert failed' });
  });
});
