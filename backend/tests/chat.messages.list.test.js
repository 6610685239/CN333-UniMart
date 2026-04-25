/**
 * Unit Tests สำหรับ GET /api/chat/rooms/:roomId/messages — UniMart Iteration 2
 * 
 * ทดสอบการดึงข้อความใน Chat Room พร้อม pagination
 * Validates: Requirements 1.3, 1.6
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
    users: { findUnique: jest.fn() }
  }))
}));

jest.mock('axios');

const { app } = require('../server');

beforeEach(() => {
  jest.clearAllMocks();
});

describe('GET /api/chat/rooms/:roomId/messages', () => {
  const roomId = 'room-uuid-1';

  test('returns 404 when room does not exist', async () => {
    mockSupabaseFrom.mockImplementation((table) => {
      if (table === 'chat_rooms') {
        return {
          select: jest.fn().mockReturnValue({
            eq: jest.fn().mockReturnValue({
              single: jest.fn().mockResolvedValue({
                data: null,
                error: { code: 'PGRST116', message: 'No rows found' }
              })
            })
          })
        };
      }
      return {};
    });

    const res = await request(app).get(`/api/chat/rooms/${roomId}/messages`);

    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toBe('ไม่พบห้องสนทนา');
  });

  test('returns empty array when room has no messages', async () => {
    mockSupabaseFrom.mockImplementation((table) => {
      if (table === 'chat_rooms') {
        return {
          select: jest.fn().mockReturnValue({
            eq: jest.fn().mockReturnValue({
              single: jest.fn().mockResolvedValue({
                data: { id: roomId },
                error: null
              })
            })
          })
        };
      }
      if (table === 'chat_messages') {
        return {
          select: jest.fn().mockReturnValue({
            eq: jest.fn().mockReturnValue({
              order: jest.fn().mockReturnValue({
                range: jest.fn().mockResolvedValue({ data: [], error: null })
              })
            })
          })
        };
      }
      return {};
    });

    const res = await request(app).get(`/api/chat/rooms/${roomId}/messages`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('returns messages sorted by createdAt ascending with camelCase fields', async () => {
    const dbMessages = [
      {
        id: 'msg-1',
        room_id: roomId,
        sender_id: 'user-1',
        content: 'สวัสดีครับ',
        image_url: null,
        type: 'text',
        is_read: false,
        created_at: '2025-01-01T10:00:00Z'
      },
      {
        id: 'msg-2',
        room_id: roomId,
        sender_id: 'user-2',
        content: 'สวัสดีค่ะ',
        image_url: null,
        type: 'text',
        is_read: true,
        created_at: '2025-01-01T10:01:00Z'
      }
    ];

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
                range: jest.fn().mockResolvedValue({ data: dbMessages, error: null })
              })
            })
          })
        };
      }
      return {};
    });

    const res = await request(app).get(`/api/chat/rooms/${roomId}/messages`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);

    // Check first message (oldest)
    expect(res.body[0]).toEqual({
      id: 'msg-1',
      roomId: roomId,
      senderId: 'user-1',
      content: 'สวัสดีครับ',
      imageUrl: null,
      type: 'text',
      isRead: false,
      createdAt: '2025-01-01T10:00:00Z'
    });

    // Check second message (newer)
    expect(res.body[1]).toEqual({
      id: 'msg-2',
      roomId: roomId,
      senderId: 'user-2',
      content: 'สวัสดีค่ะ',
      imageUrl: null,
      type: 'text',
      isRead: true,
      createdAt: '2025-01-01T10:01:00Z'
    });
  });

  test('supports image type messages', async () => {
    const imageMsg = [{
      id: 'msg-img',
      room_id: roomId,
      sender_id: 'user-1',
      content: null,
      image_url: 'https://example.com/photo.jpg',
      type: 'image',
      is_read: false,
      created_at: '2025-01-01T10:00:00Z'
    }];

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
                range: jest.fn().mockResolvedValue({ data: imageMsg, error: null })
              })
            })
          })
        };
      }
      return {};
    });

    const res = await request(app).get(`/api/chat/rooms/${roomId}/messages`);

    expect(res.status).toBe(200);
    expect(res.body[0].type).toBe('image');
    expect(res.body[0].imageUrl).toBe('https://example.com/photo.jpg');
    expect(res.body[0].content).toBeNull();
  });

  test('respects limit and offset query params', async () => {
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
                range: jest.fn().mockImplementation((from, to) => {
                  expect(from).toBe(10);
                  expect(to).toBe(14); // offset 10 + limit 5 - 1
                  return Promise.resolve({ data: [], error: null });
                })
              })
            })
          })
        };
      }
      return {};
    });

    const res = await request(app).get(`/api/chat/rooms/${roomId}/messages?limit=5&offset=10`);

    expect(res.status).toBe(200);
  });

  test('returns 500 when supabase messages query fails', async () => {
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
                  data: null,
                  error: { message: 'DB error' }
                })
              })
            })
          })
        };
      }
      return {};
    });

    const res = await request(app).get(`/api/chat/rooms/${roomId}/messages`);

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
