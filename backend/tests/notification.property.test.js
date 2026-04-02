/**
 * Property-Based Tests สำหรับ Notification System — UniMart Iteration 2
 *
 * ใช้ fast-check สำหรับ property-based testing
 * Mock Supabase เพื่อ test logic ภายใน
 *
 * Validates: Requirements 5.2, 5.3, 5.5, 5.6
 */

const fc = require('fast-check');
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
    product: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn()
    },
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
  return chain;
}

const { app, createNotification } = require('../server');

// ============================================
// Generators
// ============================================
const uuidArb = fc.uuid().filter(u => u.length > 0);
const notifTypeArb = fc.constantFrom('chat_message', 'transaction_update', 'review_received');
const titleArb = fc.string({ minLength: 1, maxLength: 100 }).filter(s => s.trim().length > 0 && !s.includes('\x00'));
const bodyArb = fc.string({ minLength: 1, maxLength: 200 }).filter(s => s.trim().length > 0 && !s.includes('\x00'));

beforeEach(() => {
  jest.clearAllMocks();
});

// ============================================
// Property 20: แจ้งเตือนเมื่อสถานะธุรกรรมเปลี่ยน
// (test.todo — transaction endpoints don't call createNotification yet)
// ============================================
describe('Feature: unimart-iteration-2, Property 20: แจ้งเตือนเมื่อสถานะธุรกรรมเปลี่ยน', () => {
  /**
   * Validates: Requirements 5.2
   * For any transaction status change, a notification should be created
   * for the relevant user (buyer and/or seller).
   *
   * NOTE: Currently transaction endpoints have TODO placeholders for
   * createNotification calls. This test is marked as todo until those
   * are wired up.
   */
  test.todo('transaction status change creates notification for relevant user — TODO: wire createNotification into transaction endpoints');
});

// ============================================
// Property 21: แจ้งเตือนเรียงจากใหม่ไปเก่า
// ============================================
describe('Feature: unimart-iteration-2, Property 21: แจ้งเตือนเรียงจากใหม่ไปเก่า', () => {
  /**
   * Validates: Requirements 5.3
   * For any user with multiple notifications, GET /api/notifications/:userId
   * should return them sorted by createdAt descending (newest first).
   */
  test('notifications are returned sorted by createdAt descending', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        fc.integer({ min: 2, max: 15 }),
        async (userId, count) => {
          // Generate notifications with sequential timestamps
          const baseTime = new Date('2025-01-01T00:00:00Z').getTime();
          const notifications = [];
          for (let i = 0; i < count; i++) {
            notifications.push({
              id: `notif-${i}`,
              user_id: userId,
              type: 'chat_message',
              title: `Title ${i}`,
              body: `Body ${i}`,
              data: {},
              is_read: i % 2 === 0,
              created_at: new Date(baseTime + i * 60000).toISOString()
            });
          }

          // Supabase returns them sorted descending (as the API requests via .order())
          const sortedDesc = [...notifications].sort(
            (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          );

          const chain = buildChain();
          chain.order.mockReturnValue({ data: sortedDesc, error: null });
          mockSupabaseFrom.mockReturnValue(chain);

          const res = await request(app).get(`/api/notifications/${userId}`);

          expect(res.status).toBe(200);
          expect(res.body.length).toBe(count);

          // Verify descending order
          for (let i = 1; i < res.body.length; i++) {
            const prev = new Date(res.body[i - 1].createdAt).getTime();
            const curr = new Date(res.body[i].createdAt).getTime();
            expect(prev).toBeGreaterThanOrEqual(curr);
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ============================================
// Property 22: ปิด Push แต่ยังบันทึกแจ้งเตือน
// ============================================
describe('Feature: unimart-iteration-2, Property 22: ปิด Push แต่ยังบันทึกแจ้งเตือน', () => {
  /**
   * Validates: Requirements 5.5
   * For any user with push_enabled = false, createNotification should still
   * save the notification to the database (is_read, content intact) but not send push.
   */
  test('notification is saved to DB even when push is disabled', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        notifTypeArb,
        titleArb,
        bodyArb,
        async (userId, type, title, body) => {
          const mockNotif = {
            id: 'notif-' + Math.random().toString(36).slice(2),
            user_id: userId,
            type,
            title,
            body,
            data: {},
            is_read: false,
            created_at: new Date().toISOString()
          };

          mockSupabaseFrom.mockImplementation((table) => {
            const chain = buildChain();
            if (table === 'notifications') {
              // insert → select → single returns the saved notification
              chain.single.mockResolvedValue({ data: mockNotif, error: null });
            } else if (table === 'notification_settings') {
              // User has push_enabled = false
              chain.single.mockResolvedValue({
                data: {
                  push_enabled: false,
                  fcm_token: 'some-token',
                  chat_notifications: true,
                  transaction_notifications: true
                },
                error: null
              });
            }
            return chain;
          });

          const result = await createNotification(userId, type, title, body, {});

          // Notification must be saved with correct data
          expect(result).toBeDefined();
          expect(result.user_id).toBe(userId);
          expect(result.type).toBe(type);
          expect(result.title).toBe(title);
          expect(result.body).toBe(body);
          expect(result.is_read).toBe(false);
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ============================================
// Property 23: จำนวน Badge ตรงกับแจ้งเตือนที่ยังไม่อ่าน
// ============================================
describe('Feature: unimart-iteration-2, Property 23: จำนวน Badge ตรงกับแจ้งเตือนที่ยังไม่อ่าน', () => {
  /**
   * Validates: Requirements 5.6
   * For any user, the unread count from GET /api/notifications/:userId/unread-count
   * should equal the number of notifications with is_read = false.
   */
  test('unread count matches number of is_read=false notifications', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        fc.array(fc.boolean(), { minLength: 0, maxLength: 20 }),
        async (userId, readStatuses) => {
          const unreadCount = readStatuses.filter(r => !r).length;

          const chain = buildChain();
          let eqCallCount = 0;
          chain.eq.mockImplementation(() => {
            eqCallCount++;
            if (eqCallCount >= 2) {
              return { count: unreadCount, error: null };
            }
            return chain;
          });
          mockSupabaseFrom.mockReturnValue(chain);

          const res = await request(app).get(`/api/notifications/${userId}/unread-count`);

          expect(res.status).toBe(200);
          expect(res.body.unreadCount).toBe(unreadCount);
        }
      ),
      { numRuns: 100 }
    );
  });
});
