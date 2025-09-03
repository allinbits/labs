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
	"$logograph": Term{
		Word:    "logograph",
		Binding: logographDef,
	},
	"$logoglyph": Term{
		Word:    "logoglyph",
		Binding: logoglyphDef,
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

func logographDef(path string) string {
	return "## $logograph\n\n" +
		"A `$logograph` is a **symbolic representation of a model or concept** in the logoverse. " +
		"It captures the **meaning**, **behavior**, and **structure** of that concept, and may be visualized or executed.\n"
}

func logoglyphDef(path string) string {
	return "## $logoglyph\n\n" +
		"A `$logoglyph` is a **visual emblem** of a `$logograph`, rendered as an image, icon, or glyph. " +
		"It communicates identity, purpose, and essence in symbolic form.\n"
}

