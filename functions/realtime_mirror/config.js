const requiredKeys = ['SERVICEBUS_CONNECTION_STRING'];

function parseInteger(value, defaultValue) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    return defaultValue;
  }
  return parsed;
}

function parseBoolean(value, defaultValue = false) {
  if (value === undefined || value === null) {
    return defaultValue;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'on'].includes(normalized)) {
      return true;
    }
    if (['false', '0', 'no', 'off'].includes(normalized)) {
      return false;
    }
  }
  if (typeof value === 'number') {
    return value !== 0;
  }
  return defaultValue;
}

function readRealtimeMirrorConfig() {
  const missing = requiredKeys.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    throw new Error(`Missing realtime mirror environment variables: ${missing.join(', ')}`);
  }

  return {
    serviceBus: {
      connectionString: process.env.SERVICEBUS_CONNECTION_STRING,
      topicName: process.env.SERVICEBUS_TOPIC_REALTIME_MIRROR || 'realtime-mirror',
      publishRetryCount: parseInteger(process.env.SERVICEBUS_PUBLISH_RETRY, 3),
      deadLetterAlertThreshold: parseInteger(process.env.SERVICEBUS_DEADLETTER_ALERT_THRESHOLD, 10),
      subscriptions: {
        sqlWriter: process.env.SERVICEBUS_SUBSCRIPTION_SQL_WRITER || 'sql-writer',
        monitoring: process.env.SERVICEBUS_SUBSCRIPTION_MONITORING || 'monitoring',
      },
    },
    featureFlags: {
      writeMirrorEnabled: parseBoolean(process.env.USE_SQL_DM_WRITE_MIRROR, false),
    },
    sqlProcedures: {
      dmMessageUpsert: process.env.SQL_PROC_DM_MESSAGE_UPSERT || 'sp_StoreMirror_UpsertDmMessage',
      dmConversationUpsert:
        process.env.SQL_PROC_DM_CONVERSATION_UPSERT || 'sp_StoreMirror_UpsertDmConversation',
      dmMessageDelete: process.env.SQL_PROC_DM_MESSAGE_DELETE || 'sp_StoreMirror_DeleteDmMessage',
      followEdgeUpsert:
        process.env.SQL_PROC_FOLLOW_EDGE_UPSERT || 'sp_StoreMirror_UpsertFollowEdge',
      followEdgeDelete:
        process.env.SQL_PROC_FOLLOW_EDGE_DELETE || 'sp_StoreMirror_DeleteFollowEdge',
    },
  };
}

module.exports = {
  readRealtimeMirrorConfig,
  parseBoolean,
  parseInteger,
};
