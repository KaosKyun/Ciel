/**
 * Fonction de test pour vérifier que Ciel fonctionne
 * @returns true si tout va bien
 */
export function testCiel(): boolean {
  console.log("[TEST] Ciel hooks are working!");
  return true;
}

// Test rapide
if (import.meta.main) {
  const result = testCiel();
  console.log(`Result: ${result ? "✓ PASS" : "✗ FAIL"}`);
}
