package events

import (
	"context"
	"sync"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
)

// VerificationTask represents a periodic verification task
type VerificationTask struct {
	ID          string
	Name        string
	Description string
	Priority    string // "high", "medium", or "low"
	Interval    time.Duration
	Handler     func(ctx context.Context, guildID string, state *storage.GuildQueryState) error
	Enabled     bool
}

// VerificationScheduler manages periodic Discord member verification
type VerificationScheduler struct {
	guildID       string
	store         storage.ConfigStore
	eventHandlers *EventHandlers
	logger        core.Logger

	tasks   map[string]*VerificationTask
	timers  map[string]*time.Timer
	mutex   sync.RWMutex
	ctx     context.Context
	cancel  context.CancelFunc
	wg      sync.WaitGroup
	running bool
}

// NewVerificationScheduler creates a new verification scheduler
func NewVerificationScheduler(guildID string, store storage.ConfigStore, eventHandlers *EventHandlers, logger core.Logger) *VerificationScheduler {
	scheduler := &VerificationScheduler{
		guildID:       guildID,
		store:         store,
		eventHandlers: eventHandlers,
		logger:        logger,
		tasks:         make(map[string]*VerificationTask),
		timers:        make(map[string]*time.Timer),
	}

	// Initialize verification tasks
	scheduler.initializeTasks()

	return scheduler
}

// initializeTasks sets up the verification tasks
func (vs *VerificationScheduler) initializeTasks() {
	// High priority - online/active users
	vs.tasks["verify_high_priority"] = &VerificationTask{
		ID:          "verify_high_priority",
		Name:        "Verify High Priority Members",
		Description: "Verifies online/active guild members against Gno realm state",
		Priority:    "high",
		Interval:    1 * time.Minute,
		Handler:     vs.createVerificationHandler("high", 0),
		Enabled:     true,
	}

	// Medium priority - recently active users
	vs.tasks["verify_medium_priority"] = &VerificationTask{
		ID:          "verify_medium_priority",
		Name:        "Verify Medium Priority Members",
		Description: "Verifies recently active guild members against Gno realm state",
		Priority:    "medium",
		Interval:    5 * time.Minute,
		Handler:     vs.createVerificationHandler("medium", 0),
		Enabled:     true,
	}

	// Low priority - inactive/offline users (with incremental processing)
	vs.tasks["verify_low_priority"] = &VerificationTask{
		ID:          "verify_low_priority",
		Name:        "Verify Low Priority Members",
		Description: "Verifies inactive/offline guild members against Gno realm state incrementally",
		Priority:    "low",
		Interval:    30 * time.Minute,
		Handler:     vs.createVerificationHandler("low", 10), // Process 10 users at a time
		Enabled:     true,
	}
}

// createVerificationHandler creates a handler for a specific priority tier
func (vs *VerificationScheduler) createVerificationHandler(priority string, maxUsers int) func(context.Context, string, *storage.GuildQueryState) error {
	return func(ctx context.Context, guildID string, state *storage.GuildQueryState) error {
		vs.logger.Info("Processing verification task",
			"guild_id", guildID,
			"priority", priority,
			"max_users", maxUsers)

		if vs.eventHandlers == nil {
			vs.logger.Error("EventHandlers not available for verification",
				"guild_id", guildID,
				"priority", priority)
			return nil
		}

		// Process verification for this priority tier
		if err := vs.eventHandlers.ProcessTieredVerification(ctx, guildID, state, priority, maxUsers); err != nil {
			vs.logger.Error("Failed to process verification",
				"guild_id", guildID,
				"priority", priority,
				"error", err)
			return err
		}

		vs.logger.Info("Completed verification task",
			"guild_id", guildID,
			"priority", priority)
		return nil
	}
}

// Start begins the verification scheduler
func (vs *VerificationScheduler) Start(ctx context.Context) error {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()

	if vs.running {
		return nil
	}

	vs.ctx, vs.cancel = context.WithCancel(ctx)
	vs.running = true

	vs.logger.Info("Starting verification scheduler", "guild_id", vs.guildID)

	// Start timers for each enabled task
	for _, task := range vs.tasks {
		if task.Enabled {
			vs.logger.Info("Starting verification task timer",
				"guild_id", vs.guildID,
				"task_id", task.ID,
				"priority", task.Priority,
				"interval", task.Interval)
			vs.startTaskTimer(task)
		}
	}

	return nil
}

// Stop halts the verification scheduler
func (vs *VerificationScheduler) Stop() error {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()

	if !vs.running {
		return nil
	}

	vs.logger.Info("Stopping verification scheduler", "guild_id", vs.guildID)

	if vs.cancel != nil {
		vs.cancel()
	}

	// Stop all timers
	for _, timer := range vs.timers {
		timer.Stop()
	}
	vs.timers = make(map[string]*time.Timer)

	vs.running = false
	vs.wg.Wait()

	vs.logger.Info("Verification scheduler stopped", "guild_id", vs.guildID)
	return nil
}

// startTaskTimer starts a timer for a verification task
func (vs *VerificationScheduler) startTaskTimer(task *VerificationTask) {
	// Check if task should run immediately based on state
	shouldRunNow := vs.shouldRunTaskNow(task.ID)

	// Calculate initial delay
	var initialDelay time.Duration
	if shouldRunNow {
		initialDelay = 0
	} else {
		initialDelay = task.Interval
	}

	// Create timer
	timer := time.AfterFunc(initialDelay, func() {
		vs.wg.Add(1)
		go vs.runTask(task)
	})

	vs.timers[task.ID] = timer
}

// shouldRunTaskNow checks if a task should run immediately
func (vs *VerificationScheduler) shouldRunTaskNow(taskID string) bool {
	config, err := vs.store.Get(vs.guildID)
	if err != nil {
		return true // Run immediately if we can't check state
	}

	queryState, exists := config.GetQueryState(taskID)
	if !exists {
		return true // Run immediately if no state exists
	}

	// Check if enough time has passed since last run
	return time.Now().After(queryState.NextRunTimestamp)
}

// runTask executes a verification task
func (vs *VerificationScheduler) runTask(task *VerificationTask) {
	defer vs.wg.Done()

	// Check if scheduler is still running
	vs.mutex.RLock()
	if !vs.running {
		vs.mutex.RUnlock()
		return
	}
	vs.mutex.RUnlock()

	vs.logger.Debug("Running verification task",
		"guild_id", vs.guildID,
		"task_id", task.ID,
		"priority", task.Priority)

	// Get or create task state
	config, err := vs.store.Get(vs.guildID)
	if err != nil {
		vs.logger.Error("Failed to get guild config", "guild_id", vs.guildID, "error", err)
		vs.rescheduleTask(task)
		return
	}

	// Ensure query state exists for the task
	queryState := config.EnsureQueryState(task.ID, true)

	// Check if task is already running
	if queryState.IsExecuting {
		vs.logger.Debug("Task already executing, skipping",
			"guild_id", vs.guildID,
			"task_id", task.ID)
		vs.rescheduleTask(task)
		return
	}

	// Set executing state
	queryState.SetExecuting(true)
	queryState.LastRunTimestamp = time.Now()

	// Save state
	if err := vs.store.Set(vs.guildID, config); err != nil {
		vs.logger.Error("Failed to save execution state", "guild_id", vs.guildID, "error", err)
		vs.rescheduleTask(task)
		return
	}

	// Run the task handler
	err = task.Handler(vs.ctx, vs.guildID, queryState)

	// Update state based on result
	if err != nil {
		queryState.RecordError(err)
		vs.logger.Error("Verification task failed",
			"guild_id", vs.guildID,
			"task_id", task.ID,
			"error", err)
	} else {
		queryState.ClearErrors()
		vs.logger.Info("Verification task completed",
			"guild_id", vs.guildID,
			"task_id", task.ID)
	}

	// Clear executing state and update next run time
	queryState.SetExecuting(false)
	queryState.UpdateRunTimestamp(task.Interval)

	// Save final state
	if err := vs.store.Set(vs.guildID, config); err != nil {
		vs.logger.Error("Failed to save final state", "guild_id", vs.guildID, "error", err)
	}

	// Reschedule task
	vs.rescheduleTask(task)
}

// rescheduleTask schedules the next run of a task
func (vs *VerificationScheduler) rescheduleTask(task *VerificationTask) {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()

	if !vs.running {
		return
	}

	// Cancel existing timer if any
	if timer, exists := vs.timers[task.ID]; exists {
		timer.Stop()
	}

	// Create new timer
	timer := time.AfterFunc(task.Interval, func() {
		vs.wg.Add(1)
		go vs.runTask(task)
	})

	vs.timers[task.ID] = timer
}

// EnableTask enables a verification task
func (vs *VerificationScheduler) EnableTask(taskID string) error {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()

	task, exists := vs.tasks[taskID]
	if !exists {
		return nil
	}

	task.Enabled = true

	// Start timer if scheduler is running
	if vs.running {
		vs.startTaskTimer(task)
	}

	return nil
}

// DisableTask disables a verification task
func (vs *VerificationScheduler) DisableTask(taskID string) error {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()

	task, exists := vs.tasks[taskID]
	if !exists {
		return nil
	}

	task.Enabled = false

	// Stop timer if exists
	if timer, exists := vs.timers[taskID]; exists {
		timer.Stop()
		delete(vs.timers, taskID)
	}

	return nil
}
