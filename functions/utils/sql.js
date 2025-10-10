/**
 * SQL utilities (legacy alias)
 * Re-exports sql_pool for backward compatibility
 */

const { getSqlPool, resetSqlPool } = require('./sql_pool');

module.exports = {
  getSqlPool,
  resetSqlPool,
};
