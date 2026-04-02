/**
 * Property-Based Test สำหรับ Transaction Notification — UniMart Iteration 2 Wiring
 *
 * Feature: unimart-iteration-2-wiring, Property 2: Transaction State Transition สร้าง Notification
 *
 * ทดสอบว่าทุก state transition (confirm, ship, complete, cancel) สร้าง notification 1 รายการ
 * โดย user_id เป็นอีกฝ่ายที่ไม่ใช่ผู้กระทำ
 *
 * Validates: Requirements 4.1, 4.2, 4.3, 4.4
 */

const fc = require('fast-check');
const request = require('supertest');

// --- Mock notification service to capture calls ---
const mockCreateNotification = jest.fn().mockResolvedValue({ id: 'mock-notif-id' });

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
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn()
    },
    transaction: {
      create: jest.fn(),
      findUnique: mockTransactionFindUnique,
      findMany: jest.fn().mockResolvedValue([]),
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
const actionArb = fc.constantFrom('confirm', 'ship', 'complete', 'cancel');

beforeEach(() => {
  jest.clearAllMocks();
});

// ============================================
// Property 2: Transaction State Transition สร้าง Notification
// ============================================
describe('Feature: unimart-iteration-2-wiring, Property 2: Transaction State Transition สร้าง Notification', () => {
  /**
   * **Validates: Requirements 4.1, 4.2, 4.3, 4.4**
   *
   * For any transaction state transition that succeeds (confirm, ship, complete, cancel),
   * the system must create exactly 1 notification with:
   * - type = "transaction_update"
   * - recipientId = the other party (not the actor)
   *   - confirm → buyer
   *   - ship → buyer
   *   - complete → seller
   *   - cancel → the other party (if canceledBy == buyer → seller, else → buyer)
   */
  test('every successful state transition creates exactly one notification to the correct recipient', async () => {
    // Increase timeout for property-based test with async operations
    // 100 iterations × async HTTP calls need more than default 5s
    // Map action to the required "from" status for it to succeed
    const actionToFromStatus = {
      confirm: 'PENDING',
      ship: 'PROCESSING',
      complete: 'SHIPPING',
      cancel: 'PENDING' // cancel works from PENDING or PROCESSING
    };

    await fc.assert(
      fc.asyncProperty(
        actionArb,
        uuidArb, // buyerId
        uuidArb, // sellerId
        async (action, buyerId, sellerId) => {
          // Ensure buyer and seller are different
          fc.pre(buyerId !== sellerId);

          jest.clearAllMocks();

          const txId = 1;
          const productId = 42;
          const fromStatus = actionToFromStatus[action];

          // Mock: transaction exists with the correct "from" status
          const baseTx = {
            id: txId,
            status: fromStatus,
            productId,
            buyerId,
            sellerId
          };
          mockTransactionFindUnique.mockResolvedValue(baseTx);

          // Mock: the transition succeeds
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

          // The transaction operation itself should succeed
          expect(res.status).toBe(200);

          // Wait a tick for fire-and-forget notification to complete
          await new Promise(resolve => setImmediate(resolve));

          // Assert: createNotification was called exactly once
          expect(mockCreateNotification).toHaveBeenCalledTimes(1);

          // Assert: notification type is "transaction_update"
          const callArgs = mockCreateNotification.mock.calls[0];
          const recipientId = callArgs[0];
          const notifType = callArgs[1];

          expect(notifType).toBe('transaction_update');

          // Assert: recipient is the correct other party
          if (action === 'confirm' || action === 'ship') {
            // Seller acts → notify buyer
            expect(recipientId).toBe(buyerId);
          } else if (action === 'complete') {
            // Buyer acts → notify seller
            expect(recipientId).toBe(sellerId);
          } else if (action === 'cancel') {
            // canceledBy is buyer → notify seller
            expect(recipientId).toBe(sellerId);
          }
        }
      ),
      { numRuns: 100 }
    );
  }, 30000);
});
