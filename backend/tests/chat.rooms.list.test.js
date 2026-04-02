/**
 * Unit Tests สำหรับ GET /api/chat/rooms/:userId — UniMart Iteration 2
 * 
 * ทดสอบการดึงรายการ Chat Room ของผู้ใช้
 * Validates: Requirements 1.4
 */

const request = require('supertest');

// Mock Supabase
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

beforeEach(() => {
  jest.clearAllMocks();
});

// Helper to create Supabase mock chain for chat_rooms queries
function createRoomsMock(buyerRooms, sellerRooms) {
  let callCount = 0;
  return {
    select: jest.fn().mockReturnValue({
      eq: jest.fn().mockImplementation(() => {
        callCount++;
        if (callCount === 1) {
          return { data: buyerRooms, error: null };
        }
        return { data: sellerRooms, error: null };
      })
    })
  };
}

// Helper to create Supabase mock for chat_messages (last message + unread count)
function createMessagesMock(lastMessages, unreadCount) {
  return {
    select: jest.fn().mockImplementation((selectStr, opts) => {
      if (opts && opts.count === 'exact' && opts.head === true) {
        // unread count query
        return {
          eq: jest.fn().mockReturnValue({
            eq: jest.fn().mockReturnValue({
              neq: jest.fn().mockResolvedValue({ count: unreadCount, error: null })
            })
          })
        };
      }
      // last message query
      return {
        eq: jest.fn().mockReturnValue({
          order: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue({ data: lastMessages, error: null })
          })
        })
      };
    })
  };
}

describe('GET /api/chat/rooms/:userId', () => {
  const userId = '11111111-1111-1111-1111-111111111111';
  const otherUserId = '22222222-2222-2222-2222-222222222222';

  test('returns empty array when user has no rooms', async () => {
    // Mock supabase.from() to return different mocks based on table name
    mockSupabaseFrom.mockImplementation((table) => {
      if (table === 'chat_rooms') {
        return {
          select: jest.fn().mockReturnValue({
            eq: jest.fn().mockResolvedValue({ data: [], error: null })
          })
        };
      }
      return {};
    });

    const res = await request(app).get(`/api/chat/rooms/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('returns rooms with complete data (otherUser, lastMessage, unreadCount)', async () => {
    const room = {
      id: 'room-uuid-1',
      buyer_id: userId,
      seller_id: otherUserId,
      product_id: 1,
      created_at: '2025-01-01T00:00:00Z'
    };

    const lastMsg = {
      content: 'สวัสดีครับ',
      created_at: '2025-01-01T12:00:00Z',
      type: 'text'
    };

    let fromCallIndex = 0;
    mockSupabaseFrom.mockImplementation((table) => {
      if (table === 'chat_rooms') {
        fromCallIndex++;
        return {
          select: jest.fn().mockReturnValue({
            eq: jest.fn().mockResolvedValue(
              fromCallIndex === 1
                ? { data: [room], error: null }
                : { data: [], error: null }
            )
          })
        };
      }
      if (table === 'chat_messages') {
        return createMessagesMock([lastMsg], 3);
      }
      return {};
    });

    mockUsersFindUnique.mockResolvedValue({
      display_name_th: 'ทดสอบ ผู้ขาย',
      username: '6200000002'
    });

    mockProductFindUnique.mockResolvedValue({
      title: 'หนังสือแคลคูลัส'
    });

    const res = await request(app).get(`/api/chat/rooms/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);

    const roomResult = res.body[0];
    expect(roomResult.id).toBe('room-uuid-1');
    expect(roomResult.productTitle).toBe('หนังสือแคลคูลัส');
    expect(roomResult.otherUser).toEqual({
      displayName: 'ทดสอบ ผู้ขาย',
      username: '6200000002'
    });
    expect(roomResult.lastMessage).toEqual({
      content: 'สวัสดีครับ',
      createdAt: '2025-01-01T12:00:00Z',
      type: 'text'
    });
    expect(roomResult.unreadCount).toBe(3);
  });

  test('returns rooms sorted by last message time (newest first)', async () => {
    const room1 = {
      id: 'room-old',
      buyer_id: userId,
      seller_id: otherUserId,
      product_id: 1,
      created_at: '2025-01-01T00:00:00Z'
    };
    const room2 = {
      id: 'room-new',
      buyer_id: userId,
      seller_id: '33333333-3333-3333-3333-333333333333',
      product_id: 2,
      created_at: '2025-01-02T00:00:00Z'
    };

    let fromCallIndex = 0;
    mockSupabaseFrom.mockImplementation((table) => {
      if (table === 'chat_rooms') {
        fromCallIndex++;
        return {
          select: jest.fn().mockReturnValue({
            eq: jest.fn().mockResolvedValue(
              fromCallIndex === 1
                ? { data: [room1, room2], error: null }
                : { data: [], error: null }
            )
          })
        };
      }
      if (table === 'chat_messages') {
        return {
          select: jest.fn().mockImplementation((selectStr, opts) => {
            if (opts && opts.count === 'exact') {
              return {
                eq: jest.fn().mockReturnValue({
                  eq: jest.fn().mockReturnValue({
                    neq: jest.fn().mockResolvedValue({ count: 0, error: null })
                  })
                })
              };
            }
            return {
              eq: jest.fn().mockImplementation((col, val) => {
                const time = val === 'room-old' ? '2025-01-01T10:00:00Z' : '2025-01-02T15:00:00Z';
                return {
                  order: jest.fn().mockReturnValue({
                    limit: jest.fn().mockResolvedValue({
                      data: [{ content: 'msg', created_at: time, type: 'text' }],
                      error: null
                    })
                  })
                };
              })
            };
          })
        };
      }
      return {};
    });

    mockUsersFindUnique.mockResolvedValue({ display_name_th: 'User', username: 'user1' });
    mockProductFindUnique.mockResolvedValue({ title: 'Product' });

    const res = await request(app).get(`/api/chat/rooms/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
    // room-new should come first (newer last message)
    expect(res.body[0].id).toBe('room-new');
    expect(res.body[1].id).toBe('room-old');
  });

  test('handles room where user is seller', async () => {
    const room = {
      id: 'room-seller',
      buyer_id: otherUserId,
      seller_id: userId,
      product_id: 1,
      created_at: '2025-01-01T00:00:00Z'
    };

    let fromCallIndex = 0;
    mockSupabaseFrom.mockImplementation((table) => {
      if (table === 'chat_rooms') {
        fromCallIndex++;
        return {
          select: jest.fn().mockReturnValue({
            eq: jest.fn().mockResolvedValue(
              fromCallIndex === 1
                ? { data: [], error: null }
                : { data: [room], error: null }
            )
          })
        };
      }
      if (table === 'chat_messages') {
        return createMessagesMock([], 0);
      }
      return {};
    });

    // otherUser should be the buyer
    mockUsersFindUnique.mockResolvedValue({
      display_name_th: 'ผู้ซื้อ ทดสอบ',
      username: '6200000001'
    });
    mockProductFindUnique.mockResolvedValue({ title: 'สินค้าทดสอบ' });

    const res = await request(app).get(`/api/chat/rooms/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].otherUser.displayName).toBe('ผู้ซื้อ ทดสอบ');
    expect(res.body[0].lastMessage).toBeNull();
    expect(res.body[0].unreadCount).toBe(0);
  });

  test('returns 500 when supabase query fails', async () => {
    mockSupabaseFrom.mockImplementation(() => ({
      select: jest.fn().mockReturnValue({
        eq: jest.fn().mockResolvedValue({
          data: null,
          error: { message: 'DB error' }
        })
      })
    }));

    const res = await request(app).get(`/api/chat/rooms/${userId}`);

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
