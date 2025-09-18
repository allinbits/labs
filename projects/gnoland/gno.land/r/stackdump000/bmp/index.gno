package bmp

import (
	"std"
	"strings"
)

// assertValidName controls the name of the image by the caller path
// ex1: /r/stackdump/bmp/v0.0.1_profile is allowed to set "profile" image
// ex2: /r/stackdump/bmp/v0.0.1/subfolder/profile is allowed to set "profile" image
func assertValidName(name string) {
	if !strings.HasSuffix(std.PreviousRealm().PkgPath(), name) {
		panic("invalid name: " + name + " must end with " + std.PreviousRealm().PkgPath())
	}
}

func renderList(selected string) string {
	if registry.Size() == 0 {
		return "No images registered."
	}

	keys := make([]string, 0, registry.Size())
	registry.IterateByOffset(0, registry.Size(), func(key string, value any) bool {
		if _, ok := value.(ImageApi); ok {
			keys = append(keys, key)
		}
		return false
	})

	// Find the index of the selected image
	selectedIndex := -1
	for i, key := range keys {
		if key == selected {
			selectedIndex = i
			break
		}
	}

	if selectedIndex == -1 {
		return "Selected image not found."
	}

	// Get previous and next images circularly
	prevIndex := (selectedIndex - 1 + len(keys)) % len(keys)
	nextIndex := (selectedIndex + 1) % len(keys)

	return "[bmp]( ./bmp:" + keys[selectedIndex] + ":source):" +
		"[" + keys[selectedIndex] + "]( ./bmp:" + keys[selectedIndex] + ")\n\n" +
		"[<- prev](./bmp:" + keys[prevIndex] + ")\n" +
		"[next ->]( ./bmp:" + keys[nextIndex] + ")\n"


func getImageApi(path string) ImageApi {
	imgHandler, ok := registry.Get(path)
	if !ok {
		panic("path not registered - (in dev?) make sure realm is deployed: r/stackdump000/bmp/" + path)
	}
	return imgHandler.(ImageApi)
}

func Frame() string {
	d, ok := registry.Get("dapp") // ensure dapp is registered
	if !ok {
		panic("dapp image not registered")
	}
	return d.(Dapp).Frame()
}

// Render image w/ a link to the SVG image rather than rendering it inline.
func Link(path string) string {
	if path == "" {
		path = "profile"
	}
	link := "/svg/r/stackdump000/bmp:" + path + ":svg"
	return "[![" + link + "](" + link + ")](" + link + ")"
}

func Markdown() string {
	d, ok := registry.Get("dapp") // ensure dapp is registered
	if !ok {
		panic("dapp image not registered")
	}
	return d.(Dapp).Markdown()
}

func Svg(name string) string {
	builder := getImageApi(name)

	img := &PixelImage{
		Pixels: make([]ColorPixel, GridWidth*GridWidth),
		Bounds: builder.Bounds(),
	}
	builder.Pixels(img.SetPixel)
	return img.ToSvg()
}

// Render supports viewing with markdown rendering or can return the SVG directly.
// markdown realm: http://127.0.0.1:8888/r/stackdump000/bmp:profile:svg
// host as svg: http://127.0.0.1:8888/svg/r/stackdump000/bmp:profile:svg
func Render(path string) (out string) {
	args := []string{}
	suffix := ""
	if path == "" {
		path = "profile"
	} else {
		args = strings.Split(path, ":")
		if len(args) >= 1 {
			path = args[0]
		}
		if len(args) >= 2 {
			suffix = args[len(args)-1]
		}
	}
	img := &PixelImage{
		Pixels: make([]ColorPixel, GridWidth*GridWidth),
	}
	switch suffix {
	case "img":
		return Link(path)
	case "svg":
		builder := getImageApi(path)
		img.Bounds = builder.Bounds()
		builder.Pixels(img.SetPixel)
		return img.ToSvg()
	case "frame":
		if path == "dapp" {
			return Frame()
		}
	default:
		if path == "dapp" {
			return Markdown()
		}
	}
	builder := getImageApi(path)
	img.Bounds = builder.Bounds()
	builder.Pixels(img.SetPixel)
	out = "[" + img.ToMarkdown() + path + ".svg](/svg/r/stackdump000/bmp:" + path + ":svg)\n\n"
	out += "\n\n" + renderList(path) + "\n\n"
	out += "#### " + builder.Description() + "\n\n"
	out += "\n\n[PIXELFIED DAPP](./bmp:dapp)\n\n"
	out += "\n\n[RSS FEED](./feed)\n\n"

	if len(args) == 2 {
		if args[1] == "source" {
			return "```\n" + img.Source(args[0]) + "```"
		}
	}
	return out
}
