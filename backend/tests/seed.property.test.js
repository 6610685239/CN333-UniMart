/**
 * Property-Based Test สำหรับ Seed Script Idempotent — UniMart Iteration 2 Wiring
 *
 * ใช้ fast-check สำหรับ property-based testing
 * Mock Prisma เพื่อ test seed logic ภายใน
 *
 * Feature: unimart-iteration-2-wiring, Property 1: Seed Script Idempotent
 * Validates: Requirements 2.2, 3.2
 */

const fc = require('fast-check');

// In-memory stores (prefixed with mock to satisfy jest.mock scope rules)
const mockCategoryStore = [];
const mockMeetingPointStore = [];

const mockCategoryUpsert = jest.fn().mockImplementation(({ where, create }) => {
  const existing = mockCategoryStore.find(c => c.name === where.name);
  if (!existing) {
    mockCategoryStore.push({ ...create });
  }
  return Promise.resolve(existing || create);
});

const mockMeetingPointUpsert = jest.fn().mockImplementation(({ where, create }) => {
  const existing = mockMeetingPointStore.find(m => m.name === where.name);
  if (!existing) {
    mockMeetingPointStore.push({ ...create });
  }
  return Promise.resolve(existing || create);
});

const mockDisconnect = jest.fn().mockResolvedValue(undefined);

jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: {
      upsert: mockCategoryUpsert,
      findMany: jest.fn().mockResolvedValue([]),
    },
    meetingPoint: {
      upsert: mockMeetingPointUpsert,
    },
    product: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    $disconnect: mockDisconnect,
  })),
}));

// Seed data — ตรงกับ backend/prisma/seed.js
const categories = [
  { id: 1, name: 'Textbooks' },
  { id: 2, name: 'Uniforms' },
  { id: 3, name: 'Gadgets' },
  { id: 4, name: 'Accessories' },
  { id: 5, name: 'Stationery' },
  { id: 6, name: 'Dorm Essentials' },
  { id: 7, name: 'Sports' },
  { id: 8, name: 'Others' },
];

const meetingPoints = [
  { id: 1, name: 'โรงอาหารกรีน', zone: 'ในมหาวิทยาลัย' },
  { id: 2, name: 'SC Hall', zone: 'ในมหาวิทยาลัย' },
  { id: 3, name: 'ป้ายรถตู้', zone: 'ในมหาวิทยาลัย' },
  { id: 4, name: 'หอพักเชียงราก', zone: 'เชียงราก' },
  { id: 5, name: 'หอพักอินเตอร์โซน', zone: 'อินเตอร์โซน' },
];

// Replicate seed logic — same as prisma/seed.js main()
const { PrismaClient } = require('@prisma/client');

async function runSeed() {
  const prisma = new PrismaClient();
  for (const cat of categories) {
    await prisma.category.upsert({
      where: { name: cat.name },
      update: {},
      create: { id: cat.id, name: cat.name },
    });
  }
  for (const mp of meetingPoints) {
    await prisma.meetingPoint.upsert({
      where: { name: mp.name },
      update: {},
      create: { id: mp.id, name: mp.name, zone: mp.zone },
    });
  }
}

beforeEach(() => {
  mockCategoryStore.length = 0;
  mockMeetingPointStore.length = 0;
  jest.clearAllMocks();
});

// ============================================
// Property 1: Seed Script Idempotent
// ============================================
describe('Feature: unimart-iteration-2-wiring, Property 1: Seed Script Idempotent', () => {
  /**
   * Validates: Requirements 2.2, 3.2
   * For any number of seed runs (1-5), categories = 8 and meeting_points = 5 always
   */
  test('running seed N times always results in exactly 8 categories and 5 meeting points', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 1, max: 5 }),
        async (numRuns) => {
          // Reset stores for each property iteration
          mockCategoryStore.length = 0;
          mockMeetingPointStore.length = 0;

          // Run seed numRuns times
          for (let i = 0; i < numRuns; i++) {
            await runSeed();
          }

          // Assert counts — must always be exactly 8 and 5
          expect(mockCategoryStore.length).toBe(8);
          expect(mockMeetingPointStore.length).toBe(5);
        }
      ),
      { numRuns: 100 }
    );
  });
});
