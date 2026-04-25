/**
 * Property-Based Tests สำหรับ Smart Filter — UniMart Iteration 2
 *
 * ใช้ fast-check สำหรับ property-based testing
 * Mock Prisma (product.findMany, review.aggregate) เพื่อ test logic ภายใน
 *
 * Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6
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
const mockProductFindMany = jest.fn();
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
    meetingPoint: { findMany: jest.fn().mockResolvedValue([]) }
  }))
}));

jest.mock('axios');

const { app } = require('../server');

// ============================================
// Generators
// ============================================
const facultyArb = fc.constantFrom(
  'วิศวกรรมศาสตร์', 'วิทยาศาสตร์', 'นิติศาสตร์', 'พาณิชยศาสตร์และการบัญชี',
  'รัฐศาสตร์', 'เศรษฐศาสตร์', 'สังคมสงเคราะห์ศาสตร์', 'ศิลปศาสตร์'
);

const dormitoryZoneArb = fc.constantFrom('เชียงราก', 'อินเตอร์โซน', 'ในมหาวิทยาลัย');

const meetingPointArb = fc.constantFrom(
  'โรงอาหารกรีน', 'SC Hall', 'ป้ายรถตู้', 'หอพักเชียงราก', 'หอพักอินเตอร์โซน'
);

const meetingPointZoneMap = {
  'โรงอาหารกรีน': 'ในมหาวิทยาลัย',
  'SC Hall': 'ในมหาวิทยาลัย',
  'ป้ายรถตู้': 'ในมหาวิทยาลัย',
  'หอพักเชียงราก': 'เชียงราก',
  'หอพักอินเตอร์โซน': 'อินเตอร์โซน'
};

// Generator for a product with randomized attributes
function productArb(idStart) {
  return fc.record({
    faculty: facultyArb,
    dormitoryZone: dormitoryZoneArb,
    meetingPointName: meetingPointArb
  }).map((attrs, idx) => {
    const id = idStart + (idx || 0);
    return {
      id,
      title: `สินค้า ${id}`,
      price: 100 + id,
      status: 'Available',
      ownerId: `user-${id}`,
      categoryId: 1,
      owner: {
        id: `user-${id}`,
        display_name_th: `ผู้ขาย ${id}`,
        username: `seller${id}`,
        faculty: attrs.faculty,
        dormitory_zone: attrs.dormitoryZone
      },
      category: { id: 1, name: 'General' },
      meetingPoint: {
        id: id,
        name: attrs.meetingPointName,
        zone: meetingPointZoneMap[attrs.meetingPointName]
      }
    };
  });
}

// Generate an array of products with unique IDs
const productsArrayArb = fc.array(
  fc.record({
    faculty: facultyArb,
    dormitoryZone: dormitoryZoneArb,
    meetingPointName: meetingPointArb
  }),
  { minLength: 1, maxLength: 20 }
).map(items =>
  items.map((attrs, idx) => ({
    id: idx + 1,
    title: `สินค้า ${idx + 1}`,
    price: 100 + idx,
    status: 'Available',
    ownerId: `user-${idx + 1}`,
    categoryId: 1,
    owner: {
      id: `user-${idx + 1}`,
      display_name_th: `ผู้ขาย ${idx + 1}`,
      username: `seller${idx + 1}`,
      faculty: attrs.faculty,
      dormitory_zone: attrs.dormitoryZone
    },
    category: { id: 1, name: 'General' },
    meetingPoint: {
      id: idx + 1,
      name: attrs.meetingPointName,
      zone: meetingPointZoneMap[attrs.meetingPointName]
    }
  }))
);

// Generator for optional filter combinations
const filterCombinationArb = fc.record({
  faculty: fc.option(facultyArb, { nil: undefined }),
  dormitoryZone: fc.option(dormitoryZoneArb, { nil: undefined }),
  meetingPoint: fc.option(meetingPointArb, { nil: undefined })
});

// Reset mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});

// ============================================
// Property 12: Smart Filter — AND Logic ถูกต้อง
// ============================================
describe('Feature: unimart-iteration-2, Property 12: Smart Filter — AND Logic ถูกต้อง', () => {
  /**
   * Validates: Requirements 3.1, 3.2, 3.3, 3.4
   * For any set of filter conditions (faculty, dormitoryZone, meetingPoint),
   * all products in the result should match ALL selected conditions (AND logic).
   * Generate random filter combinations and verify each product in the result
   * matches every active filter.
   */
  test('all returned products match every active filter condition (AND logic)', async () => {
    await fc.assert(
      fc.asyncProperty(
        productsArrayArb,
        filterCombinationArb,
        async (allProducts, filters) => {
          // At least one filter must be active for a meaningful test
          const hasFilter = filters.faculty || filters.dormitoryZone || filters.meetingPoint;
          fc.pre(hasFilter);

          // Compute expected results: products matching ALL active filters
          const expected = allProducts.filter(p => {
            if (filters.faculty && p.owner.faculty !== filters.faculty) return false;
            if (filters.dormitoryZone && p.owner.dormitory_zone !== filters.dormitoryZone) return false;
            if (filters.meetingPoint && p.meetingPoint.name !== filters.meetingPoint) return false;
            return true;
          });

          // Mock Prisma to simulate the AND-filtered query
          // The server builds a where clause and passes it to Prisma,
          // so we mock findMany to return the expected filtered results
          mockProductFindMany.mockImplementation(({ where }) => {
            // Verify the where clause uses AND logic by filtering allProducts
            let result = allProducts.filter(p => {
              if (where.status && p.status !== where.status) return false;
              if (where.owner) {
                if (where.owner.faculty && p.owner.faculty !== where.owner.faculty) return false;
                if (where.owner.dormitory_zone && p.owner.dormitory_zone !== where.owner.dormitory_zone) return false;
              }
              if (where.meetingPoint && where.meetingPoint.name && p.meetingPoint.name !== where.meetingPoint.name) return false;
              if (where.categoryId && p.categoryId !== where.categoryId) return false;
              return true;
            });
            return Promise.resolve(result);
          });

          // Build query string
          const params = new URLSearchParams();
          if (filters.faculty) params.set('faculty', filters.faculty);
          if (filters.dormitoryZone) params.set('dormitoryZone', filters.dormitoryZone);
          if (filters.meetingPoint) params.set('meetingPoint', filters.meetingPoint);

          const res = await request(app)
            .get(`/api/products/filter?${params.toString()}`);

          expect(res.status).toBe(200);

          // Every returned product must match ALL active filters
          for (const product of res.body.products) {
            if (filters.faculty) {
              expect(product.owner.faculty).toBe(filters.faculty);
            }
            if (filters.dormitoryZone) {
              expect(product.owner.dormitory_zone).toBe(filters.dormitoryZone);
            }
            if (filters.meetingPoint) {
              expect(product.meetingPoint.name).toBe(filters.meetingPoint);
            }
          }

          // No matching product should be excluded
          expect(res.body.products.length).toBe(expected.length);
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 13: ล้างตัวกรองคืนสินค้าทั้งหมด
// ============================================
describe('Feature: unimart-iteration-2, Property 13: ล้างตัวกรองคืนสินค้าทั้งหมด', () => {
  /**
   * Validates: Requirements 3.5
   * When no filters are provided (empty query), the result should equal
   * all products with status "Available". This is equivalent to "clearing all filters".
   */
  test('empty query returns all Available products', async () => {
    await fc.assert(
      fc.asyncProperty(
        productsArrayArb,
        async (allProducts) => {
          // All products in our generator have status 'Available'
          const availableProducts = allProducts.filter(p => p.status === 'Available');

          mockProductFindMany.mockImplementation(({ where }) => {
            // When no filters, where should only have { status: 'Available' }
            const result = allProducts.filter(p => {
              if (where.status && p.status !== where.status) return false;
              return true;
            });
            return Promise.resolve(result);
          });

          const res = await request(app)
            .get('/api/products/filter');

          expect(res.status).toBe(200);
          expect(res.body.products.length).toBe(availableProducts.length);

          // Verify all available products are returned
          const returnedIds = res.body.products.map(p => p.id).sort();
          const expectedIds = availableProducts.map(p => p.id).sort();
          expect(returnedIds).toEqual(expectedIds);
        }
      ),
      { numRuns: 100 }
    );
  });
});


// ============================================
// Property 14: จำนวนสินค้าตรงกับผลลัพธ์
// ============================================
describe('Feature: unimart-iteration-2, Property 14: จำนวนสินค้าตรงกับผลลัพธ์', () => {
  /**
   * Validates: Requirements 3.6
   * For any filter result, the totalCount field should exactly equal
   * the length of the products array.
   */
  test('totalCount equals products array length for any filter combination', async () => {
    await fc.assert(
      fc.asyncProperty(
        productsArrayArb,
        filterCombinationArb,
        async (allProducts, filters) => {
          mockProductFindMany.mockImplementation(({ where }) => {
            let result = allProducts.filter(p => {
              if (where.status && p.status !== where.status) return false;
              if (where.owner) {
                if (where.owner.faculty && p.owner.faculty !== where.owner.faculty) return false;
                if (where.owner.dormitory_zone && p.owner.dormitory_zone !== where.owner.dormitory_zone) return false;
              }
              if (where.meetingPoint && where.meetingPoint.name && p.meetingPoint.name !== where.meetingPoint.name) return false;
              if (where.categoryId && p.categoryId !== where.categoryId) return false;
              return true;
            });
            return Promise.resolve(result);
          });

          // Build query string
          const params = new URLSearchParams();
          if (filters.faculty) params.set('faculty', filters.faculty);
          if (filters.dormitoryZone) params.set('dormitoryZone', filters.dormitoryZone);
          if (filters.meetingPoint) params.set('meetingPoint', filters.meetingPoint);

          const queryStr = params.toString();
          const url = queryStr ? `/api/products/filter?${queryStr}` : '/api/products/filter';

          const res = await request(app).get(url);

          expect(res.status).toBe(200);
          expect(res.body.totalCount).toBe(res.body.products.length);
        }
      ),
      { numRuns: 100 }
    );
  });
});
