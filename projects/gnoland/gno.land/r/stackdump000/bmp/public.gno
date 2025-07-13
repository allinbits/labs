package bmp

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
)

var (
	registry         = avl.NewTree()
	realmAllowPrefix = []string{}
)

func init() {
	allowPatchesFromSubRealms()
	registry.Set("profile", Profile{})
	registry.Set("gnome", Gnome{})
	registry.Set("aib", Aib{})
	registry.Set("sierpinski", Triangle{})
	registry.Set("dapp", Dapp{})
}

type PixelSetter = func(x, y, r, g, b int)

type ImageApi interface {
	Pixels(p PixelSetter)
	Bounds() Bounds
	Description() string
}

func Register(name string, imgHandler ImageApi) {
	assertAccess()
	assertValidName(name)
	if _, exists := registry.Get(name); !exists {
		std.Emit("image_registered", "name", name)
	} else {
		std.Emit("image_updated", "name", name)
	}
	registry.Set(name, imgHandler)
}

func allowPatchesFromSubRealms() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/") // must be in realm sub-path
}

func hasAllowedPrefix() bool {
	prevRealm := std.PreviousRealm()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(prevRealm.PkgPath(), callerPath) {
			return true
		}
	}
	return false
}

func assertAccess() {
	if !hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}

type RegistryCallback = func(key string, value interface{}) bool
type RegistryMatcher = func(value interface{}) bool

func HasImageApi(value interface{}) bool {
	_, ok := value.(ImageApi)
	return ok
}

func IterateRegistry(callback RegistryCallback, matcher RegistryMatcher) {
	registry.IterateByOffset(0, registry.Size(), func(key string, value interface{}) bool {
		if matcher(value) {
			return callback(key, value)
		}
		return false
	})
}
