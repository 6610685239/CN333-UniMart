/**
 * Unit Tests สำหรับ Smart Filter — UniMart Iteration 2
 *
 * Task 7.1: GET /api/products/filter — กรองสินค้าตามเงื่อนไข (Requirements 3.1-3.6, 2.5)
 * Task 7.2: GET /api/meeting-points — ดึงรายการจุดนัดพบ (Requirements 3.3, 3.7)
 * Task 7.3: GET /api/dormitory-zones — ดึงรายการโซนหอพัก (Requirements 3.2)
 */

const request = require('supertest');

// Mock Supabase
jest.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    from: jest.fn().mockReturnValue({
      select: jest.fn().mockReturnValue({
        eq: jest.fn().mockReturnValue({
          single: jest.fn().mockResolvedValue({ data: null, error: null })
        })
      })
    })
  })
}));

// Mock Prisma
const mockProductFindMany = jest.fn();
const mockMeetingPointFindMany = jest.fn();
const mockReviewAggregate = jest.fn();

jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: { findMany: jest.fn().mockResolvedValue([]) },
    product: {
      findMany: mockProductFindMany,
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn()
    },
    transaction: { findUnique: jest.fn(), create: jest.fn() },
    review: {
      create: jest.fn(),
      findMany: jest.fn(),
      aggregate: mockReviewAggregate
    },
    meetingPoint: {
      findMany: mockMeetingPointFindMany
    }
  }))
}));

jest.mock('axios');

const { app } = require('../server');

beforeEach(() => {
  jest.clearAllMocks();
});

// ==========================================
// Task 7.1: GET /api/products/filter
// ==========================================
describe('GET /api/products/filter', () => {
  const sampleProducts = [
    {
      id: 1, title: 'หนังสือแคลคูลัส', price: 200, status: 'Available',
      ownerId: 'user-1', categoryId: 1,
      owner: { id: 'user-1', display_name_th: 'สมชาย', username: '6401', faculty: 'วิศวกรรมศาสตร์', dormitory_zone: 'เชียงราก' },
      category: { id: 1, name: 'Textbooks' },
      meetingPoint: { id: 1, name: 'SC Hall', zone: 'ในมหาวิทยาลัย' }
    },
    {
      id: 2, title: 'เสื้อช็อป', price: 150, status: 'Available',
      ownerId: 'user-2', categoryId: 2,
      owner: { id: 'user-2', display_name_th: 'สมหญิง', username: '6402', faculty: 'วิทยาศาสตร์', dormitory_zone: 'อินเตอร์โซน' },
      category: { id: 2, name: 'Uniforms' },
      meetingPoint: { id: 2, name: 'โรงอาหารกรีน', zone: 'ในมหาวิทยาลัย' }
    }
  ];

  test('returns all available products when no filters provided', async () => {
    mockProductFindMany.mockResolvedValue(sampleProducts);

    const res = await request(app).get('/api/products/filter');

    expect(res.status).toBe(200);
    expect(res.body.products).toHaveLength(2);
    expect(res.body.totalCount).toBe(2);
  });

  test('filters by faculty (Req 3.1)', async () => {
    mockProductFindMany.mockResolvedValue([sampleProducts[0]]);

    const res = await request(app).get('/api/products/filter?faculty=วิศวกรรมศาสตร์');

    expect(res.status).toBe(200);
    expect(mockProductFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: 'Available',
          owner: { faculty: 'วิศวกรรมศาสตร์' }
        })
      })
    );
  });

  test('filters by dormitoryZone (Req 3.2)', async () => {
    mockProductFindMany.mockResolvedValue([sampleProducts[1]]);

    const res = await request(app).get('/api/products/filter?dormitoryZone=อินเตอร์โซน');

    expect(res.status).toBe(200);
    expect(mockProductFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: 'Available',
          owner: { dormitory_zone: 'อินเตอร์โซน' }
        })
      })
    );
  });

  test('filters by meetingPoint (Req 3.3)', async () => {
    mockProductFindMany.mockResolvedValue([sampleProducts[0]]);

    const res = await request(app).get('/api/products/filter?meetingPoint=SC Hall');

    expect(res.status).toBe(200);
    expect(mockProductFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: 'Available',
          meetingPoint: { name: 'SC Hall' }
        })
      })
    );
  });

  test('filters by categoryId', async () => {
    mockProductFindMany.mockResolvedValue([sampleProducts[0]]);

    const res = await request(app).get('/api/products/filter?categoryId=1');

    expect(res.status).toBe(200);
    expect(mockProductFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: 'Available',
          categoryId: 1
        })
      })
    );
  });

  test('applies AND logic for multiple filters (Req 3.4)', async () => {
    mockProductFindMany.mockResolvedValue([sampleProducts[0]]);

    const res = await request(app)
      .get('/api/products/filter?faculty=วิศวกรรมศาสตร์&dormitoryZone=เชียงราก&meetingPoint=SC Hall&categoryId=1');

    expect(res.status).toBe(200);
    expect(mockProductFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: 'Available',
          owner: { faculty: 'วิศวกรรมศาสตร์', dormitory_zone: 'เชียงราก' },
          meetingPoint: { name: 'SC Hall' },
          categoryId: 1
        })
      })
    );
  });

  test('filters by minCredit — keeps sellers with sufficient credit (Req 2.5)', async () => {
    mockProductFindMany.mockResolvedValue(sampleProducts);
    // user-1 has avg 4.5, user-2 has avg 2.0
    mockReviewAggregate
      .mockResolvedValueOnce({ _avg: { rating: 4.5 }, _count: { rating: 5 } })
      .mockResolvedValueOnce({ _avg: { rating: 2.0 }, _count: { rating: 3 } });

    const res = await request(app).get('/api/products/filter?minCredit=3.5');

    expect(res.status).toBe(200);
    expect(res.body.products).toHaveLength(1);
    expect(res.body.products[0].id).toBe(1);
    expect(res.body.totalCount).toBe(1);
  });

  test('filters by minCredit — excludes sellers with no reviews', async () => {
    mockProductFindMany.mockResolvedValue([sampleProducts[0]]);
    mockReviewAggregate.mockResolvedValue({ _avg: { rating: null }, _count: { rating: 0 } });

    const res = await request(app).get('/api/products/filter?minCredit=1');

    expect(res.status).toBe(200);
    expect(res.body.products).toHaveLength(0);
    expect(res.body.totalCount).toBe(0);
  });

  test('totalCount matches products array length (Req 3.6)', async () => {
    mockProductFindMany.mockResolvedValue(sampleProducts);

    const res = await request(app).get('/api/products/filter');

    expect(res.status).toBe(200);
    expect(res.body.totalCount).toBe(res.body.products.length);
  });

  test('only returns products with status Available', async () => {
    mockProductFindMany.mockResolvedValue([]);

    await request(app).get('/api/products/filter');

    expect(mockProductFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: 'Available' })
      })
    );
  });

  test('returns 500 when prisma throws error', async () => {
    mockProductFindMany.mockRejectedValue(new Error('DB error'));

    const res = await request(app).get('/api/products/filter');

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

// ==========================================
// Task 7.2: GET /api/meeting-points
// ==========================================
describe('GET /api/meeting-points', () => {
  test('returns all meeting points', async () => {
    const mockPoints = [
      { id: 1, name: 'โรงอาหารกรีน', zone: 'ในมหาวิทยาลัย' },
      { id: 2, name: 'SC Hall', zone: 'ในมหาวิทยาลัย' },
      { id: 3, name: 'ป้ายรถตู้', zone: 'ในมหาวิทยาลัย' },
      { id: 4, name: 'หอพักเชียงราก', zone: 'เชียงราก' },
      { id: 5, name: 'หอพักอินเตอร์โซน', zone: 'อินเตอร์โซน' }
    ];
    mockMeetingPointFindMany.mockResolvedValue(mockPoints);

    const res = await request(app).get('/api/meeting-points');

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(5);
    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0]).toHaveProperty('name');
    expect(res.body[0]).toHaveProperty('zone');
  });

  test('returns empty array when no meeting points exist', async () => {
    mockMeetingPointFindMany.mockResolvedValue([]);

    const res = await request(app).get('/api/meeting-points');

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('returns 500 when prisma throws error', async () => {
    mockMeetingPointFindMany.mockRejectedValue(new Error('DB error'));

    const res = await request(app).get('/api/meeting-points');

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

// ==========================================
// Task 7.3: GET /api/dormitory-zones
// ==========================================
describe('GET /api/dormitory-zones', () => {
  test('returns the three dormitory zones', async () => {
    const res = await request(app).get('/api/dormitory-zones');

    expect(res.status).toBe(200);
    expect(res.body).toEqual(['เชียงราก', 'อินเตอร์โซน', 'ในมหาวิทยาลัย']);
  });

  test('returns exactly 3 zones', async () => {
    const res = await request(app).get('/api/dormitory-zones');

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(3);
  });

  test('includes เชียงราก zone', async () => {
    const res = await request(app).get('/api/dormitory-zones');
    expect(res.body).toContain('เชียงราก');
  });

  test('includes อินเตอร์โซน zone', async () => {
    const res = await request(app).get('/api/dormitory-zones');
    expect(res.body).toContain('อินเตอร์โซน');
  });

  test('includes ในมหาวิทยาลัย zone', async () => {
    const res = await request(app).get('/api/dormitory-zones');
    expect(res.body).toContain('ในมหาวิทยาลัย');
  });
});
