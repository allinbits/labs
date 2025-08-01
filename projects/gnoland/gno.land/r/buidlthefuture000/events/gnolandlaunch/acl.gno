package gnolandlaunch

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

var (
	acl           = &Acl{}
	roles         = make(map[string]*avl.Tree)
	roleCheckFunc = make(map[string]func(std.Address) bool)
)

type Acl struct{}

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath())
	declareRole("organizer")
	declareRole("attendee")
	declareAlias("attendee", "waitlist") // alias for attendee
	declareRole("speaker")
}

func declareRole(role string) {
	if _, exists := roles[role]; !exists {
		roles[role] = avl.NewTree()
		roleCheckFunc[role] = roles[role].Has
	}
}

func declareAlias(role string, alias string) {
	if _, exists := roles[role]; !exists {
		panic("role not found: " + role)
	}
	if _, exists := roles[alias]; exists {
		panic("alias already exists: " + alias)
	}
	roles[alias] = roles[role]
	roleCheckFunc[alias] = roleCheckFunc[role]
}

func hasAllowedPrefix() bool {
	currentRealm := std.CurrentRealm()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(currentRealm.PkgPath(), callerPath) {
			return true
		}
	}
	return false
}

func assertAccess() {
	// FIXME use ACL to restrict access to this function to admins
	if !hasAllowedPrefix() {
		panic("access denied: " + std.CurrentRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}

// getOrCreateRoleTree lazily initializes and retrieves the AVL tree for a role.
func getOrCreateRoleTree(role string) *avl.Tree {
	tree, exists := roles[role]
	if !exists {
		declareRole(role)
	}
	return tree
}

func (*Acl) AddRole(role string, addr std.Address) {
	assertAccess()
	tree := getOrCreateRoleTree(role)
	tree.Set(string(addr), struct{}{})
}

func (*Acl) RemoveRole(role string, addr std.Address) {
	assertAccess()
	tree, exists := roles[role]
	if exists {
		tree.Remove(string(addr))
	} else {
		panic("role not found: " + role)
	}
}

func (*Acl) ResetRoles() {
	assertAccess()
	roles = make(map[string]*avl.Tree)
}

func (*Acl) HasRole(role string, addr std.Address) bool {
	tree, exists := roles[role]
	if !exists {
		return false
	}
	return roleCheckFunc[role](addr)
}

func (*Acl) ListRoles() []string {
	roleList := make([]string, 0, len(roles))
	for role := range roles {
		roleList = append(roleList, role)
	}
	return roleList
}

func (*Acl) RenderList(role string) string {
	var sb strings.Builder
	sb.WriteString(ufmt.Sprintf("\n### %s \n", role))
	tree, exists := roles[role]
	if !exists {
		sb.WriteString("role not found\n")
	}
	addresses := treeToSlice(tree)
	if len(addresses) == 0 {
		return ""
	}
	sb.WriteString(toMDList(addrs))
	return sb.String()
}

func treeToSlice(tree *avl.Tree) []std.Address {
	result := make([]std.Address, 0)
	tree.IterateByOffset(0, 100, func(k string, _ any) bool {
		if k == "" {
			return true
		}
		result = append(result, std.Address(k))
		return false
	})
	return result
}

func toMDList(addresses []std.Address) string {
	var result string
	for _, addr := range addresses {
		result += ufmt.Sprintf("- %v\n", string(addr))
	}
	return result
}
