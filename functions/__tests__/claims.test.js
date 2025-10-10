const { getAuthClaims, hasRole, hasAnyRole } = require('../utils/claims');

describe('claims helper', () => {
  const contextWithClaims = (claims) => ({
    auth: {
      uid: 'user-1',
      token: claims,
    },
  });

  describe('getAuthClaims', () => {
    it('returns token claims when present', () => {
      const claims = { superadmin: true };
      expect(getAuthClaims(contextWithClaims(claims))).toBe(claims);
    });

    it('returns empty object when context missing auth', () => {
      expect(getAuthClaims({})).toEqual({});
      expect(getAuthClaims(null)).toEqual({});
    });
  });

  describe('hasRole', () => {
    it('returns true when claim flag is true', () => {
      const ctx = contextWithClaims({ system_writer: true });
      expect(hasRole(ctx, 'system_writer')).toBe(true);
    });

    it('returns false when claim missing or falsy', () => {
      const ctx = contextWithClaims({ system_writer: false });
      expect(hasRole(ctx, 'system_writer')).toBe(false);
      expect(hasRole(ctx, 'unknown_role')).toBe(false);
    });

    it('returns false when role parameter is falsy', () => {
      const ctx = contextWithClaims({ superadmin: true });
      expect(hasRole(ctx, '')).toBe(false);
      expect(hasRole(ctx, null)).toBe(false);
    });
  });

  describe('hasAnyRole', () => {
    it('returns true when any expected role present', () => {
      const ctx = contextWithClaims({ superadmin: true });
      expect(hasAnyRole(ctx, ['system_writer', 'superadmin'])).toBe(true);
    });

    it('returns false when none of the roles match', () => {
      const ctx = contextWithClaims({ system_writer: false });
      expect(hasAnyRole(ctx, ['system_writer', 'superadmin'])).toBe(false);
    });

    it('returns false for invalid role array input', () => {
      const ctx = contextWithClaims({});
      expect(hasAnyRole(ctx, [])).toBe(false);
      expect(hasAnyRole(ctx, null)).toBe(false);
      expect(hasAnyRole(ctx, 'superadmin')).toBe(false);
    });
  });
});
