package gno_cdn

import (
	"context"
	"fmt"
	"github.com/gnolang/gno/tm2/pkg/telemetry/config"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/metric"
	sdkMetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

const (
	requestDurationKey = "http_request_duration_hist"
	cacheHitKey        = "cache_hit_counter"
	cacheMissKey       = "cache_miss_counter"
)

var (
	// HTTPRequestDuration measures the duration of HTTP requests
	HTTPRequestDuration metric.Int64Histogram

	// CacheHitCounter counts the number of cache hits
	CacheHitCounter metric.Int64Counter

	// CacheMissCounter counts the number of cache misses
	CacheMissCounter metric.Int64Counter
)

// Init initializes the metrics for the CDN server.
func Init(config config.Config) error {
	var (
		ctx = context.Background()
		exp sdkMetric.Exporter
	)
	var err error

	// FIXME
	// _, err := url.Parse(config.ExporterEndpoint)
	// if err != nil {
	// 	return fmt.Errorf("error parsing exporter endpoint: %s, %w", config.ExporterEndpoint, err)
	// }

	// Use OTLP metric exporter with gRPC
	exp, err = otlpmetricgrpc.New(
		ctx,
		otlpmetricgrpc.WithEndpoint(config.ExporterEndpoint),
		otlpmetricgrpc.WithInsecure(),
	)
	if err != nil {
		return fmt.Errorf("unable to create gRPC metrics exporter, %w", err)
	}

	provider := sdkMetric.NewMeterProvider(
		sdkMetric.WithReader(sdkMetric.NewPeriodicReader(exp)),
		sdkMetric.WithResource(
			resource.NewWithAttributes(
				semconv.SchemaURL,
				semconv.ServiceNameKey.String(config.ServiceName),
				semconv.ServiceVersionKey.String("0.1.0"),
				semconv.ServiceInstanceIDKey.String(config.ServiceInstanceID),
			),
		),
	)
	otel.SetMeterProvider(provider)
	meter := provider.Meter(config.MeterName)

	// Initialize metrics
	if HTTPRequestDuration, err = meter.Int64Histogram(
		requestDurationKey,
		metric.WithDescription("Duration of HTTP requests"),
		metric.WithUnit("ms"),
	); err != nil {
		return fmt.Errorf("unable to create histogram, %w", err)
	}

	if CacheHitCounter, err = meter.Int64Counter(
		cacheHitKey,
		metric.WithDescription("Number of cache hits"),
	); err != nil {
		return fmt.Errorf("unable to create counter, %w", err)
	}

	if CacheMissCounter, err = meter.Int64Counter(
		cacheMissKey,
		metric.WithDescription("Number of cache misses"),
	); err != nil {
		return fmt.Errorf("unable to create counter, %w", err)
	}

	return nil
}
