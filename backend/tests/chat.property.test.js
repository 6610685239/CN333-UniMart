/**
 * Property-Based Tests สำหรับ Chat System — UniMart Iteration 2
 * 
 * ใช้ fast-check สำหรับ property-based testing
 * Mock Supabase และ Prisma เพื่อ test logic ภายใน
 * 
 * Validates: Requirements 1.1, 1.3, 1.4, 1.6, 1.7
 */

const fc = require('fast-check');
const request = require('supertest');

// Mock Supabase ก่อน require server
const mockSupabaseFrom = jest.fn();
jest.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    from: mockSupabaseFrom
  })
}));

// Mock Prisma
const mockUsersFindUnique = jest.fn();
const mockProductFindUnique = jest.fn();
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: { findMany: jest.fn().mockResolvedValue([]) },
    product: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
      findUnique: mockProductFindUnique,
      update: jest.fn(),
      delete: jest.fn()
    },
    users: {
      findUnique: mockUsersFindUnique
    }
  }))
}));

jest.mock('axios');

const { app } = require('../server');

// ============================================
// Generators
// ============================================
const uuidArb = fc.uuid().filter(u => u.length > 0);
const productIdArb = fc.integer({ min: 1, max: 100000 });

const messageContentArb = fc.string({ minLength: 1, maxLength: 200 })
  .filter(s => s.trim().length > 0 && !s.includes('\x00'));
const reasonArb = fc.constantFrom(
  'ส่งข้อความไม่เหมาะสม', 'หลอกลวง', 'สแปม', 'คุกคาม', 'อื่นๆ'
);

// Reset mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});

// ============================================
// Property 1: Chat Room สร้างแบบ Idempotent
// ============================================
describe('Feature: unimart-iteration-2, Property 1: Chat Room สร้างแบบ Idempotent', () => {
  /**
   * Validates: Requirements 1.1
   * For any buyer, seller, product combination, calling create chat room twice
   * with the same data should return the same room ID (no duplicate creation)
   */
  test('creating chat room twice with same data returns same room ID', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        uuidArb,
        productIdArb,
        async (buyerId, sellerId, productId) => {
          fc.pre(buyerId !== sellerId);

          const roomId = 'room-' + buyerId.slice(0, 8);
          const roomData = {
            id: roomId,
            buyer_id: buyerId,
            seller_id: sellerId,
            product_id: productId,
            created_at: '2025-01-01T00:00:00Z'
          };

          // Helper to build the chained .select().eq().eq().eq().single() mock
          function buildSelectChain(data, error) {
            const mockSingle = jest.fn().mockResolvedValue({ data, error });
            const mockEq3 = jest.fn().mockReturnValue({ single: mockSingle });
            const mockEq2 = jest.fn().mockReturnValue({ eq: mockEq3 });
            const mockEq1 = jest.fn().mockReturnValue({ eq: mockEq2 });
            const mockSelect = jest.fn().mockReturnValue({ eq: mockEq1 });
            return mockSelect;
          }

          // First call: room doesn't exist → create new
          // from('chat_rooms') is called twice in server: once for select, once for insert
          mockSupabaseFrom
            .mockReturnValueOnce({
              select: buildSelectChain(null, { code: 'PGRST116' })
            })
            .mockReturnValueOnce({
              insert: jest.fn().mockReturnValue({
                select: jest.fn().mockReturnValue({
                  single: jest.fn().mockResolvedValue({ data: roomData, error: null })
                })
              })
            });

          const res1 = await request(app)
            .post('/api/chat/rooms')
            .send({ buyerId, sellerId, productId });

          expect(res1.status).toBe(201);
          const firstRoomId = res1.body.id;

          // Second call: room already exists → return existing
          mockSupabaseFrom.mockReturnValueOnce({
            select: buildSelectChain(roomData, null)
          });

          const res2 = await request(app)
            .post('/api/chat/rooms')
            .send({ buyerId, sellerId, productId });

          expect(res2.status).toBe(200);
          expect(res2.body.id).toBe(firstRoomId);
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 2: ข้อความเรียงตามลำดับเวลา
// ============================================
describe('Feature: unimart-iteration-2, Property 2: ข้อความเรียงตามลำดับเวลา', () => {
  /**
   * Validates: Requirements 1.3
   * For any chat room with multiple messages, fetching all messages
   * should return them sorted by createdAt ascending
   */
  test('messages are returned sorted by createdAt ascending', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        fc.integer({ min: 2, max: 20 }),
        async (roomId, msgCount) => {
          // Generate messages with random timestamps, then sort for expected order
          const baseTime = new Date('2025-01-01T00:00:00Z').getTime();
          const messages = [];
          for (let i = 0; i < msgCount; i++) {
            messages.push({
              id: `msg-${i}`,
              room_id: roomId,
              sender_id: 'user-sender',
              content: `Message ${i}`,
              image_url: null,
              type: 'text',
              is_read: false,
              created_at: new Date(baseTime + i * 60000).toISOString()
            });
          }

          // Shuffle messages to simulate DB returning them in any order,
          // but the API orders by created_at ascending via Supabase .order()
          // Since we mock the Supabase response, we return them already sorted
          // (as Supabase would after .order('created_at', { ascending: true }))
          const sortedMessages = [...messages].sort(
            (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
          );

          mockSupabaseFrom.mockImplementation((table) => {
            if (table === 'chat_rooms') {
              return {
                select: jest.fn().mockReturnValue({
                  eq: jest.fn().mockReturnValue({
                    single: jest.fn().mockResolvedValue({ data: { id: roomId }, error: null })
                  })
                })
              };
            }
            if (table === 'chat_messages') {
              return {
                select: jest.fn().mockReturnValue({
                  eq: jest.fn().mockReturnValue({
                    order: jest.fn().mockReturnValue({
                      range: jest.fn().mockResolvedValue({ data: sortedMessages, error: null })
                    })
                  })
                })
              };
            }
            return {};
          });

          const res = await request(app)
            .get(`/api/chat/rooms/${roomId}/messages`);

          expect(res.status).toBe(200);
          expect(res.body.length).toBe(msgCount);

          // Verify ascending order
          for (let i = 1; i < res.body.length; i++) {
            const prev = new Date(res.body[i - 1].createdAt).getTime();
            const curr = new Date(res.body[i].createdAt).getTime();
            expect(curr).toBeGreaterThanOrEqual(prev);
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 3: ข้อความ Round-Trip (Persistence)
// ============================================
describe('Feature: unimart-iteration-2, Property 3: ข้อความ Round-Trip (Persistence)', () => {
  /**
   * Validates: Requirements 1.6
   * For any message sent to a chat room, fetching messages from the same room
   * should include that message with matching content
   */
  test('sent message can be retrieved with matching content', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        uuidArb,
        messageContentArb,
        async (roomId, senderId, content) => {
          const msgId = 'msg-' + Math.random().toString(36).slice(2);
          const createdAt = new Date().toISOString();

          const insertedMessage = {
            id: msgId,
            room_id: roomId,
            sender_id: senderId,
            content: content,
            image_url: null,
            type: 'text',
            created_at: createdAt
          };

          // Mock for POST /api/chat/messages
          mockSupabaseFrom.mockImplementation((table) => {
            if (table === 'chat_rooms') {
              return {
                select: jest.fn().mockReturnValue({
                  eq: jest.fn().mockReturnValue({
                    single: jest.fn().mockResolvedValue({
                      data: { id: roomId, buyer_id: senderId, seller_id: 'other-user' },
                      error: null
                    })
                  })
                })
              };
            }
            if (table === 'chat_messages') {
              return {
                insert: jest.fn().mockReturnValue({
                  select: jest.fn().mockReturnValue({
                    single: jest.fn().mockResolvedValue({ data: insertedMessage, error: null })
                  })
                })
              };
            }
            return {};
          });

          // Step 1: Send message
          const sendRes = await request(app)
            .post('/api/chat/messages')
            .send({ roomId, senderId, content, type: 'text' });

          expect(sendRes.status).toBe(201);
          const sentMsgId = sendRes.body.id;
          const sentContent = sendRes.body.content;

          // Step 2: Fetch messages — mock includes the sent message
          mockSupabaseFrom.mockImplementation((table) => {
            if (table === 'chat_rooms') {
              return {
                select: jest.fn().mockReturnValue({
                  eq: jest.fn().mockReturnValue({
                    single: jest.fn().mockResolvedValue({ data: { id: roomId }, error: null })
                  })
                })
              };
            }
            if (table === 'chat_messages') {
              return {
                select: jest.fn().mockReturnValue({
                  eq: jest.fn().mockReturnValue({
                    order: jest.fn().mockReturnValue({
                      range: jest.fn().mockResolvedValue({
                        data: [insertedMessage],
                        error: null
                      })
                    })
                  })
                })
              };
            }
            return {};
          });

          const getRes = await request(app)
            .get(`/api/chat/rooms/${roomId}/messages`);

          expect(getRes.status).toBe(200);

          // Verify the sent message is in the fetched results with matching content
          const found = getRes.body.find(m => m.id === sentMsgId);
          expect(found).toBeDefined();
          expect(found.content).toBe(sentContent);
          expect(found.roomId).toBe(roomId);
          expect(found.senderId).toBe(senderId);
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 4: Chat List แสดงข้อมูลครบถ้วน
// ============================================
describe('Feature: unimart-iteration-2, Property 4: Chat List แสดงข้อมูลครบถ้วน', () => {
  /**
   * Validates: Requirements 1.4
   * For any user with chat rooms, fetching the chat room list should return rooms
   * where each has: otherUser info, lastMessage, unreadCount
   */
  test('chat list returns rooms with complete data fields', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        uuidArb,
        fc.string({ minLength: 1, maxLength: 50 }).filter(s => s.trim().length > 0),
        fc.string({ minLength: 1, maxLength: 100 }).filter(s => s.trim().length > 0),
        fc.string({ minLength: 1, maxLength: 100 }).filter(s => s.trim().length > 0),
        fc.nat({ max: 50 }),
        async (userId, otherUserId, productTitle, displayName, lastMsgContent, unreadCount) => {
          fc.pre(userId !== otherUserId);

          const room = {
            id: 'room-' + Math.random().toString(36).slice(2),
            buyer_id: userId,
            seller_id: otherUserId,
            product_id: 1,
            created_at: '2025-01-01T00:00:00Z'
          };

          const lastMsg = {
            content: lastMsgContent,
            created_at: '2025-01-01T12:00:00Z',
            type: 'text'
          };

          let buyerCallDone = false;
          mockSupabaseFrom.mockImplementation((table) => {
            if (table === 'chat_rooms') {
              return {
                select: jest.fn().mockReturnValue({
                  eq: jest.fn().mockImplementation(() => {
                    if (!buyerCallDone) {
                      buyerCallDone = true;
                      return { data: [room], error: null };
                    }
                    return { data: [], error: null };
                  })
                })
              };
            }
            if (table === 'chat_messages') {
              return {
                select: jest.fn().mockImplementation((selectStr, opts) => {
                  if (opts && opts.count === 'exact' && opts.head === true) {
                    return {
                      eq: jest.fn().mockReturnValue({
                        eq: jest.fn().mockReturnValue({
                          neq: jest.fn().mockResolvedValue({ count: unreadCount, error: null })
                        })
                      })
                    };
                  }
                  return {
                    eq: jest.fn().mockReturnValue({
                      order: jest.fn().mockReturnValue({
                        limit: jest.fn().mockResolvedValue({ data: [lastMsg], error: null })
                      })
                    })
                  };
                })
              };
            }
            return {};
          });

          mockUsersFindUnique.mockResolvedValue({
            display_name_th: displayName,
            username: 'user-' + otherUserId.slice(0, 6)
          });

          mockProductFindUnique.mockResolvedValue({
            title: productTitle
          });

          const res = await request(app)
            .get(`/api/chat/rooms/${userId}`);

          expect(res.status).toBe(200);
          expect(res.body.length).toBeGreaterThanOrEqual(1);

          for (const room of res.body) {
            // otherUser info must be present
            expect(room.otherUser).toBeDefined();
            expect(room.otherUser).toHaveProperty('displayName');
            expect(room.otherUser).toHaveProperty('username');

            // lastMessage must be present (we sent one)
            expect(room.lastMessage).toBeDefined();
            expect(room.lastMessage).toHaveProperty('content');
            expect(room.lastMessage).toHaveProperty('createdAt');

            // unreadCount must be a number
            expect(typeof room.unreadCount).toBe('number');
            expect(room.unreadCount).toBeGreaterThanOrEqual(0);
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 5: Report มีข้อมูลครบถ้วน
// ============================================
describe('Feature: unimart-iteration-2, Property 5: Report มีข้อมูลครบถ้วน', () => {
  /**
   * Validates: Requirements 1.7
   * For any report created, the saved data should contain
   * room_id, reporter_id, reported_user_id, reason, and created_at
   */
  test('created report contains all required fields', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        uuidArb,
        uuidArb,
        reasonArb,
        async (roomId, reporterId, reportedUserId, reason) => {
          fc.pre(reporterId !== reportedUserId);
          fc.pre(reason.length > 0);

          const createdAt = new Date().toISOString();
          const reportId = 'report-' + Math.random().toString(36).slice(2);

          let capturedInsertData = null;

          mockSupabaseFrom.mockReturnValue({
            insert: jest.fn().mockImplementation((rows) => {
              capturedInsertData = rows[0];
              return {
                select: jest.fn().mockReturnValue({
                  single: jest.fn().mockResolvedValue({
                    data: {
                      id: reportId,
                      room_id: rows[0].room_id,
                      reporter_id: rows[0].reporter_id,
                      reported_user_id: rows[0].reported_user_id,
                      reason: rows[0].reason,
                      status: rows[0].status,
                      created_at: createdAt
                    },
                    error: null
                  })
                })
              };
            })
          });

          const res = await request(app)
            .post('/api/chat/reports')
            .send({ roomId, reporterId, reportedUserId, reason });

          expect(res.status).toBe(201);

          // Verify response has all required fields
          expect(res.body.roomId).toBe(roomId);
          expect(res.body.reporterId).toBe(reporterId);
          expect(res.body.reportedUserId).toBe(reportedUserId);
          expect(res.body.reason).toBe(reason);
          expect(res.body.createdAt).toBeDefined();

          // Verify the data sent to Supabase insert
          expect(capturedInsertData).toBeDefined();
          expect(capturedInsertData.room_id).toBe(roomId);
          expect(capturedInsertData.reporter_id).toBe(reporterId);
          expect(capturedInsertData.reported_user_id).toBe(reportedUserId);
          expect(capturedInsertData.reason).toBe(reason);
          expect(capturedInsertData.status).toBe('pending');
        }
      ),
      { numRuns: 100 }
    );
  });
});
