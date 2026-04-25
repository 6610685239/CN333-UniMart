/**
 * Property-Based Test สำหรับ Chat Notification — UniMart Iteration 2 Wiring
 *
 * Feature: unimart-iteration-2-wiring, Property 4: Chat Message สร้าง Notification ไปยังผู้รับที่ถูกต้อง
 *
 * ทดสอบว่าทุกข้อความที่ส่งสำเร็จ สร้าง notification 1 รายการ
 * โดย user_id เป็นฝ่ายที่ไม่ใช่ผู้ส่ง
 *
 * Validates: Requirements 5.1, 5.2
 */

const fc = require('fast-check');
const request = require('supertest');

// --- Mock notification service to capture calls ---
const mockCreateNotification = jest.fn().mockResolvedValue({ id: 'mock-notif-id' });

jest.mock('../services/notification.service', () => ({
  createNotification: (...args) => mockCreateNotification(...args),
  sendFcmNotification: jest.fn().mockResolvedValue({ success: true })
}));

// --- Supabase mock ---
const mockSupabaseFrom = jest.fn();
jest.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    from: (...args) => mockSupabaseFrom(...args)
  })
}));

// --- Prisma mock ---
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
    transaction: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      update: jest.fn()
    },
    users: { findUnique: jest.fn() },
    $transaction: jest.fn()
  }))
}));

jest.mock('axios');

const { app } = require('../server');

// ============================================
// Generators
// ============================================
const uuidArb = fc.uuid().filter(u => u.length > 0);
const senderRoleArb = fc.constantFrom('buyer', 'seller');
const messageContentArb = fc.string({ minLength: 1, maxLength: 200 }).filter(s => s.trim().length > 0);

beforeEach(() => {
  jest.clearAllMocks();
});

/**
 * Helper: set up Supabase mocks for chat_rooms (select) and chat_messages (insert)
 */
function setupSupabaseMocks({ roomData, roomError, insertData, insertError }) {
  mockSupabaseFrom.mockImplementation((table) => {
    if (table === 'chat_rooms') {
      return {
        select: jest.fn().mockReturnValue({
          eq: jest.fn().mockReturnValue({
            single: jest.fn().mockResolvedValue({ data: roomData, error: roomError })
          })
        })
      };
    }
    if (table === 'chat_messages') {
      return {
        insert: jest.fn().mockReturnValue({
          select: jest.fn().mockReturnValue({
            single: jest.fn().mockResolvedValue({ data: insertData, error: insertError })
          })
        })
      };
    }
    // Default fallback for other tables (e.g. notifications used by notification service mock)
    return {
      select: jest.fn().mockReturnValue({
        eq: jest.fn().mockReturnValue({
          single: jest.fn().mockResolvedValue({ data: null, error: null })
        })
      })
    };
  });
}

// ============================================
// Property 4: Chat Message สร้าง Notification ไปยังผู้รับที่ถูกต้อง
// ============================================
describe('Feature: unimart-iteration-2-wiring, Property 4: Chat Message สร้าง Notification ไปยังผู้รับที่ถูกต้อง', () => {
  /**
   * **Validates: Requirements 5.1, 5.2**
   *
   * For any chat message sent successfully, the system must create exactly 1 notification
   * where the recipientId is the other party (not the sender).
   * If sender == buyer_id → notify seller_id
   * If sender == seller_id → notify buyer_id
   */
  test('every successful chat message creates exactly one notification to the correct recipient', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb, // buyerId
        uuidArb, // sellerId
        senderRoleArb, // whether sender is buyer or seller
        messageContentArb, // message content
        async (buyerId, sellerId, senderRole, content) => {
          // Ensure buyer and seller are different
          fc.pre(buyerId !== sellerId);

          jest.clearAllMocks();

          const senderId = senderRole === 'buyer' ? buyerId : sellerId;
          const expectedRecipientId = senderRole === 'buyer' ? sellerId : buyerId;
          const roomId = 'room-' + buyerId.substring(0, 8);

          const createdMsg = {
            id: 'msg-' + Date.now(),
            room_id: roomId,
            sender_id: senderId,
            content: content,
            image_url: null,
            type: 'text',
            created_at: new Date().toISOString()
          };

          setupSupabaseMocks({
            roomData: { id: roomId, buyer_id: buyerId, seller_id: sellerId },
            roomError: null,
            insertData: createdMsg,
            insertError: null
          });

          const res = await request(app)
            .post('/api/chat/messages')
            .send({ roomId, senderId, content, type: 'text' });

          // The message send should succeed
          expect(res.status).toBe(201);

          // Wait a tick for fire-and-forget notification to complete
          await new Promise(resolve => setImmediate(resolve));

          // Assert: createNotification was called exactly once
          expect(mockCreateNotification).toHaveBeenCalledTimes(1);

          // Assert: notification was sent to the correct recipient
          const callArgs = mockCreateNotification.mock.calls[0];
          const recipientId = callArgs[0];
          const notifType = callArgs[1];

          expect(recipientId).toBe(expectedRecipientId);
          expect(notifType).toBe('chat_message');
        }
      ),
      { numRuns: 100 }
    );
  }, 30000);
});
