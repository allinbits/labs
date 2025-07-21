package core

import (
	"context"
	"log/slog"
	"os"
	"strings"
)

// Logger interface for IoC pattern
type Logger interface {
	Debug(msg string, args ...any)
	Info(msg string, args ...any)
	Warn(msg string, args ...any)
	Error(msg string, args ...any)
	With(args ...any) Logger
	WithGroup(name string) Logger
}

// SlogLogger is a slog-based implementation of Logger
type SlogLogger struct {
	logger *slog.Logger
}

// NewSlogLogger creates a new SlogLogger with the specified log level
func NewSlogLogger(level slog.Level) *SlogLogger {
	opts := &slog.HandlerOptions{
		Level: level,
	}

	handler := slog.NewTextHandler(os.Stdout, opts)
	logger := slog.New(handler)

	return &SlogLogger{
		logger: logger,
	}
}

// NewDebugLogger creates a new logger configured for debug level
func NewDebugLogger() *SlogLogger {
	return NewSlogLogger(slog.LevelDebug)
}

// ParseLogLevel parses a log level string into slog.Level
func ParseLogLevel(level string) slog.Level {
	switch strings.ToUpper(level) {
	case "DEBUG":
		return slog.LevelDebug
	case "INFO":
		return slog.LevelInfo
	case "WARN", "WARNING":
		return slog.LevelWarn
	case "ERROR":
		return slog.LevelError
	default:
		return slog.LevelInfo // default to INFO
	}
}

// NewLoggerFromLevel creates a logger with the specified level string
func NewLoggerFromLevel(level string) *SlogLogger {
	return NewSlogLogger(ParseLogLevel(level))
}

func (l *SlogLogger) Debug(msg string, args ...any) {
	l.logger.Debug(msg, args...)
}

func (l *SlogLogger) Info(msg string, args ...any) {
	l.logger.Info(msg, args...)
}

func (l *SlogLogger) Warn(msg string, args ...any) {
	l.logger.Warn(msg, args...)
}

func (l *SlogLogger) Error(msg string, args ...any) {
	l.logger.Error(msg, args...)
}

func (l *SlogLogger) With(args ...any) Logger {
	return &SlogLogger{
		logger: l.logger.With(args...),
	}
}

func (l *SlogLogger) WithGroup(name string) Logger {
	return &SlogLogger{
		logger: l.logger.WithGroup(name),
	}
}

// LoggerContext provides context-aware logging
type LoggerContext struct {
	Logger
	ctx context.Context
}

// WithContext creates a new LoggerContext with the provided context
func WithContext(ctx context.Context, logger Logger) *LoggerContext {
	return &LoggerContext{
		Logger: logger,
		ctx:    ctx,
	}
}

func (lc *LoggerContext) Debug(msg string, args ...any) {
	lc.Logger.Debug(msg, args...)
}

func (lc *LoggerContext) Info(msg string, args ...any) {
	lc.Logger.Info(msg, args...)
}

func (lc *LoggerContext) Warn(msg string, args ...any) {
	lc.Logger.Warn(msg, args...)
}

func (lc *LoggerContext) Error(msg string, args ...any) {
	lc.Logger.Error(msg, args...)
}

func (lc *LoggerContext) With(args ...any) Logger {
	return &LoggerContext{
		Logger: lc.Logger.With(args...),
		ctx:    lc.ctx,
	}
}

func (lc *LoggerContext) WithGroup(name string) Logger {
	return &LoggerContext{
		Logger: lc.Logger.WithGroup(name),
		ctx:    lc.ctx,
	}
}
