package discord

import (
	"errors"
	"sync"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/bwmarrin/discordgo"
)

// MockDiscordSession for testing both RoleManager and InteractionHandlers
type MockDiscordSession struct {
	mu               sync.RWMutex
	user             *discordgo.User
	guilds           map[string]*discordgo.Guild
	roles            map[string][]*discordgo.Role               // guildID -> roles
	members          map[string]map[string]*discordgo.Member    // guildID -> userID -> member
	commands         map[string][]*discordgo.ApplicationCommand // guildID -> commands
	responses        map[string]*discordgo.InteractionResponse
	followups        map[string]*discordgo.WebhookEdit
	roleCreateError  error
	roleDeleteError  error
	rolesErr         error
	guildMemberError error
	permissionsError error
	commandsError    error
	permissions      map[string]int64 // userID -> permissions
}

func NewMockDiscordSession() *MockDiscordSession {
	return &MockDiscordSession{
		user: &discordgo.User{
			ID:       "bot-user-123",
			Username: "test-bot",
		},
		guilds:      make(map[string]*discordgo.Guild),
		roles:       make(map[string][]*discordgo.Role),
		members:     make(map[string]map[string]*discordgo.Member),
		commands:    make(map[string][]*discordgo.ApplicationCommand),
		responses:   make(map[string]*discordgo.InteractionResponse),
		followups:   make(map[string]*discordgo.WebhookEdit),
		permissions: make(map[string]int64),
	}
}

// State property for role manager compatibility
func (m *MockDiscordSession) State() *discordgo.State {
	return &discordgo.State{}
}

func (m *MockDiscordSession) GuildRoles(guildID string, options ...discordgo.RequestOption) ([]*discordgo.Role, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.rolesErr != nil {
		return nil, m.rolesErr
	}

	roles := m.roles[guildID]
	if roles == nil {
		return []*discordgo.Role{}, nil
	}

	// Return copy
	result := make([]*discordgo.Role, len(roles))
	copy(result, roles)
	return result, nil
}

func (m *MockDiscordSession) GuildRoleCreate(guildID string, data *discordgo.RoleParams, options ...discordgo.RequestOption) (*discordgo.Role, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.roleCreateError != nil {
		return nil, m.roleCreateError
	}

	role := &discordgo.Role{
		ID:       "role_" + data.Name + "_123",
		Name:     data.Name,
		Color:    *data.Color,
		Position: 1,
	}

	if m.roles[guildID] == nil {
		m.roles[guildID] = []*discordgo.Role{}
	}
	m.roles[guildID] = append(m.roles[guildID], role)

	return role, nil
}

func (m *MockDiscordSession) GuildRoleDelete(guildID, roleID string, options ...discordgo.RequestOption) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.roleDeleteError != nil {
		return m.roleDeleteError
	}

	roles := m.roles[guildID]
	for i, role := range roles {
		if role.ID == roleID {
			m.roles[guildID] = append(roles[:i], roles[i+1:]...)
			return nil
		}
	}

	return errors.New("role not found")
}

func (m *MockDiscordSession) Guild(guildID string, options ...discordgo.RequestOption) (*discordgo.Guild, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	guild := m.guilds[guildID]
	if guild == nil {
		return nil, errors.New("guild not found")
	}
	return guild, nil
}

func (m *MockDiscordSession) GuildMember(guildID, userID string, options ...discordgo.RequestOption) (*discordgo.Member, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.guildMemberError != nil {
		return nil, m.guildMemberError
	}

	guildMembers := m.members[guildID]
	if guildMembers == nil {
		return nil, errors.New("guild not found")
	}

	member := guildMembers[userID]
	if member == nil {
		return nil, errors.New("member not found")
	}
	return member, nil
}

func (m *MockDiscordSession) GuildMemberRoleAdd(guildID, userID, roleID string, options ...discordgo.RequestOption) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	guildMembers := m.members[guildID]
	if guildMembers == nil {
		return errors.New("guild not found")
	}

	member := guildMembers[userID]
	if member == nil {
		return errors.New("member not found")
	}

	// Check if role already exists
	for _, existingRoleID := range member.Roles {
		if existingRoleID == roleID {
			return nil // Already has role
		}
	}

	member.Roles = append(member.Roles, roleID)
	return nil
}

func (m *MockDiscordSession) GuildMemberRoleRemove(guildID, userID, roleID string, options ...discordgo.RequestOption) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	guildMembers := m.members[guildID]
	if guildMembers == nil {
		return errors.New("guild not found")
	}

	member := guildMembers[userID]
	if member == nil {
		return errors.New("member not found")
	}

	// Remove role
	for i, existingRoleID := range member.Roles {
		if existingRoleID == roleID {
			member.Roles = append(member.Roles[:i], member.Roles[i+1:]...)
			break
		}
	}

	return nil
}

func (m *MockDiscordSession) UserChannelPermissions(userID, channelID string, options ...discordgo.RequestOption) (int64, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.permissionsError != nil {
		return 0, m.permissionsError
	}

	perms := m.permissions[userID]
	return perms, nil
}

func (m *MockDiscordSession) ApplicationCommandCreate(appID, guildID string, cmd *discordgo.ApplicationCommand) (*discordgo.ApplicationCommand, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.commandsError != nil {
		return nil, m.commandsError
	}

	cmd.ID = "cmd-" + cmd.Name + "-123"
	if m.commands[guildID] == nil {
		m.commands[guildID] = []*discordgo.ApplicationCommand{}
	}
	m.commands[guildID] = append(m.commands[guildID], cmd)
	return cmd, nil
}

func (m *MockDiscordSession) ApplicationCommands(appID, guildID string) ([]*discordgo.ApplicationCommand, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.commandsError != nil {
		return nil, m.commandsError
	}

	commands := m.commands[guildID]
	if commands == nil {
		return []*discordgo.ApplicationCommand{}, nil
	}
	return commands, nil
}

func (m *MockDiscordSession) ApplicationCommandDelete(appID, guildID, cmdID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.commandsError != nil {
		return m.commandsError
	}

	commands := m.commands[guildID]
	for i, cmd := range commands {
		if cmd.ID == cmdID {
			m.commands[guildID] = append(commands[:i], commands[i+1:]...)
			break
		}
	}
	return nil
}

func (m *MockDiscordSession) InteractionRespond(interaction *discordgo.Interaction, resp *discordgo.InteractionResponse, options ...discordgo.RequestOption) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.responses[interaction.ID] = resp
	return nil
}

func (m *MockDiscordSession) InteractionResponseEdit(interaction *discordgo.Interaction, edit *discordgo.WebhookEdit, options ...discordgo.RequestOption) (*discordgo.Message, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.followups[interaction.ID] = edit
	return &discordgo.Message{}, nil
}

// Setup helpers
func (m *MockDiscordSession) AddGuild(guildID, ownerID string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.guilds[guildID] = &discordgo.Guild{
		ID:      guildID,
		Name:    "Test Guild",
		OwnerID: ownerID,
	}

	if m.members[guildID] == nil {
		m.members[guildID] = make(map[string]*discordgo.Member)
	}
}

func (m *MockDiscordSession) AddMember(guildID, userID string, roles []string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.members[guildID] == nil {
		m.members[guildID] = make(map[string]*discordgo.Member)
	}

	m.members[guildID][userID] = &discordgo.Member{
		User: &discordgo.User{
			ID:       userID,
			Username: "test-user-" + userID,
		},
		Roles: roles,
	}
}

func (m *MockDiscordSession) AddRole(guildID string, role *discordgo.Role) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.roles[guildID] == nil {
		m.roles[guildID] = []*discordgo.Role{}
	}

	// Create a copy to avoid external modification
	roleCopy := *role
	m.roles[guildID] = append(m.roles[guildID], &roleCopy)
}

func (m *MockDiscordSession) SetRoleCreateError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.roleCreateError = err
}

func (m *MockDiscordSession) SetRoleDeleteError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.roleDeleteError = err
}

func (m *MockDiscordSession) SetRolesError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.rolesErr = err
}

func (m *MockDiscordSession) SetGuildMemberError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.guildMemberError = err
}

func (m *MockDiscordSession) SetCommandsError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.commandsError = err
}

func (m *MockDiscordSession) SetUserPermissions(userID string, permissions int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.permissions[userID] = permissions
}

// MockLogger for testing
type MockLogger struct {
	mu       sync.RWMutex
	messages []LogMessage
}

type LogMessage struct {
	Level string
	Msg   string
	Args  []any
}

func NewMockLogger() *MockLogger {
	return &MockLogger{
		messages: make([]LogMessage, 0),
	}
}

func (l *MockLogger) Debug(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "DEBUG", Msg: msg, Args: args})
}

func (l *MockLogger) Info(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "INFO", Msg: msg, Args: args})
}

func (l *MockLogger) Warn(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "WARN", Msg: msg, Args: args})
}

func (l *MockLogger) Error(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "ERROR", Msg: msg, Args: args})
}

func (l *MockLogger) With(args ...any) core.Logger {
	return l
}

func (l *MockLogger) WithGroup(name string) core.Logger {
	return l
}

func (l *MockLogger) HasMessage(level, msgSubstring string) bool {
	l.mu.RLock()
	defer l.mu.RUnlock()

	for _, msg := range l.messages {
		if msg.Level == level && contains(msg.Msg, msgSubstring) {
			return true
		}
	}
	return false
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) &&
		(s == substr ||
			(len(s) > len(substr) && (s[:len(substr)] == substr || contains(s[1:], substr))))
}
