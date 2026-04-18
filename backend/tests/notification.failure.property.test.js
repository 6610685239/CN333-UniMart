/**
 * Property-Based Test สำหรับ Notification Failure Isolation — UniMart Iteration 2 Wiring
 *
 * Feature: unimart-iteration-2-wiring, Property 3: Notification Failure ไม่ทำให้ Operation หลักล้มเหลว
 *
 * ทดสอบว่าถ้า notificationService.createNotification throw error,
 * transaction response ยังคง HTTP 2xx
 *
 * Validates: Requirements 4.5, 5.3
 */

const fc = require('fast-check');
const request = require('supertest');

// --- Mock notification service to THROW errors ---
const mockCreateNotification = jest.fn().mockRejectedValue(new Error('Notification service unavailable'));

jest.mock('../services/notification.service', () => ({
  createNotification: (...args) => mockCreateNotification(...args),
  sendFcmNotification: jest.fn().mockResolvedValue({ success: true })
}));

// --- Supabase mock ---
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

// --- Prisma mock ---
const mockTransactionFindUnique = jest.fn();
const mockTransactionUpdate = jest.fn();
const mockPrismaTransaction = jest.fn();

jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: { findMany: jest.fn().mockResolvedValue([]) },
    product: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
      findUnique: jest.fn().mockResolvedValue({ id: 1, status: 'RESERVED', quantity: 0 }),
      update: jest.fn(),
      delete: jest.fn()
    },
    transaction: {
      create: jest.fn(),
      findUnique: mockTransactionFindUnique,
      findMany: jest.fn().mockResolvedValue([]),
      update: mockTransactionUpdate,
      count: jest.fn().mockResolvedValue(0)
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
const actionArb = fc.constantFrom('confirm', 'ship', 'complete', 'cancel');

beforeEach(() => {
  jest.clearAllMocks();
  // Always make notification throw an error
  mockCreateNotification.mockRejectedValue(new Error('Notification service unavailable'));
});

// ============================================
// Property 3: Notification Failure ไม่ทำให้ Operation หลักล้มเหลว
// ============================================
describe('Feature: unimart-iteration-2-wiring, Property 3: Notification Failure ไม่ทำให้ Operation หลักล้มเหลว', () => {
  /**
   * **Validates: Requirements 4.5, 5.3**
   *
   * For any transaction operation that triggers a notification,
   * if notificationService.createNotification throws an error,
   * the HTTP response of the main operation must still be 2xx (200).
   */
  test('transaction response is still HTTP 200 even when notification service throws', async () => {
    const actionToFromStatus = {
      confirm: 'PENDING',
      ship: 'PROCESSING',
      complete: 'SHIPPING',
      cancel: 'PENDING'
    };

    await fc.assert(
      fc.asyncProperty(
        actionArb,
        uuidArb, // buyerId
        uuidArb, // sellerId
        async (action, buyerId, sellerId) => {
          fc.pre(buyerId !== sellerId);

          jest.clearAllMocks();
          // Re-set the mock to throw after clearAllMocks
          mockCreateNotification.mockRejectedValue(new Error('Notification service unavailable'));

          const txId = 1;
          const productId = 42;
          const fromStatus = actionToFromStatus[action];

          const baseTx = {
            id: txId,
            status: fromStatus,
            productId,
            buyerId,
            sellerId
          };
          mockTransactionFindUnique.mockResolvedValue(baseTx);

          // Mock the transition to succeed
          if (action === 'confirm') {
            const updatedTx = { ...baseTx, status: 'PROCESSING' };
            mockPrismaTransaction.mockResolvedValue([updatedTx, { id: productId, status: 'Reserved' }]);
          } else if (action === 'ship') {
            const updatedTx = { ...baseTx, status: 'SHIPPING' };
            mockTransactionUpdate.mockResolvedValue(updatedTx);
          } else if (action === 'complete') {
            const updatedTx = { ...baseTx, status: 'COMPLETED' };
            mockPrismaTransaction.mockResolvedValue([updatedTx, { id: productId, status: 'Sold' }]);
          } else if (action === 'cancel') {
            const updatedTx = { ...baseTx, status: 'CANCELED', canceledBy: buyerId, cancelReason: 'เปลี่ยนใจ' };
            mockPrismaTransaction.mockResolvedValue([updatedTx, { id: productId, status: 'Available' }]);
          }

          // Perform the request
          let res;
          if (action === 'cancel') {
            res = await request(app)
              .patch(`/api/transactions/${txId}/${action}`)
              .send({ canceledBy: buyerId, cancelReason: 'เปลี่ยนใจ' });
          } else {
            res = await request(app)
              .patch(`/api/transactions/${txId}/${action}`);
          }

          // The main operation must still succeed with HTTP 200
          // despite notification service throwing an error
          expect(res.status).toBe(200);

          // Wait a tick for fire-and-forget notification to attempt
          await new Promise(resolve => setImmediate(resolve));

          // Verify that createNotification was indeed called (and threw)
          expect(mockCreateNotification).toHaveBeenCalledTimes(1);
        }
      ),
      { numRuns: 100 }
    );
  }, 30000);
});
