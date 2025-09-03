package logoverse

type Registry map[string]Term

type Term struct {
    Word string
    Binding func(string) string
}

var registry = Registry{
	"$logoverse": Term{
		Word:    "logoverse",
		Binding: logoverseDef,
	},
}


func logoverseDef(path string) string {
	return "## $logoverse\n\n![$logoverse](" + RenderLogoverseSvg(path) + ")\n" +
		"### Terms \n\n" +
		term("$objects") + ": The fundamental building blocks of the logoverse, representing both fungible and non-fungible items that can be owned, transferred, and interacted with.\n\n" +
		term("$logoverse") + ": A universe of interconnected concepts and ideas, represented as a collection of $objects.\n\n" +
		term("$logograph") + ": A symbol or representation of a concept (model) within the logoverse, capturing its essence, behavior, and meaning.\n\n" +
		term("$logoglyph") + ": A visual representation of a logograph, often in the form of an image or icon, that conveys the concept's identity and significance within the logoverse.\n\n"
}