/**
 * Unit Tests สำหรับ POST /api/transactions — UniMart Iteration 2
 * 
 * ทดสอบการสร้างธุรกรรมใหม่
 * Validates: Requirements 6.1, 6.7
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
const mockProductFindUnique = jest.fn();
const mockTransactionCreate = jest.fn();

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
    transaction: {
      create: mockTransactionCreate
    }
  }))
}));

jest.mock('axios');

const { app } = require('../server');

beforeEach(() => {
  jest.clearAllMocks();
});

describe('POST /api/transactions', () => {
  const buyerId = '11111111-1111-1111-1111-111111111111';
  const sellerId = '22222222-2222-2222-2222-222222222222';
  const productId = 1;

  const mockProduct = {
    id: productId,
    title: 'หนังสือ CN333',
    price: 250,
    status: 'AVAILABLE',
    ownerId: sellerId
  };

  test('returns 400 when buyerId is missing', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .send({ productId, type: 'SALE' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when productId is missing', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, type: 'SALE' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when type is missing', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 400 when type is invalid', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId, type: 'INVALID' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('returns 404 when product does not exist', async () => {
    mockProductFindUnique.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId: 999, type: 'SALE' });

    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test('returns 409 when product status is Reserved', async () => {
    mockProductFindUnique.mockResolvedValue({ ...mockProduct, status: 'Reserved' });

    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId, type: 'SALE' });

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toBe('สินค้านี้ถูกจองแล้ว');
  });

  test('creates transaction with PENDING status for SALE type', async () => {
    mockProductFindUnique.mockResolvedValue(mockProduct);

    const createdTransaction = {
      id: 1,
      buyerId,
      sellerId,
      productId,
      type: 'SALE',
      status: 'PENDING',
      price: 250,
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z'
    };
    mockTransactionCreate.mockResolvedValue(createdTransaction);

    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId, type: 'SALE' });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('PENDING');
    expect(res.body.buyerId).toBe(buyerId);
    expect(res.body.sellerId).toBe(sellerId);
    expect(res.body.productId).toBe(productId);
    expect(res.body.price).toBe(250);
    expect(res.body.type).toBe('SALE');
  });

  test('creates transaction with PENDING status for RENT type', async () => {
    mockProductFindUnique.mockResolvedValue(mockProduct);

    const createdTransaction = {
      id: 2,
      buyerId,
      sellerId,
      productId,
      type: 'RENT',
      status: 'PENDING',
      price: 250,
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z'
    };
    mockTransactionCreate.mockResolvedValue(createdTransaction);

    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId, type: 'RENT' });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('PENDING');
    expect(res.body.type).toBe('RENT');
  });

  test('uses product ownerId as sellerId', async () => {
    mockProductFindUnique.mockResolvedValue(mockProduct);
    mockTransactionCreate.mockResolvedValue({
      id: 3, buyerId, sellerId, productId, type: 'SALE', status: 'PENDING', price: 250
    });

    await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId, type: 'SALE' });

    expect(mockTransactionCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({
        sellerId: sellerId,
        buyerId: buyerId,
        productId: productId,
        price: 250,
        status: 'PENDING'
      })
    });
  });

  test('returns 500 when prisma throws an error', async () => {
    mockProductFindUnique.mockRejectedValue(new Error('DB connection failed'));

    const res = await request(app)
      .post('/api/transactions')
      .send({ buyerId, productId, type: 'SALE' });

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
