// Prefer the v1 API to ensure region() and classic builders are available on latest packages
let baseFunctions;
try {
	baseFunctions = require('firebase-functions/v1');
} catch (e) {
	baseFunctions = require('firebase-functions');
}

const defaultRegion = process.env.FUNCTIONS_TARGET_REGION || process.env.FUNCTION_REGION || 'europe-west1';

if (typeof baseFunctions.region !== 'function') {
	throw new Error('firebase-functions v1 API not available; ensure firebase-functions/v1 can be required.');
}
const regionalFunctions = baseFunctions.region(defaultRegion);
const BaseHttpsError = baseFunctions?.https?.HttpsError;
class RegionalHttpsError extends (BaseHttpsError || Error) {
	constructor(code, message, details) {
		super(message);
		this.code = code;
		if (details !== undefined) {
			this.details = details;
		}
	}
}

// Preserve helpers that are not automatically copied over by region()
regionalFunctions.config = (...args) => baseFunctions.config(...args);
regionalFunctions.logger = baseFunctions.logger;
regionalFunctions.params = baseFunctions.params;
regionalFunctions.app = baseFunctions.app;
regionalFunctions.experimental = baseFunctions.experimental;
regionalFunctions.testLab = baseFunctions.testLab;
regionalFunctions.pubsub = regionalFunctions.pubsub || baseFunctions.pubsub;
regionalFunctions.firestore = regionalFunctions.firestore || baseFunctions.firestore;
regionalFunctions.database = regionalFunctions.database || baseFunctions.database;
regionalFunctions.storage = regionalFunctions.storage || baseFunctions.storage;
regionalFunctions.remoteConfig = regionalFunctions.remoteConfig || baseFunctions.remoteConfig;
regionalFunctions.analytics = regionalFunctions.analytics || baseFunctions.analytics;
const httpsBuilder = regionalFunctions.https || baseFunctions.https || {};
const patchedHttps = Object.assign(Object.create(httpsBuilder), httpsBuilder, {
	HttpsError: BaseHttpsError || RegionalHttpsError,
});
Object.defineProperty(regionalFunctions, 'https', {
	value: patchedHttps,
	writable: false,
	configurable: true,
});
if (!regionalFunctions.https.CallableContextOptions) {
	regionalFunctions.https.CallableContextOptions = baseFunctions.https?.CallableContextOptions;
}
regionalFunctions.scheduler = regionalFunctions.scheduler || baseFunctions.scheduler;
regionalFunctions.tasks = regionalFunctions.tasks || baseFunctions.tasks;
regionalFunctions.region = (...args) => baseFunctions.region(...args);

module.exports = regionalFunctions;
module.exports.baseFunctions = baseFunctions;
module.exports.defaultRegion = defaultRegion;
