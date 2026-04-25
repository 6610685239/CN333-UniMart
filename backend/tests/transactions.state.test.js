/**
 * Unit Tests สำหรับ Transaction State Transitions — UniMart Iteration 2
 *
 * 5.2 PATCH /api/transactions/:id/confirm (PENDING → PROCESSING)
 * 5.3 PATCH /api/transactions/:id/ship (PROCESSING → SHIPPING)
 * 5.4 PATCH /api/transactions/:id/complete (SHIPPING → COMPLETED)
 * 5.5 PATCH /api/transactions/:id/cancel (PENDING/PROCESSING → CANCELED)
 * 5.6 GET /api/transactions/user/:userId
 *
 * Validates: Requirements 6.2, 6.3, 6.4, 6.5, 6.6
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
const mockTransactionFindMany = jest.fn();
const mockTransactionUpdate = jest.fn();
const mockProductUpdate = jest.fn();
const mockPrismaTransaction = jest.fn();

jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: { findMany: jest.fn().mockResolvedValue([]) },
    product: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
      findUnique: jest.fn(),
      update: mockProductUpdate,
      delete: jest.fn()
    },
    transaction: {
      create: jest.fn(),
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

beforeEach(() => {
  jest.clearAllMocks();
});

const buyerId = '11111111-1111-1111-1111-111111111111';
const sellerId = '22222222-2222-2222-2222-222222222222';

// ==========================================
// 5.2 PATCH /api/transactions/:id/confirm
// Validates: Requirements 6.2
// ==========================================
describe('PATCH /api/transactions/:id/confirm', () => {
  test('returns 404 when transaction not found', async () => {
    mockTransactionFindUnique.mockResolvedValue(null);

    const res = await request(app).patch('/api/transactions/999/confirm');

    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toBe('ไม่พบธุรกรรม');
  });

  test('returns 400 when status is not PENDING', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'PROCESSING', productId: 1, buyerId, sellerId
    });

    const res = await request(app).patch('/api/transactions/1/confirm');

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toContain('PROCESSING');
    expect(res.body.message).toContain('PROCESSING');
  });

  test('transitions PENDING → PROCESSING and sets product to Reserved', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'PENDING', productId: 10, buyerId, sellerId
    });

    const updatedTx = { id: 1, status: 'PROCESSING', productId: 10, buyerId, sellerId };
    mockPrismaTransaction.mockResolvedValue([updatedTx, { id: 10, status: 'Reserved' }]);

    const res = await request(app).patch('/api/transactions/1/confirm');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('PROCESSING');
    expect(mockPrismaTransaction).toHaveBeenCalled();
  });

  test('returns 400 when trying to confirm a COMPLETED transaction', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'COMPLETED', productId: 1, buyerId, sellerId
    });

    const res = await request(app).patch('/api/transactions/1/confirm');

    expect(res.status).toBe(400);
  });

  test('returns 400 when trying to confirm a CANCELED transaction', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'CANCELED', productId: 1, buyerId, sellerId
    });

    const res = await request(app).patch('/api/transactions/1/confirm');

    expect(res.status).toBe(400);
  });

  test('returns 500 when prisma throws an error', async () => {
    mockTransactionFindUnique.mockRejectedValue(new Error('DB error'));

    const res = await request(app).patch('/api/transactions/1/confirm');

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

// ==========================================
// 5.3 PATCH /api/transactions/:id/ship
// Validates: Requirements 6.3
// ==========================================
describe('PATCH /api/transactions/:id/ship', () => {
  test('returns 404 when transaction not found', async () => {
    mockTransactionFindUnique.mockResolvedValue(null);

    const res = await request(app).patch('/api/transactions/999/ship');

    expect(res.status).toBe(404);
    expect(res.body.message).toBe('ไม่พบธุรกรรม');
  });

  test('returns 400 when status is not PROCESSING', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'PENDING', productId: 1, buyerId, sellerId
    });

    const res = await request(app).patch('/api/transactions/1/ship');

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('PENDING');
    expect(res.body.message).toContain('SHIPPING');
  });

  test('transitions PROCESSING → SHIPPING', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'PROCESSING', productId: 10, buyerId, sellerId
    });

    const updatedTx = { id: 1, status: 'SHIPPING', productId: 10, buyerId, sellerId };
    mockTransactionUpdate.mockResolvedValue(updatedTx);

    const res = await request(app).patch('/api/transactions/1/ship');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('SHIPPING');
  });

  test('returns 400 when trying to ship a SHIPPING transaction', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'SHIPPING', productId: 1, buyerId, sellerId
    });

    const res = await request(app).patch('/api/transactions/1/ship');

    expect(res.status).toBe(400);
  });

  test('returns 500 when prisma throws an error', async () => {
    mockTransactionFindUnique.mockRejectedValue(new Error('DB error'));

    const res = await request(app).patch('/api/transactions/1/ship');

    expect(res.status).toBe(500);
  });
});

// ==========================================
// 5.4 PATCH /api/transactions/:id/complete
// Validates: Requirements 6.4
// ==========================================
describe('PATCH /api/transactions/:id/complete', () => {
  test('returns 404 when transaction not found', async () => {
    mockTransactionFindUnique.mockResolvedValue(null);

    const res = await request(app).patch('/api/transactions/999/complete');

    expect(res.status).toBe(404);
    expect(res.body.message).toBe('ไม่พบธุรกรรม');
  });

  test('returns 400 when status is not SHIPPING', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'PROCESSING', productId: 1, buyerId, sellerId
    });

    const res = await request(app).patch('/api/transactions/1/complete');

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('PROCESSING');
    expect(res.body.message).toContain('COMPLETED');
  });

  test('transitions SHIPPING → COMPLETED and sets product to Sold', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'SHIPPING', productId: 10, buyerId, sellerId
    });

    const updatedTx = { id: 1, status: 'COMPLETED', productId: 10, buyerId, sellerId };
    mockPrismaTransaction.mockResolvedValue([updatedTx, { id: 10, status: 'Sold' }]);

    const res = await request(app).patch('/api/transactions/1/complete');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('COMPLETED');
    expect(mockPrismaTransaction).toHaveBeenCalled();
  });

  test('returns 400 when trying to complete a PENDING transaction', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'PENDING', productId: 1, buyerId, sellerId
    });

    const res = await request(app).patch('/api/transactions/1/complete');

    expect(res.status).toBe(400);
  });

  test('returns 500 when prisma throws an error', async () => {
    mockTransactionFindUnique.mockRejectedValue(new Error('DB error'));

    const res = await request(app).patch('/api/transactions/1/complete');

    expect(res.status).toBe(500);
  });
});

// ==========================================
// 5.5 PATCH /api/transactions/:id/cancel
// Validates: Requirements 6.5
// ==========================================
describe('PATCH /api/transactions/:id/cancel', () => {
  test('returns 404 when transaction not found', async () => {
    mockTransactionFindUnique.mockResolvedValue(null);

    const res = await request(app)
      .patch('/api/transactions/999/cancel')
      .send({ canceledBy: buyerId, cancelReason: 'เปลี่ยนใจ' });

    expect(res.status).toBe(404);
    expect(res.body.message).toBe('ไม่พบธุรกรรม');
  });

  test('cancels PENDING transaction successfully', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'PENDING', productId: 10, buyerId, sellerId
    });

    const updatedTx = {
      id: 1, status: 'CANCELED', productId: 10, buyerId, sellerId,
      canceledBy: buyerId, cancelReason: 'เปลี่ยนใจ'
    };
    mockPrismaTransaction.mockResolvedValue([updatedTx, { id: 10, status: 'Available' }]);

    const res = await request(app)
      .patch('/api/transactions/1/cancel')
      .send({ canceledBy: buyerId, cancelReason: 'เปลี่ยนใจ' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('CANCELED');
    expect(res.body.canceledBy).toBe(buyerId);
    expect(res.body.cancelReason).toBe('เปลี่ยนใจ');
  });

  test('cancels PROCESSING transaction successfully', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 2, status: 'PROCESSING', productId: 10, buyerId, sellerId
    });

    const updatedTx = {
      id: 2, status: 'CANCELED', productId: 10, buyerId, sellerId,
      canceledBy: sellerId, cancelReason: 'สินค้าหมด'
    };
    mockPrismaTransaction.mockResolvedValue([updatedTx, { id: 10, status: 'Available' }]);

    const res = await request(app)
      .patch('/api/transactions/2/cancel')
      .send({ canceledBy: sellerId, cancelReason: 'สินค้าหมด' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('CANCELED');
  });

  test('returns 400 when trying to cancel SHIPPING transaction', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'SHIPPING', productId: 1, buyerId, sellerId
    });

    const res = await request(app)
      .patch('/api/transactions/1/cancel')
      .send({ canceledBy: buyerId, cancelReason: 'test' });

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('SHIPPING');
  });

  test('returns 400 when trying to cancel COMPLETED transaction', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'COMPLETED', productId: 1, buyerId, sellerId
    });

    const res = await request(app)
      .patch('/api/transactions/1/cancel')
      .send({ canceledBy: buyerId, cancelReason: 'test' });

    expect(res.status).toBe(400);
  });

  test('returns 400 when trying to cancel already CANCELED transaction', async () => {
    mockTransactionFindUnique.mockResolvedValue({
      id: 1, status: 'CANCELED', productId: 1, buyerId, sellerId
    });

    const res = await request(app)
      .patch('/api/transactions/1/cancel')
      .send({ canceledBy: buyerId, cancelReason: 'test' });

    expect(res.status).toBe(400);
  });

  test('returns 500 when prisma throws an error', async () => {
    mockTransactionFindUnique.mockRejectedValue(new Error('DB error'));

    const res = await request(app)
      .patch('/api/transactions/1/cancel')
      .send({ canceledBy: buyerId, cancelReason: 'test' });

    expect(res.status).toBe(500);
  });
});

// ==========================================
// 5.6 GET /api/transactions/user/:userId
// Validates: Requirements 6.6
// ==========================================
describe('GET /api/transactions/user/:userId', () => {
  const mockTransactions = [
    { id: 1, buyerId, sellerId, productId: 10, status: 'PENDING', type: 'SALE', price: 100, reviews: [], product: { id: 10, title: 'Book', price: 100, images: [], status: 'AVAILABLE' }, buyer: { id: buyerId, display_name_th: 'ผู้ซื้อ', username: 'buyer1' }, seller: { id: sellerId, display_name_th: 'ผู้ขาย', username: 'seller1' }, updatedAt: '2025-01-01' },
    { id: 2, buyerId, sellerId, productId: 11, status: 'PROCESSING', type: 'SALE', price: 200, reviews: [], product: { id: 11, title: 'Pen', price: 200, images: [], status: 'Reserved' }, buyer: { id: buyerId, display_name_th: 'ผู้ซื้อ', username: 'buyer1' }, seller: { id: sellerId, display_name_th: 'ผู้ขาย', username: 'seller1' }, updatedAt: '2025-01-02' },
    { id: 3, buyerId, sellerId, productId: 12, status: 'SHIPPING', type: 'RENT', price: 50, reviews: [], product: { id: 12, title: 'Bag', price: 50, images: [], status: 'Reserved' }, buyer: { id: buyerId, display_name_th: 'ผู้ซื้อ', username: 'buyer1' }, seller: { id: sellerId, display_name_th: 'ผู้ขาย', username: 'seller1' }, updatedAt: '2025-01-03' },
    { id: 4, buyerId, sellerId, productId: 13, status: 'COMPLETED', type: 'SALE', price: 300, reviews: [], product: { id: 13, title: 'Phone', price: 300, images: [], status: 'Sold' }, buyer: { id: buyerId, display_name_th: 'ผู้ซื้อ', username: 'buyer1' }, seller: { id: sellerId, display_name_th: 'ผู้ขาย', username: 'seller1' }, updatedAt: '2025-01-04' },
    { id: 5, buyerId, sellerId, productId: 14, status: 'CANCELED', type: 'SALE', price: 150, reviews: [], product: { id: 14, title: 'Hat', price: 150, images: [], status: 'AVAILABLE' }, buyer: { id: buyerId, display_name_th: 'ผู้ซื้อ', username: 'buyer1' }, seller: { id: sellerId, display_name_th: 'ผู้ขาย', username: 'seller1' }, updatedAt: '2025-01-05' }
  ];

  test('returns grouped transactions for a user', async () => {
    mockTransactionFindMany.mockResolvedValue(mockTransactions);

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('processing');
    expect(res.body).toHaveProperty('shipping');
    expect(res.body).toHaveProperty('history');
    expect(res.body).toHaveProperty('canceled');
  });

  test('groups PENDING and PROCESSING into processing', async () => {
    mockTransactionFindMany.mockResolvedValue(mockTransactions);

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    expect(res.body.processing).toHaveLength(2);
    expect(res.body.processing.every(t => ['PENDING', 'PROCESSING'].includes(t.status))).toBe(true);
  });

  test('groups SHIPPING correctly', async () => {
    mockTransactionFindMany.mockResolvedValue(mockTransactions);

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    expect(res.body.shipping).toHaveLength(1);
    expect(res.body.shipping[0].status).toBe('SHIPPING');
  });

  test('groups COMPLETED into history', async () => {
    mockTransactionFindMany.mockResolvedValue(mockTransactions);

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    expect(res.body.history).toHaveLength(1);
    expect(res.body.history[0].status).toBe('COMPLETED');
  });

  test('groups CANCELED correctly', async () => {
    mockTransactionFindMany.mockResolvedValue(mockTransactions);

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    expect(res.body.canceled).toHaveLength(1);
    expect(res.body.canceled[0].status).toBe('CANCELED');
  });

  test('includes product and user info', async () => {
    mockTransactionFindMany.mockResolvedValue(mockTransactions);

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    const firstProcessing = res.body.processing[0];
    expect(firstProcessing.product).toBeDefined();
    expect(firstProcessing.product.title).toBeDefined();
    expect(firstProcessing.buyer).toBeDefined();
    expect(firstProcessing.seller).toBeDefined();
  });

  test('returns empty groups when user has no transactions', async () => {
    mockTransactionFindMany.mockResolvedValue([]);

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    expect(res.status).toBe(200);
    expect(res.body.processing).toHaveLength(0);
    expect(res.body.shipping).toHaveLength(0);
    expect(res.body.history).toHaveLength(0);
    expect(res.body.canceled).toHaveLength(0);
  });

  test('returns 500 when prisma throws an error', async () => {
    mockTransactionFindMany.mockRejectedValue(new Error('DB error'));

    const res = await request(app).get(`/api/transactions/user/${buyerId}`);

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
