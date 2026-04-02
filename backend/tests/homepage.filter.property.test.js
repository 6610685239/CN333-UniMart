/**
 * Property-Based Test สำหรับ HomePage กรองสินค้าของตัวเอง
 *
 * ทดสอบ logic เดียวกับ frontend/lib/screens/home_screen.dart _fetchProducts():
 *   products = allProducts.where((p) => p.ownerId != widget.currentUserId).toList();
 *
 * Feature: unimart-iteration-2-wiring, Property 5: HomePage กรองสินค้าของตัวเองออก
 * Validates: Requirements 6.5
 */

const fc = require('fast-check');

/**
 * Pure filter logic equivalent to the Flutter HomePage filtering.
 * Given a list of products and a currentUserId, returns only products
 * whose ownerId is not equal to currentUserId.
 */
function filterOwnProducts(products, currentUserId) {
  return products.filter(p => p.ownerId !== currentUserId);
}

// ============================================
// Generators
// ============================================

const uuidArb = fc.uuid();

/**
 * Generate a product with a given ownerId.
 */
function productArb(ownerIdArb) {
  return fc.record({
    id: fc.integer({ min: 1, max: 100000 }),
    title: fc.string({ minLength: 1, maxLength: 50 }),
    price: fc.float({ min: 1, max: 99999, noNaN: true }),
    ownerId: ownerIdArb,
  });
}

/**
 * Generate a list of products where some may have ownerId === currentUserId
 * and some have different ownerIds.
 */
function productsWithMixedOwners(currentUserId) {
  return fc.array(
    productArb(
      fc.oneof(
        fc.constant(currentUserId),  // some products owned by current user
        uuidArb                       // some products owned by others
      )
    ),
    { minLength: 0, maxLength: 30 }
  );
}

// ============================================
// Property 5: HomePage กรองสินค้าของตัวเองออก
// ============================================
describe('Feature: unimart-iteration-2-wiring, Property 5: HomePage กรองสินค้าของตัวเองออก', () => {
  /**
   * Validates: Requirements 6.5
   *
   * For any currentUserId and any list of products with various ownerIds,
   * after filtering, no product in the result should have ownerId === currentUserId.
   * Additionally, all products NOT owned by currentUser must be preserved.
   */
  test('no product in filtered result has ownerId equal to currentUserId', () => {
    fc.assert(
      fc.property(
        uuidArb.chain(currentUserId =>
          fc.tuple(
            fc.constant(currentUserId),
            productsWithMixedOwners(currentUserId)
          )
        ),
        ([currentUserId, allProducts]) => {
          const filtered = filterOwnProducts(allProducts, currentUserId);

          // PROPERTY: No product in the result has ownerId === currentUserId
          for (const product of filtered) {
            expect(product.ownerId).not.toBe(currentUserId);
          }

          // All products NOT owned by currentUser should be preserved
          const expectedCount = allProducts.filter(p => p.ownerId !== currentUserId).length;
          expect(filtered.length).toBe(expectedCount);
        }
      ),
      { numRuns: 100 }
    );
  });
});
