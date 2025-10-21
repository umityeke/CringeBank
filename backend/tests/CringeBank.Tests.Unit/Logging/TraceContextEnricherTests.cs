namespace CringeBank.Tests.Unit.Logging;

using System;
using System.Diagnostics;
using CringeBank.Api.Logging;
using Serilog.Core;
using Serilog.Events;
using Serilog.Parsing;

public sealed class TraceContextEnricherTests
{
    [Fact]
    public void Enrich_AddsTraceContext_WhenActivityIsPresent()
    {
        using var activity = new Activity("test-activity");
        activity.SetIdFormat(ActivityIdFormat.W3C);
        activity.ActivityTraceFlags = ActivityTraceFlags.Recorded;
        activity.Start();

        var messageTemplate = new MessageTemplateParser().Parse("Test message");
        var logEvent = new LogEvent(DateTimeOffset.UtcNow, LogEventLevel.Information, exception: null, messageTemplate, Array.Empty<LogEventProperty>());
        var enricher = new TraceContextEnricher();
        var propertyFactory = new TestPropertyFactory();

        enricher.Enrich(logEvent, propertyFactory);

        Assert.True(logEvent.Properties.TryGetValue("TraceId", out var traceIdProperty));
        Assert.Equal(activity.TraceId.ToHexString(), Assert.IsType<ScalarValue>(traceIdProperty).Value);

        Assert.True(logEvent.Properties.TryGetValue("SpanId", out var spanIdProperty));
        Assert.Equal(activity.SpanId.ToHexString(), Assert.IsType<ScalarValue>(spanIdProperty).Value);

        Assert.True(logEvent.Properties.TryGetValue("TraceFlags", out var traceFlagsProperty));
        Assert.Equal(activity.ActivityTraceFlags.ToString(), Assert.IsType<ScalarValue>(traceFlagsProperty).Value);

        activity.Stop();
    }

    [Fact]
    public void Enrich_DoesNothing_WhenActivityIsMissing()
    {
        var messageTemplate = new MessageTemplateParser().Parse("Test message");
        var logEvent = new LogEvent(DateTimeOffset.UtcNow, LogEventLevel.Information, exception: null, messageTemplate, Array.Empty<LogEventProperty>());
        var enricher = new TraceContextEnricher();
        var propertyFactory = new TestPropertyFactory();

        enricher.Enrich(logEvent, propertyFactory);

        Assert.False(logEvent.Properties.ContainsKey("TraceId"));
        Assert.False(logEvent.Properties.ContainsKey("SpanId"));
        Assert.False(logEvent.Properties.ContainsKey("TraceFlags"));
    }

    private sealed class TestPropertyFactory : ILogEventPropertyFactory
    {
    public LogEventProperty CreateProperty(string name, object? value, bool destructureObjects = false)
        {
            return new LogEventProperty(name, new ScalarValue(value));
        }
    }
}
