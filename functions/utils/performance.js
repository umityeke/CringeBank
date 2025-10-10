/**
 * Performance Tracking Wrapper for Cloud Functions
 * 
 * Callable fonksiyonları wrap ederek:
 * - Execution time tracking
 * - Structured logging
 * - Error handling with context
 * - Performance metrics collection
 */

const { logStructured } = require('./alerts');

/**
 * Wrap callable function with performance tracking
 * 
 * @param {string} functionName - Function name for logging
 * @param {Function} callable - The actual callable function
 * @returns {Function} Wrapped callable
 */
function trackPerformance(functionName, callable) {
  return async (data, context) => {
    const startTime = Date.now();
    const userId = context.auth?.uid || 'anonymous';

    try {
      // Log function start
      logStructured('INFO', `${functionName} started`, {
        functionName,
        userId,
        dataKeys: Object.keys(data || {}),
      });

      // Execute callable
      const result = await callable(data, context);

      // Log success
      const duration = Date.now() - startTime;
      logStructured('INFO', `${functionName} completed`, {
        functionName,
        userId,
        duration,
        success: true,
      });

      // Alert on slow performance
      if (duration > 5000) {
        logStructured('WARNING', `${functionName} slow execution`, {
          functionName,
          duration,
          threshold: 5000,
        });
      }

      return result;
    } catch (error) {
      // Log error with context
      const duration = Date.now() - startTime;
      logStructured('ERROR', `${functionName} failed`, {
        functionName,
        userId,
        duration,
        error: error.message,
        errorCode: error.code,
        stack: error.stack,
      });

      throw error;
    }
  };
}

/**
 * Wrap async function with retry logic
 * 
 * @param {Function} fn - Async function to retry
 * @param {number} maxRetries - Maximum retry attempts
 * @param {number} delayMs - Delay between retries
 * @returns {Promise} Function result
 */
async function retryWithBackoff(fn, maxRetries = 3, delayMs = 1000) {
  let lastError;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (attempt < maxRetries) {
        const delay = delayMs * Math.pow(2, attempt - 1); // Exponential backoff
        logStructured('WARNING', `Retry attempt ${attempt}/${maxRetries}`, {
          error: error.message,
          nextRetryIn: delay,
        });

        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError;
}

module.exports = {
  trackPerformance,
  retryWithBackoff,
};
