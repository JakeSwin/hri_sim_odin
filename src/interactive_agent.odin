package hri

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"
import "vendor:sdl2/ttf"

Feedback :: enum {
    NONE,
    GOOD,
    BAD,
}

InteractiveAgent :: struct {
	using agent: Agent,
    next_action: Action,
    waiting_for_feedback: bool,
    feedback: Feedback,
}

interactive_agent_create :: proc(sim: ^Simulation, x, y: int) -> ^InteractiveAgent {
    a := new(InteractiveAgent)
	pos := Position{x, y}
	a.start_pos = pos
	a.current_pos = pos
	a.path = make_dynamic_array([dynamic]Position)
	a.parent_sim = sim
    a.variant = a
	return a
}