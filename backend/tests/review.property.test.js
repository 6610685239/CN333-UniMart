/**
 * Property-Based Tests สำหรับ Review System — UniMart Iteration 2
 *
 * ใช้ fast-check สำหรับ property-based testing
 * Mock Prisma เพื่อ test logic ภายใน
 *
 * Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7
 */

const fc = require('fast-check');
const request = require('supertest');

// Mock Supabase ก่อน require server
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

// ============================================
// Generators
// ============================================
const uuidArb = fc.uuid().filter(u => u.length > 0);
const ratingArb = fc.integer({ min: 1, max: 5 });
const commentArb = fc.oneof(
  fc.constant(null),
  fc.string({ minLength: 1, maxLength: 200 }).filter(s => s.trim().length > 0 && !s.includes('\x00'))
);
const transactionIdArb = fc.integer({ min: 1, max: 100000 });
const nonCompletedStatusArb = fc.constantFrom('PENDING', 'PROCESSING', 'SHIPPING', 'CANCELED');

// Reset mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});


// ============================================
// Property 6: รีวิวได้เฉพาะธุรกรรมที่เสร็จสิ้น
// ============================================
describe('Feature: unimart-iteration-2, Property 6: รีวิวได้เฉพาะธุรกรรมที่เสร็จสิ้น', () => {
  /**
   * Validates: Requirements 2.1, 2.2
   * For any COMPLETED transaction, review creation should succeed.
   * For any non-COMPLETED transaction, review should be rejected with 403.
   */
  test('COMPLETED transactions allow review, non-COMPLETED are rejected with 403', async () => {
    await fc.assert(
      fc.asyncProperty(
        transactionIdArb,
        uuidArb,
        uuidArb,
        ratingArb,
        commentArb,
        nonCompletedStatusArb,
        async (txnId, reviewerId, revieweeId, rating, comment, badStatus) => {
          fc.pre(reviewerId !== revieweeId);

          // --- Part A: COMPLETED transaction should succeed ---
          mockTransactionFindUnique.mockResolvedValueOnce({
            id: txnId,
            buyerId: reviewerId,
            sellerId: revieweeId,
            status: 'COMPLETED'
          });

          const createdReview = {
            id: txnId,
            transactionId: txnId,
            reviewerId,
            revieweeId,
            rating,
            comment,
            createdAt: new Date().toISOString()
          };
          mockReviewCreate.mockResolvedValueOnce(createdReview);

          const successRes = await request(app)
            .post('/api/reviews')
            .send({ transactionId: txnId, reviewerId, revieweeId, rating, comment });

          expect(successRes.status).toBe(201);
          expect(successRes.body.rating).toBe(rating);

          // --- Part B: Non-COMPLETED transaction should be rejected ---
          mockTransactionFindUnique.mockResolvedValueOnce({
            id: txnId,
            buyerId: reviewerId,
            sellerId: revieweeId,
            status: badStatus
          });

          const failRes = await request(app)
            .post('/api/reviews')
            .send({ transactionId: txnId, reviewerId, revieweeId, rating, comment });

          expect(failRes.status).toBe(403);
          expect(failRes.body.success).toBe(false);
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 7: Credit Score เท่ากับค่าเฉลี่ยคะแนนดาว
// ============================================
describe('Feature: unimart-iteration-2, Property 7: Credit Score เท่ากับค่าเฉลี่ยคะแนนดาว', () => {
  /**
   * Validates: Requirements 2.3
   * For any set of ratings, the credit score (averageRating) should equal
   * the arithmetic mean of all ratings.
   */
  test('credit score equals arithmetic mean of all ratings', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        fc.array(ratingArb, { minLength: 1, maxLength: 50 }),
        async (userId, ratings) => {
          const sum = ratings.reduce((a, b) => a + b, 0);
          const expectedAvg = sum / ratings.length;

          // Mock Prisma aggregate to return the computed average
          mockReviewAggregate.mockResolvedValueOnce({
            _avg: { rating: expectedAvg },
            _count: { rating: ratings.length }
          });

          const res = await request(app)
            .get(`/api/reviews/credit/${userId}`);

          expect(res.status).toBe(200);
          expect(res.body.totalReviews).toBe(ratings.length);
          // Compare with tolerance for floating point
          expect(Math.abs(res.body.averageRating - expectedAvg)).toBeLessThan(0.0001);
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 8: โปรไฟล์แสดงข้อมูลรีวิวครบถ้วน
// ============================================
describe('Feature: unimart-iteration-2, Property 8: โปรไฟล์แสดงข้อมูลรีวิวครบถ้วน', () => {
  /**
   * Validates: Requirements 2.4
   * For any user with reviews, GET /api/reviews/user/:userId should return
   * reviews with all required fields.
   */
  test('user reviews contain all required fields', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        fc.array(
          fc.record({
            id: fc.integer({ min: 1, max: 100000 }),
            transactionId: transactionIdArb,
            reviewerId: uuidArb,
            rating: ratingArb,
            comment: commentArb,
            reviewerName: fc.string({ minLength: 1, maxLength: 50 }).filter(s => s.trim().length > 0)
          }),
          { minLength: 1, maxLength: 10 }
        ),
        async (userId, reviewInputs) => {
          // Build mock data matching Prisma's include format
          const mockReviews = reviewInputs.map(r => ({
            id: r.id,
            transactionId: r.transactionId,
            reviewerId: r.reviewerId,
            revieweeId: userId,
            rating: r.rating,
            comment: r.comment,
            createdAt: new Date().toISOString(),
            reviewer: { display_name_th: r.reviewerName }
          }));

          mockReviewFindMany.mockResolvedValueOnce(mockReviews);

          const res = await request(app)
            .get(`/api/reviews/user/${userId}`);

          expect(res.status).toBe(200);
          expect(res.body.length).toBe(reviewInputs.length);

          for (const review of res.body) {
            expect(review).toHaveProperty('id');
            expect(review).toHaveProperty('transactionId');
            expect(review).toHaveProperty('reviewerId');
            expect(review).toHaveProperty('revieweeId');
            expect(review).toHaveProperty('rating');
            expect(review).toHaveProperty('comment');
            expect(review).toHaveProperty('createdAt');
            expect(review).toHaveProperty('reviewerName');
            expect(review.revieweeId).toBe(userId);
            expect(review.rating).toBeGreaterThanOrEqual(1);
            expect(review.rating).toBeLessThanOrEqual(5);
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 9: กรองสินค้าตามความน่าเชื่อถือ
// ============================================
describe('Feature: unimart-iteration-2, Property 9: กรองสินค้าตามความน่าเชื่อถือ', () => {
  /**
   * Validates: Requirements 2.5
   * SKIP — filter endpoint not built yet
   */
  test.todo('products filtered by minCredit only include sellers with credit >= threshold');
});


// ============================================
// Property 10: ห้ามรีวิวซ้ำ
// ============================================
describe('Feature: unimart-iteration-2, Property 10: ห้ามรีวิวซ้ำ', () => {
  /**
   * Validates: Requirements 2.6
   * For any transaction where a review already exists, attempting to create
   * another review with the same reviewer should be rejected with 409.
   */
  test('duplicate review for same transaction+reviewer is rejected with 409', async () => {
    await fc.assert(
      fc.asyncProperty(
        transactionIdArb,
        uuidArb,
        uuidArb,
        ratingArb,
        ratingArb,
        async (txnId, reviewerId, revieweeId, firstRating, secondRating) => {
          fc.pre(reviewerId !== revieweeId);

          const completedTxn = {
            id: txnId,
            buyerId: reviewerId,
            sellerId: revieweeId,
            status: 'COMPLETED'
          };

          // First review succeeds
          mockTransactionFindUnique.mockResolvedValueOnce(completedTxn);
          mockReviewCreate.mockResolvedValueOnce({
            id: 1,
            transactionId: txnId,
            reviewerId,
            revieweeId,
            rating: firstRating,
            comment: null,
            createdAt: new Date().toISOString()
          });

          const firstRes = await request(app)
            .post('/api/reviews')
            .send({ transactionId: txnId, reviewerId, revieweeId, rating: firstRating });

          expect(firstRes.status).toBe(201);

          // Second review with same reviewer → Prisma unique constraint error
          mockTransactionFindUnique.mockResolvedValueOnce(completedTxn);
          const prismaError = new Error('Unique constraint failed');
          prismaError.code = 'P2002';
          mockReviewCreate.mockRejectedValueOnce(prismaError);

          const secondRes = await request(app)
            .post('/api/reviews')
            .send({ transactionId: txnId, reviewerId, revieweeId, rating: secondRating });

          expect(secondRes.status).toBe(409);
          expect(secondRes.body.success).toBe(false);
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 11: คะแนนดาวต้องอยู่ในช่วง 1-5
// ============================================
describe('Feature: unimart-iteration-2, Property 11: คะแนนดาวต้องอยู่ในช่วง 1-5', () => {
  /**
   * Validates: Requirements 2.7
   * For any rating value outside 1-5, review creation should be rejected with 400.
   */
  test('invalid ratings outside 1-5 are rejected with 400', async () => {
    const invalidRatingArb = fc.oneof(
      fc.integer({ min: -1000, max: 0 }),
      fc.integer({ min: 6, max: 1000 })
    );

    await fc.assert(
      fc.asyncProperty(
        transactionIdArb,
        uuidArb,
        uuidArb,
        invalidRatingArb,
        async (txnId, reviewerId, revieweeId, badRating) => {
          fc.pre(reviewerId !== revieweeId);

          // The server should reject before even checking the transaction
          const res = await request(app)
            .post('/api/reviews')
            .send({ transactionId: txnId, reviewerId, revieweeId, rating: badRating });

          expect(res.status).toBe(400);
          expect(res.body.success).toBe(false);

          // Prisma should NOT have been called since validation fails first
          expect(mockTransactionFindUnique).not.toHaveBeenCalled();
          expect(mockReviewCreate).not.toHaveBeenCalled();
        }
      ),
      { numRuns: 100 }
    );
  });
});
