function getAuthClaims(context) {
  return (context && context.auth && context.auth.token) || {};
}

function hasRole(context, role) {
  if (!role) {
    return false;
  }
  const claims = getAuthClaims(context);
  return claims[role] === true;
}

function hasAnyRole(context, roles) {
  if (!Array.isArray(roles) || roles.length === 0) {
    return false;
  }
  return roles.some((role) => hasRole(context, role));
}

module.exports = {
  getAuthClaims,
  hasRole,
  hasAnyRole,
};
