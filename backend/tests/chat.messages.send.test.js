/**
 * Unit Tests สำหรับ POST /api/chat/messages — UniMart Iteration 2
 * 
 * ทดสอบการส่งข้อความ (text/image) ใน Chat Room
 * Validates: Requirements 1.2, 1.5, 1.6
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

describe('POST /api/chat/messages', () => {
  const roomId = 'room-uuid-1';
  const senderId = 'user-uuid-1';
  const receiverId = 'user-uuid-2';

  // Helper to mock room lookup + message insert
  function setupMocks({ roomData, roomError, insertData, insertError }) {
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
      return {};
    });
  }

  // --- Validation Tests ---

  test('returns 400 when roomId is missing', async () => {
    const res = await request(app)
      .post('/api/chat/messages')
      .send({ senderId, content: 'hello', type: 'text' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when senderId is missing', async () => {
    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, content: 'hello', type: 'text' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when type is text and content is empty', async () => {
    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, content: '', type: 'text' });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('กรุณากรอกข้อความ');
  });

  test('returns 400 when type is text and content is whitespace only', async () => {
    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, content: '   ', type: 'text' });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('กรุณากรอกข้อความ');
  });

  test('returns 400 when type is image and imageUrl is missing', async () => {
    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, type: 'image' });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('กรุณาระบุ URL รูปภาพ');
  });

  // --- Room Not Found ---

  test('returns 404 when room does not exist', async () => {
    setupMocks({
      roomData: null,
      roomError: { code: 'PGRST116', message: 'No rows found' },
      insertData: null,
      insertError: null
    });

    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, content: 'hello', type: 'text' });

    expect(res.status).toBe(404);
    expect(res.body.message).toBe('ไม่พบห้องสนทนา');
  });

  // --- Successful Text Message ---

  test('creates text message successfully', async () => {
    const createdMsg = {
      id: 'msg-uuid-1',
      room_id: roomId,
      sender_id: senderId,
      content: 'สวัสดีครับ',
      image_url: null,
      type: 'text',
      created_at: '2025-01-01T10:00:00Z'
    };

    setupMocks({
      roomData: { id: roomId, buyer_id: senderId, seller_id: receiverId },
      roomError: null,
      insertData: createdMsg,
      insertError: null
    });

    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, content: 'สวัสดีครับ', type: 'text' });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      id: 'msg-uuid-1',
      roomId: roomId,
      senderId: senderId,
      content: 'สวัสดีครับ',
      imageUrl: null,
      type: 'text',
      createdAt: '2025-01-01T10:00:00Z'
    });
  });

  // --- Successful Image Message ---

  test('creates image message successfully', async () => {
    const createdMsg = {
      id: 'msg-uuid-2',
      room_id: roomId,
      sender_id: senderId,
      content: null,
      image_url: 'https://example.com/photo.jpg',
      type: 'image',
      created_at: '2025-01-01T10:05:00Z'
    };

    setupMocks({
      roomData: { id: roomId, buyer_id: senderId, seller_id: receiverId },
      roomError: null,
      insertData: createdMsg,
      insertError: null
    });

    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, imageUrl: 'https://example.com/photo.jpg', type: 'image' });

    expect(res.status).toBe(201);
    expect(res.body.type).toBe('image');
    expect(res.body.imageUrl).toBe('https://example.com/photo.jpg');
    expect(res.body.content).toBeNull();
  });

  // --- Default type is text ---

  test('defaults to type text when type is not specified', async () => {
    const createdMsg = {
      id: 'msg-uuid-3',
      room_id: roomId,
      sender_id: senderId,
      content: 'ข้อความทดสอบ',
      image_url: null,
      type: 'text',
      created_at: '2025-01-01T10:10:00Z'
    };

    setupMocks({
      roomData: { id: roomId, buyer_id: senderId, seller_id: receiverId },
      roomError: null,
      insertData: createdMsg,
      insertError: null
    });

    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, content: 'ข้อความทดสอบ' });

    expect(res.status).toBe(201);
    expect(res.body.type).toBe('text');
  });

  // --- Error Handling ---

  test('returns 500 when supabase insert fails', async () => {
    setupMocks({
      roomData: { id: roomId, buyer_id: senderId, seller_id: receiverId },
      roomError: null,
      insertData: null,
      insertError: { message: 'Insert failed' }
    });

    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, content: 'test', type: 'text' });

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });

  test('returns 500 when room query throws unexpected error', async () => {
    setupMocks({
      roomData: null,
      roomError: { code: 'UNEXPECTED', message: 'DB error' },
      insertData: null,
      insertError: null
    });

    const res = await request(app)
      .post('/api/chat/messages')
      .send({ roomId, senderId, content: 'test', type: 'text' });

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
