/**
 * Property-Based Tests สำหรับ Transaction System — UniMart Iteration 2
 *
 * ใช้ fast-check สำหรับ property-based testing
 * Mock Prisma เพื่อ test logic ภายใน
 *
 * Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7
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
const mockTransactionCreate = jest.fn();
const mockTransactionFindUnique = jest.fn();
const mockTransactionFindMany = jest.fn();
const mockTransactionUpdate = jest.fn();
const mockProductFindUnique = jest.fn();
const mockProductUpdate = jest.fn();
const mockPrismaTransaction = jest.fn();

jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: { findMany: jest.fn().mockResolvedValue([]) },
    product: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
      findUnique: mockProductFindUnique,
      update: mockProductUpdate,
      delete: jest.fn()
    },
    transaction: {
      create: mockTransactionCreate,
      findUnique: mockTransactionFindUnique,
      findMany: mockTransactionFindMany,
      update: mockTransactionUpdate
    },
    users: { findUnique: jest.fn() },
    $transaction: mockPrismaTransaction
  }))
}));

jest.mock('axios');

const { app } = require('../server');

// ============================================
// Generators
// ============================================
const uuidArb = fc.uuid().filter(u => u.length > 0);
const productIdArb = fc.integer({ min: 1, max: 100000 });
const priceArb = fc.integer({ min: 1, max: 999999 });
const typeArb = fc.constantFrom('SALE', 'RENT');
const statusArb = fc.constantFrom('PENDING', 'PROCESSING', 'SHIPPING', 'COMPLETED', 'CANCELED');
const cancelReasonArb = fc.constantFrom('เปลี่ยนใจ', 'สินค้าหมด', 'ราคาไม่ตรง', 'อื่นๆ');

// Reset mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});

// ============================================
// Property 24: ธุรกรรมใหม่เริ่มต้นที่ PENDING
// ============================================
describe('Feature: unimart-iteration-2, Property 24: ธุรกรรมใหม่เริ่มต้นที่ PENDING', () => {
  /**
   * Validates: Requirements 6.1
   * For any new transaction, initial status should always be PENDING
   */
  test('new transaction always starts with PENDING status', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        productIdArb,
        priceArb,
        typeArb,
        uuidArb,
        async (buyerId, productId, price, type, sellerId) => {
          fc.pre(buyerId !== sellerId);

          // Mock product exists and is available
          mockProductFindUnique.mockResolvedValue({
            id: productId,
            title: 'Test Product',
            price: price,
            status: 'AVAILABLE',
            ownerId: sellerId
          });

          // Capture what gets created
          let capturedData = null;
          mockTransactionCreate.mockImplementation(({ data }) => {
            capturedData = data;
            return Promise.resolve({
              id: 1,
              ...data,
              createdAt: new Date().toISOString(),
              updatedAt: new Date().toISOString()
            });
          });

          const res = await request(app)
            .post('/api/transactions')
            .send({ buyerId, productId, type });

          expect(res.status).toBe(201);
          expect(res.body.status).toBe('PENDING');
          expect(capturedData).toBeDefined();
          expect(capturedData.status).toBe('PENDING');
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ============================================
// Property 25: State Transition ถูกต้องตามวงจรชีวิต
// ============================================
describe('Feature: unimart-iteration-2, Property 25: State Transition ถูกต้องตามวงจรชีวิต', () => {
  /**
   * Validates: Requirements 6.2, 6.3, 6.4
   * State transitions follow lifecycle:
   * PENDING → PROCESSING (confirm), PROCESSING → SHIPPING (ship), SHIPPING → COMPLETED (complete)
   * Invalid transitions should be rejected with 400
   */
  test('valid transitions succeed and invalid transitions are rejected', async () => {
    // Define valid transitions and their endpoints
    const validTransitions = [
      { from: 'PENDING', to: 'PROCESSING', endpoint: 'confirm' },
      { from: 'PROCESSING', to: 'SHIPPING', endpoint: 'ship' },
      { from: 'SHIPPING', to: 'COMPLETED', endpoint: 'complete' }
    ];

    // Define all endpoints and which statuses are invalid for each
    const allEndpoints = [
      { endpoint: 'confirm', validFrom: 'PENDING' },
      { endpoint: 'ship', validFrom: 'PROCESSING' },
      { endpoint: 'complete', validFrom: 'SHIPPING' }
    ];

    const allStatuses = ['PENDING', 'PROCESSING', 'SHIPPING', 'COMPLETED', 'CANCELED'];

    await fc.assert(
      fc.asyncProperty(
        fc.constantFrom(...allEndpoints),
        fc.constantFrom(...allStatuses),
        productIdArb,
        uuidArb,
        uuidArb,
        async (endpointInfo, currentStatus, productId, buyerId, sellerId) => {
          fc.pre(buyerId !== sellerId);

          const txId = 1;
          const isValid = currentStatus === endpointInfo.validFrom;

          mockTransactionFindUnique.mockResolvedValue({
            id: txId,
            status: currentStatus,
            productId,
            buyerId,
            sellerId
          });

          if (isValid) {
            const transition = validTransitions.find(t => t.endpoint === endpointInfo.endpoint);
            if (endpointInfo.endpoint === 'confirm') {
              mockPrismaTransaction.mockResolvedValue([
                { id: txId, status: transition.to, productId, buyerId, sellerId },
                { id: productId, status: 'Reserved' }
              ]);
            } else if (endpointInfo.endpoint === 'ship') {
              mockTransactionUpdate.mockResolvedValue({
                id: txId, status: transition.to, productId, buyerId, sellerId
              });
            } else if (endpointInfo.endpoint === 'complete') {
              mockPrismaTransaction.mockResolvedValue([
                { id: txId, status: transition.to, productId, buyerId, sellerId },
                { id: productId, status: 'Sold' }
              ]);
            }
          }

          const res = await request(app)
            .patch(`/api/transactions/${txId}/${endpointInfo.endpoint}`);

          if (isValid) {
            expect(res.status).toBe(200);
            const transition = validTransitions.find(t => t.endpoint === endpointInfo.endpoint);
            expect(res.body.status).toBe(transition.to);
          } else {
            expect(res.status).toBe(400);
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ============================================
// Property 26: ยกเลิกได้เฉพาะก่อน Shipping
// ============================================
describe('Feature: unimart-iteration-2, Property 26: ยกเลิกได้เฉพาะก่อน Shipping', () => {
  /**
   * Validates: Requirements 6.5
   * Cancel only works for PENDING or PROCESSING.
   * SHIPPING/COMPLETED/CANCELED → cancel should return 400
   */
  test('cancel succeeds for PENDING/PROCESSING and fails for SHIPPING/COMPLETED/CANCELED', async () => {
    await fc.assert(
      fc.asyncProperty(
        statusArb,
        productIdArb,
        uuidArb,
        uuidArb,
        cancelReasonArb,
        async (currentStatus, productId, buyerId, sellerId, reason) => {
          fc.pre(buyerId !== sellerId);

          const txId = 1;
          const canCancel = ['PENDING', 'PROCESSING'].includes(currentStatus);

          mockTransactionFindUnique.mockResolvedValue({
            id: txId,
            status: currentStatus,
            productId,
            buyerId,
            sellerId
          });

          if (canCancel) {
            mockPrismaTransaction.mockResolvedValue([
              {
                id: txId, status: 'CANCELED', productId, buyerId, sellerId,
                canceledBy: buyerId, cancelReason: reason
              },
              { id: productId, status: 'Available' }
            ]);
          }

          const res = await request(app)
            .patch(`/api/transactions/${txId}/cancel`)
            .send({ canceledBy: buyerId, cancelReason: reason });

          if (canCancel) {
            expect(res.status).toBe(200);
            expect(res.body.status).toBe('CANCELED');
          } else {
            expect(res.status).toBe(400);
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ============================================
// Property 27: ธุรกรรมจัดกลุ่มตามสถานะถูกต้อง
// ============================================
describe('Feature: unimart-iteration-2, Property 27: ธุรกรรมจัดกลุ่มตามสถานะถูกต้อง', () => {
  /**
   * Validates: Requirements 6.6
   * GET /api/transactions/user/:userId groups correctly:
   * processing = PENDING + PROCESSING, shipping = SHIPPING,
   * history = COMPLETED, canceled = CANCELED
   */
  test('transactions are grouped by status correctly', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        fc.array(
          fc.record({
            status: statusArb,
            productId: productIdArb,
            type: typeArb,
            price: priceArb
          }),
          { minLength: 1, maxLength: 20 }
        ),
        async (userId, txSpecs) => {
          // Build mock transactions from specs
          const mockTransactions = txSpecs.map((spec, i) => ({
            id: i + 1,
            buyerId: userId,
            sellerId: 'seller-uuid',
            productId: spec.productId,
            status: spec.status,
            type: spec.type,
            price: spec.price,
            updatedAt: new Date(Date.now() - i * 60000).toISOString(),
            product: { id: spec.productId, title: `Product ${i}`, price: spec.price, images: [], status: 'AVAILABLE' },
            buyer: { id: userId, display_name_th: 'ผู้ซื้อ', username: 'buyer' },
            seller: { id: 'seller-uuid', display_name_th: 'ผู้ขาย', username: 'seller' }
          }));

          mockTransactionFindMany.mockResolvedValue(mockTransactions);

          const res = await request(app)
            .get(`/api/transactions/user/${userId}`);

          expect(res.status).toBe(200);

          // Verify grouping
          const { processing, shipping, history, canceled } = res.body;

          // processing should contain PENDING and PROCESSING
          for (const tx of processing) {
            expect(['PENDING', 'PROCESSING']).toContain(tx.status);
          }

          // shipping should contain only SHIPPING
          for (const tx of shipping) {
            expect(tx.status).toBe('SHIPPING');
          }

          // history should contain only COMPLETED
          for (const tx of history) {
            expect(tx.status).toBe('COMPLETED');
          }

          // canceled should contain only CANCELED
          for (const tx of canceled) {
            expect(tx.status).toBe('CANCELED');
          }

          // Total count should match
          const totalGrouped = processing.length + shipping.length + history.length + canceled.length;
          expect(totalGrouped).toBe(mockTransactions.length);
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ============================================
// Property 28: ห้ามสร้างธุรกรรมซ้ำสำหรับสินค้าที่จองแล้ว
// ============================================
describe('Feature: unimart-iteration-2, Property 28: ห้ามสร้างธุรกรรมซ้ำสำหรับสินค้าที่จองแล้ว', () => {
  /**
   * Validates: Requirements 6.7
   * POST /api/transactions for a product with status "Reserved" should return 409
   */
  test('creating transaction for Reserved product returns 409', async () => {
    await fc.assert(
      fc.asyncProperty(
        uuidArb,
        productIdArb,
        priceArb,
        typeArb,
        uuidArb,
        async (buyerId, productId, price, type, sellerId) => {
          fc.pre(buyerId !== sellerId);

          // Product is already Reserved
          mockProductFindUnique.mockResolvedValue({
            id: productId,
            title: 'Reserved Product',
            price: price,
            status: 'Reserved',
            ownerId: sellerId
          });

          const res = await request(app)
            .post('/api/transactions')
            .send({ buyerId, productId, type });

          expect(res.status).toBe(409);
          expect(res.body.success).toBe(false);
          expect(res.body.message).toBe('สินค้านี้ถูกจองแล้ว');
        }
      ),
      { numRuns: 100 }
    );
  });
});
