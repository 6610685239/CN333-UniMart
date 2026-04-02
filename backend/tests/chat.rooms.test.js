/**
 * Unit Tests สำหรับ POST /api/chat/rooms — UniMart Iteration 2
 * 
 * ทดสอบการสร้างหรือเปิด Chat Room
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
    product: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() }
  }))
}));

jest.mock('axios');

const { app } = require('../server');

beforeEach(() => {
  jest.clearAllMocks();
});

describe('POST /api/chat/rooms', () => {
  const roomPayload = {
    buyerId: '11111111-1111-1111-1111-111111111111',
    sellerId: '22222222-2222-2222-2222-222222222222',
    productId: 1
  };

  test('returns 400 when buyerId is missing', async () => {
    const res = await request(app)
      .post('/api/chat/rooms')
      .send({ sellerId: roomPayload.sellerId, productId: roomPayload.productId });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when sellerId is missing', async () => {
    const res = await request(app)
      .post('/api/chat/rooms')
      .send({ buyerId: roomPayload.buyerId, productId: roomPayload.productId });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when productId is missing', async () => {
    const res = await request(app)
      .post('/api/chat/rooms')
      .send({ buyerId: roomPayload.buyerId, sellerId: roomPayload.sellerId });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns existing room when one already exists', async () => {
    const existingRoom = {
      id: 'room-uuid-123',
      buyer_id: roomPayload.buyerId,
      seller_id: roomPayload.sellerId,
      product_id: roomPayload.productId,
      created_at: '2025-01-01T00:00:00Z'
    };

    // Mock: select chain with multiple .eq() calls
    const mockSingle = jest.fn().mockResolvedValue({ data: existingRoom, error: null });
    const mockEq3 = jest.fn().mockReturnValue({ single: mockSingle });
    const mockEq2 = jest.fn().mockReturnValue({ eq: mockEq3 });
    const mockEq1 = jest.fn().mockReturnValue({ eq: mockEq2 });
    const mockSelect = jest.fn().mockReturnValue({ eq: mockEq1 });

    mockSupabaseFrom.mockReturnValue({
      select: mockSelect
    });

    const res = await request(app)
      .post('/api/chat/rooms')
      .send(roomPayload);

    expect(res.status).toBe(200);
    expect(res.body.id).toBe('room-uuid-123');
    expect(res.body.buyerId).toBe(roomPayload.buyerId);
    expect(res.body.sellerId).toBe(roomPayload.sellerId);
    expect(res.body.productId).toBe(roomPayload.productId);
  });

  test('creates new room when none exists', async () => {
    const newRoom = {
      id: 'new-room-uuid',
      buyer_id: roomPayload.buyerId,
      seller_id: roomPayload.sellerId,
      product_id: roomPayload.productId,
      created_at: '2025-01-01T00:00:00Z'
    };

    // Mock: select returns no rows (PGRST116)
    const mockSingle = jest.fn().mockResolvedValue({
      data: null,
      error: { code: 'PGRST116', message: 'No rows found' }
    });
    const mockEq3 = jest.fn().mockReturnValue({ single: mockSingle });
    const mockEq2 = jest.fn().mockReturnValue({ eq: mockEq3 });
    const mockEq1 = jest.fn().mockReturnValue({ eq: mockEq2 });
    const mockSelectQuery = jest.fn().mockReturnValue({ eq: mockEq1 });

    // Mock: insert chain
    const mockInsertSingle = jest.fn().mockResolvedValue({ data: newRoom, error: null });
    const mockInsertSelect = jest.fn().mockReturnValue({ single: mockInsertSingle });
    const mockInsert = jest.fn().mockReturnValue({ select: mockInsertSelect });

    mockSupabaseFrom.mockReturnValue({
      select: mockSelectQuery,
      insert: mockInsert
    });

    const res = await request(app)
      .post('/api/chat/rooms')
      .send(roomPayload);

    expect(res.status).toBe(201);
    expect(res.body.id).toBe('new-room-uuid');
    expect(res.body.buyerId).toBe(roomPayload.buyerId);
    expect(res.body.sellerId).toBe(roomPayload.sellerId);
    expect(res.body.productId).toBe(roomPayload.productId);
    expect(res.body.createdAt).toBeDefined();
  });

  test('returns 500 when supabase select throws unexpected error', async () => {
    const mockSingle = jest.fn().mockResolvedValue({
      data: null,
      error: { code: 'UNEXPECTED', message: 'DB connection failed' }
    });
    const mockEq3 = jest.fn().mockReturnValue({ single: mockSingle });
    const mockEq2 = jest.fn().mockReturnValue({ eq: mockEq3 });
    const mockEq1 = jest.fn().mockReturnValue({ eq: mockEq2 });
    const mockSelect = jest.fn().mockReturnValue({ eq: mockEq1 });

    mockSupabaseFrom.mockReturnValue({
      select: mockSelect
    });

    const res = await request(app)
      .post('/api/chat/rooms')
      .send(roomPayload);

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
