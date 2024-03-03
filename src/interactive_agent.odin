package hri

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"
import "vendor:sdl2/ttf"

MANUAL_FEEDBACK :: 0.1

Feedback :: enum {
    NONE,
    GOOD,
    BAD,
}

InteractiveAgent :: struct {
	using agent: Agent,
    next_action: Action,
    last_action: Action,
    feedback: Feedback,
    state: enum {
        NEW_ACTION,
        IS_GOOD,
        WAS_GOOD,
    }
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

interactive_agent_play :: proc(using ia: ^InteractiveAgent) -> bool {
    switch state {
    case .IS_GOOD:
        switch feedback {
        case .NONE:
        case .GOOD:
            sim_move_agent(agent.parent_sim, next_action)
            last_action = next_action
            state = .WAS_GOOD
            feedback = .NONE
        case .BAD:
            action := random_action_excluding(next_action)
            sim_move_agent(agent.parent_sim, action)
            last_action = action
            state = .WAS_GOOD
            feedback = .NONE
        }
        return false
    case .WAS_GOOD:
        reward: f32 = 0.0
        switch feedback {
        case .NONE:
        case .GOOD:
            reward = MANUAL_FEEDBACK
            utility := agent.parent_sim.mat[ia.current_pos.y][ia.current_pos.x].utility
			r := utility + LEARNING_RATE * (reward - utility)
			agent.parent_sim.mat[ia.current_pos.y][ia.current_pos.x].utility = r
            state = .NEW_ACTION
            feedback = .NONE
        case .BAD:
            reward = -MANUAL_FEEDBACK
            utility := agent.parent_sim.mat[ia.current_pos.y][ia.current_pos.x].utility
			r := utility + LEARNING_RATE * (reward - utility)
			agent.parent_sim.mat[ia.current_pos.y][ia.current_pos.x].utility = r
            state = .NEW_ACTION
            feedback = .NONE
        }
        return false
    case .NEW_ACTION:
        if agent_check_end(ia) {
            return true
        }
        next_action = agent_choose_action(ia)
        state = .IS_GOOD
        return false
    }
    return false
}