/**
 * Unit Tests สำหรับ POST /api/chat/reports — UniMart Iteration 2
 * 
 * ทดสอบการรายงานผู้ใช้ในระบบแชท
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

describe('POST /api/chat/reports', () => {
  const reportPayload = {
    roomId: 'room-uuid-123',
    reporterId: '11111111-1111-1111-1111-111111111111',
    reportedUserId: '22222222-2222-2222-2222-222222222222',
    reason: 'ส่งข้อความไม่เหมาะสม'
  };

  test('returns 400 when roomId is missing', async () => {
    const { roomId, ...payload } = reportPayload;
    const res = await request(app)
      .post('/api/chat/reports')
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when reporterId is missing', async () => {
    const { reporterId, ...payload } = reportPayload;
    const res = await request(app)
      .post('/api/chat/reports')
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when reportedUserId is missing', async () => {
    const { reportedUserId, ...payload } = reportPayload;
    const res = await request(app)
      .post('/api/chat/reports')
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when reason is missing', async () => {
    const { reason, ...payload } = reportPayload;
    const res = await request(app)
      .post('/api/chat/reports')
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('creates report successfully with status pending', async () => {
    const createdReport = {
      id: 'report-uuid-456',
      room_id: reportPayload.roomId,
      reporter_id: reportPayload.reporterId,
      reported_user_id: reportPayload.reportedUserId,
      reason: reportPayload.reason,
      status: 'pending',
      created_at: '2025-01-15T10:00:00Z'
    };

    const mockSingle = jest.fn().mockResolvedValue({ data: createdReport, error: null });
    const mockSelect = jest.fn().mockReturnValue({ single: mockSingle });
    const mockInsert = jest.fn().mockReturnValue({ select: mockSelect });

    mockSupabaseFrom.mockReturnValue({ insert: mockInsert });

    const res = await request(app)
      .post('/api/chat/reports')
      .send(reportPayload);

    expect(res.status).toBe(201);
    expect(res.body.id).toBe('report-uuid-456');
    expect(res.body.roomId).toBe(reportPayload.roomId);
    expect(res.body.reporterId).toBe(reportPayload.reporterId);
    expect(res.body.reportedUserId).toBe(reportPayload.reportedUserId);
    expect(res.body.reason).toBe(reportPayload.reason);
    expect(res.body.status).toBe('pending');
    expect(res.body.createdAt).toBeDefined();

    // Verify insert was called with correct data
    expect(mockInsert).toHaveBeenCalledWith([{
      room_id: reportPayload.roomId,
      reporter_id: reportPayload.reporterId,
      reported_user_id: reportPayload.reportedUserId,
      reason: reportPayload.reason,
      status: 'pending'
    }]);
  });

  test('returns 500 when supabase insert fails', async () => {
    const mockSingle = jest.fn().mockResolvedValue({
      data: null,
      error: { message: 'DB insert failed' }
    });
    const mockSelect = jest.fn().mockReturnValue({ single: mockSingle });
    const mockInsert = jest.fn().mockReturnValue({ select: mockSelect });

    mockSupabaseFrom.mockReturnValue({ insert: mockInsert });

    const res = await request(app)
      .post('/api/chat/reports')
      .send(reportPayload);

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
