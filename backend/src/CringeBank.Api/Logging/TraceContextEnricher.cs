namespace CringeBank.Api.Logging;

using System;
using System.Diagnostics;
using Serilog.Core;
using Serilog.Events;

internal sealed class TraceContextEnricher : ILogEventEnricher
{
    private const string TraceIdPropertyName = "TraceId";
    private const string SpanIdPropertyName = "SpanId";
    private const string ParentSpanIdPropertyName = "ParentSpanId";
    private const string TraceFlagsPropertyName = "TraceFlags";
    private const string TraceStatePropertyName = "TraceState";

    public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
    {
        ArgumentNullException.ThrowIfNull(logEvent);
        ArgumentNullException.ThrowIfNull(propertyFactory);

        var activity = Activity.Current;

        if (activity is null || activity.TraceId == default)
        {
            return;
        }

        logEvent.AddOrUpdateProperty(propertyFactory.CreateProperty(TraceIdPropertyName, activity.TraceId.ToHexString()));

        if (activity.SpanId != default)
        {
            logEvent.AddOrUpdateProperty(propertyFactory.CreateProperty(SpanIdPropertyName, activity.SpanId.ToHexString()));
        }

        if (activity.ParentSpanId != default)
        {
            logEvent.AddOrUpdateProperty(propertyFactory.CreateProperty(ParentSpanIdPropertyName, activity.ParentSpanId.ToHexString()));
        }

        if (activity.ActivityTraceFlags != ActivityTraceFlags.None)
        {
            logEvent.AddOrUpdateProperty(propertyFactory.CreateProperty(TraceFlagsPropertyName, activity.ActivityTraceFlags.ToString()));
        }

        if (!string.IsNullOrWhiteSpace(activity.TraceStateString))
        {
            logEvent.AddOrUpdateProperty(propertyFactory.CreateProperty(TraceStatePropertyName, activity.TraceStateString));
        }
    }
}
