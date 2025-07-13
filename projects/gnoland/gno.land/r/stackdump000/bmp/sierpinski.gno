package bmp

type Triangle struct{}

var _ ImageApi = &Triangle{}

func (Triangle) Description() string {
	return "Sierpinski's triangle | Recursive fractal pattern - an algorithmic pixel set"
}

func (Triangle) Bounds() Bounds {
	return Bounds{X1: 0, Y1: 0, X2: 50, Y2: 50}
}

func (Triangle) Pixels(p PixelSetter) {
	// Helper function to draw Sierpiński's triangle recursively
	var drawTriangle func(x, y, size int, label string)
	drawTriangle = func(x int, y int, size int, label string) {
		if size == 1 {
			switch label {
			case "top":
				p(x+1, y, 1, 1, 1)
			case "left":
				p(x+1, y, 27, 68, 32)
			case "right":
				p(x+1, y, 134, 3, 23)
			default:
				panic("Invalid label")
			}
			return
		}

		// Recursive case: divide the triangle into 3 smaller triangles
		half := size / 2
		drawTriangle(x, y, half, "top")        // Top triangle
		drawTriangle(x+half, y, half, "left")  // Bottom-left triangle
		drawTriangle(x, y+half, half, "right") // Bottom-right triangle
	}

	// Initialize the triangle within the bounds of 50x50
	drawTriangle(0, 0, 50, "")
}
