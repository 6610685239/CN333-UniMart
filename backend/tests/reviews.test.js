/**
 * Unit Tests สำหรับ Review System — UniMart Iteration 2
 * 
 * Task 6.1: POST /api/reviews — สร้างรีวิว (Requirements 2.1, 2.2, 2.6, 2.7)
 * Task 6.2: GET /api/reviews/user/:userId — ดึงรีวิวของผู้ใช้ (Requirements 2.4)
 * Task 6.3: GET /api/reviews/credit/:userId — ดึง Credit Score (Requirements 2.3, 2.4)
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
const mockTransactionFindUnique = jest.fn();
const mockReviewCreate = jest.fn();
const mockReviewFindMany = jest.fn();
const mockReviewAggregate = jest.fn();

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
      findUnique: mockTransactionFindUnique,
      create: jest.fn()
    },
    review: {
      create: mockReviewCreate,
      findMany: mockReviewFindMany,
      aggregate: mockReviewAggregate
    }
  }))
}));

jest.mock('axios');

const { app } = require('../server');

beforeEach(() => {
  jest.clearAllMocks();
});

// ==========================================
// Task 6.1: POST /api/reviews
// ==========================================
describe('POST /api/reviews', () => {
  const reviewerId = '11111111-1111-1111-1111-111111111111';
  const revieweeId = '22222222-2222-2222-2222-222222222222';
  const transactionId = 1;

  const completedTransaction = {
    id: transactionId,
    buyerId: reviewerId,
    sellerId: revieweeId,
    status: 'COMPLETED'
  };

  test('returns 400 when rating is less than 1', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 0, comment: 'test' });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('คะแนนดาวต้องอยู่ระหว่าง 1-5');
  });

  test('returns 400 when rating is greater than 5', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 6, comment: 'test' });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('คะแนนดาวต้องอยู่ระหว่าง 1-5');
  });

  test('returns 400 when rating is negative', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: -1 });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('คะแนนดาวต้องอยู่ระหว่าง 1-5');
  });

  test('returns 400 when rating is not an integer', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 3.5 });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('คะแนนดาวต้องอยู่ระหว่าง 1-5');
  });

  test('returns 404 when transaction does not exist', async () => {
    mockTransactionFindUnique.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId: 999, reviewerId, revieweeId, rating: 5 });

    expect(res.status).toBe(404);
    expect(res.body.message).toBe('ไม่พบธุรกรรม');
  });

  test('returns 403 when transaction is not COMPLETED', async () => {
    mockTransactionFindUnique.mockResolvedValue({ ...completedTransaction, status: 'PENDING' });

    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 5 });

    expect(res.status).toBe(403);
    expect(res.body.message).toBe('สามารถรีวิวได้เฉพาะธุรกรรมที่เสร็จสิ้นแล้ว');
  });

  test('returns 403 when transaction is PROCESSING', async () => {
    mockTransactionFindUnique.mockResolvedValue({ ...completedTransaction, status: 'PROCESSING' });

    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 4 });

    expect(res.status).toBe(403);
  });

  test('returns 409 when review already exists (duplicate)', async () => {
    mockTransactionFindUnique.mockResolvedValue(completedTransaction);
    const prismaError = new Error('Unique constraint failed');
    prismaError.code = 'P2002';
    mockReviewCreate.mockRejectedValue(prismaError);

    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 5, comment: 'ดีมาก' });

    expect(res.status).toBe(409);
    expect(res.body.message).toBe('คุณได้รีวิวธุรกรรมนี้แล้ว');
  });

  test('creates review successfully with rating and comment', async () => {
    mockTransactionFindUnique.mockResolvedValue(completedTransaction);
    const createdReview = {
      id: 1,
      transactionId,
      reviewerId,
      revieweeId,
      rating: 5,
      comment: 'ดีมาก',
      createdAt: '2025-01-01T00:00:00Z'
    };
    mockReviewCreate.mockResolvedValue(createdReview);

    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 5, comment: 'ดีมาก' });

    expect(res.status).toBe(201);
    expect(res.body.id).toBe(1);
    expect(res.body.rating).toBe(5);
    expect(res.body.comment).toBe('ดีมาก');
    expect(res.body.createdAt).toBeDefined();
  });

  test('creates review successfully without comment', async () => {
    mockTransactionFindUnique.mockResolvedValue(completedTransaction);
    mockReviewCreate.mockResolvedValue({
      id: 2, transactionId, reviewerId, revieweeId, rating: 3, comment: null, createdAt: '2025-01-01T00:00:00Z'
    });

    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 3 });

    expect(res.status).toBe(201);
    expect(res.body.rating).toBe(3);
    expect(res.body.comment).toBeNull();
  });

  test('returns 500 when prisma throws unexpected error', async () => {
    mockTransactionFindUnique.mockRejectedValue(new Error('DB connection failed'));

    const res = await request(app)
      .post('/api/reviews')
      .send({ transactionId, reviewerId, revieweeId, rating: 5 });

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});


// ==========================================
// Task 6.2: GET /api/reviews/user/:userId
// ==========================================
describe('GET /api/reviews/user/:userId', () => {
  const userId = '22222222-2222-2222-2222-222222222222';

  test('returns reviews for user sorted by createdAt descending', async () => {
    const mockReviews = [
      {
        id: 2, transactionId: 2, reviewerId: 'aaa', revieweeId: userId,
        rating: 5, comment: 'เยี่ยม', createdAt: '2025-01-02T00:00:00Z',
        reviewer: { display_name_th: 'สมชาย' }
      },
      {
        id: 1, transactionId: 1, reviewerId: 'bbb', revieweeId: userId,
        rating: 3, comment: 'พอใช้', createdAt: '2025-01-01T00:00:00Z',
        reviewer: { display_name_th: 'สมหญิง' }
      }
    ];
    mockReviewFindMany.mockResolvedValue(mockReviews);

    const res = await request(app).get(`/api/reviews/user/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
    expect(res.body[0].id).toBe(2);
    expect(res.body[0].reviewerName).toBe('สมชาย');
    expect(res.body[1].id).toBe(1);
    expect(res.body[1].reviewerName).toBe('สมหญิง');
  });

  test('returns empty array when user has no reviews', async () => {
    mockReviewFindMany.mockResolvedValue([]);

    const res = await request(app).get(`/api/reviews/user/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('includes all review fields in response', async () => {
    mockReviewFindMany.mockResolvedValue([{
      id: 1, transactionId: 10, reviewerId: 'aaa', revieweeId: userId,
      rating: 4, comment: 'ดี', createdAt: '2025-01-01T00:00:00Z',
      reviewer: { display_name_th: 'ทดสอบ' }
    }]);

    const res = await request(app).get(`/api/reviews/user/${userId}`);

    expect(res.status).toBe(200);
    const review = res.body[0];
    expect(review).toHaveProperty('id');
    expect(review).toHaveProperty('transactionId');
    expect(review).toHaveProperty('reviewerId');
    expect(review).toHaveProperty('revieweeId');
    expect(review).toHaveProperty('rating');
    expect(review).toHaveProperty('comment');
    expect(review).toHaveProperty('createdAt');
    expect(review).toHaveProperty('reviewerName');
  });

  test('calls findMany with correct params', async () => {
    mockReviewFindMany.mockResolvedValue([]);

    await request(app).get(`/api/reviews/user/${userId}`);

    expect(mockReviewFindMany).toHaveBeenCalledWith({
      where: { revieweeId: userId },
      include: { reviewer: { select: { display_name_th: true } } },
      orderBy: { createdAt: 'desc' }
    });
  });

  test('returns 500 when prisma throws error', async () => {
    mockReviewFindMany.mockRejectedValue(new Error('DB error'));

    const res = await request(app).get(`/api/reviews/user/${userId}`);

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

// ==========================================
// Task 6.3: GET /api/reviews/credit/:userId
// ==========================================
describe('GET /api/reviews/credit/:userId', () => {
  const userId = '22222222-2222-2222-2222-222222222222';

  test('returns average rating and total reviews', async () => {
    mockReviewAggregate.mockResolvedValue({
      _avg: { rating: 4.5 },
      _count: { rating: 10 }
    });

    const res = await request(app).get(`/api/reviews/credit/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body.averageRating).toBe(4.5);
    expect(res.body.totalReviews).toBe(10);
  });

  test('returns 0 average and 0 total when user has no reviews', async () => {
    mockReviewAggregate.mockResolvedValue({
      _avg: { rating: null },
      _count: { rating: 0 }
    });

    const res = await request(app).get(`/api/reviews/credit/${userId}`);

    expect(res.status).toBe(200);
    expect(res.body.averageRating).toBe(0);
    expect(res.body.totalReviews).toBe(0);
  });

  test('calls aggregate with correct params', async () => {
    mockReviewAggregate.mockResolvedValue({
      _avg: { rating: 3.0 },
      _count: { rating: 5 }
    });

    await request(app).get(`/api/reviews/credit/${userId}`);

    expect(mockReviewAggregate).toHaveBeenCalledWith({
      where: { revieweeId: userId },
      _avg: { rating: true },
      _count: { rating: true }
    });
  });

  test('returns 500 when prisma throws error', async () => {
    mockReviewAggregate.mockRejectedValue(new Error('DB error'));

    const res = await request(app).get(`/api/reviews/credit/${userId}`);

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
