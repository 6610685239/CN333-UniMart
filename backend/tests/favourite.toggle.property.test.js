/**
 * Property-Based Test สำหรับ Favourite Toggle Round-Trip
 *
 * ทดสอบ logic เดียวกับ frontend/lib/pages/favourite_manager.dart toggle():
 *   - ถ้า product อยู่ใน favourites → ลบออก (count -1)
 *   - ถ้า product ไม่อยู่ใน favourites → เพิ่มเข้า (count +1)
 *   - toggle 2 ครั้ง = กลับสู่สถานะเดิม (round-trip)
 *
 * Feature: unimart-iteration-2-wiring, Property 8: Favourite Toggle Round-Trip
 * Validates: Requirements 10.2
 */

const fc = require('fast-check');

// ── Pure toggle logic (equivalent to FavouriteManager.toggle in Dart) ──

/**
 * Applies a favourite toggle on a set of favourited product IDs.
 * Returns the new set and the new count for the toggled product.
 *
 * @param {Set<string>} favourites - current set of favourited product IDs
 * @param {Map<string,number>} counts - product id → total favourite count
 * @param {string} productId - the product to toggle
 * @returns {{ favourites: Set<string>, counts: Map<string,number>, wasLiked: boolean }}
 */
function toggleFavourite(favourites, counts, productId) {
  const newFavourites = new Set(favourites);
  const newCounts = new Map(counts);
  const wasLiked = newFavourites.has(productId);

  if (wasLiked) {
    newFavourites.delete(productId);
    newCounts.set(productId, (newCounts.get(productId) ?? 1) - 1);
  } else {
    newFavourites.add(productId);
    newCounts.set(productId, (newCounts.get(productId) ?? 0) + 1);
  }

  return { favourites: newFavourites, counts: newCounts, wasLiked };
}

// ── Generators ──

const productIdArb = fc.uuid();

/**
 * Generate an initial set of favourited product IDs (0–20 items).
 */
const favouriteSetArb = fc
  .array(productIdArb, { minLength: 0, maxLength: 20 })
  .map(ids => new Set(ids));

/**
 * Generate initial favourite counts consistent with a given set.
 * Each favourited product gets a count >= 1; non-favourited may also have counts from other users.
 */
function countsFromSet(favSet) {
  const counts = new Map();
  for (const id of favSet) {
    // count is at least 1 (this user) + random others
    counts.set(id, 1 + Math.floor(Math.random() * 10));
  }
  return counts;
}

// ============================================
// Property 8: Favourite Toggle Round-Trip
// ============================================
describe('Feature: unimart-iteration-2-wiring, Property 8: Favourite Toggle Round-Trip', () => {
  /**
   * Validates: Requirements 10.2
   *
   * For any initial set of favourited product IDs and any product ID to toggle:
   * 1. If the product was NOT in the set → after toggle it IS in the set (count +1)
   * 2. If the product WAS in the set → after toggle it is NOT in the set (count -1)
   * 3. Toggling twice returns to the original state (round-trip)
   */
  test('toggle adds/removes correctly and double-toggle is a round-trip', () => {
    fc.assert(
      fc.property(
        favouriteSetArb,
        productIdArb,
        (initialFavourites, toggleProductId) => {
          const initialCounts = countsFromSet(initialFavourites);
          const wasInSet = initialFavourites.has(toggleProductId);
          const initialCount = initialCounts.get(toggleProductId) ?? 0;

          // ── First toggle ──
          const after1 = toggleFavourite(initialFavourites, initialCounts, toggleProductId);

          if (!wasInSet) {
            // Product was NOT favourited → should now be in the set
            expect(after1.favourites.has(toggleProductId)).toBe(true);
            // Count should increase by 1
            expect(after1.counts.get(toggleProductId)).toBe(initialCount + 1);
          } else {
            // Product WAS favourited → should no longer be in the set
            expect(after1.favourites.has(toggleProductId)).toBe(false);
            // Count should decrease by 1
            expect(after1.counts.get(toggleProductId)).toBe(initialCount - 1);
          }

          // Size should change by exactly 1
          const expectedSize = wasInSet
            ? initialFavourites.size - 1
            : initialFavourites.size + 1;
          expect(after1.favourites.size).toBe(expectedSize);

          // ── Second toggle (round-trip) ──
          const after2 = toggleFavourite(after1.favourites, after1.counts, toggleProductId);

          // Should be back to original membership
          expect(after2.favourites.has(toggleProductId)).toBe(wasInSet);
          // Size should be back to original
          expect(after2.favourites.size).toBe(initialFavourites.size);
          // Count should be back to original
          expect(after2.counts.get(toggleProductId)).toBe(initialCount);

          // All other product IDs should be unchanged
          for (const id of initialFavourites) {
            if (id !== toggleProductId) {
              expect(after2.favourites.has(id)).toBe(true);
            }
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});
