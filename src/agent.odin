package hri

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"
import "vendor:sdl2/ttf"

EXPLORE_RATE :: 0.3
// Maybe put on struct so can vary in UI
LEARNING_RATE :: 0.2

Position :: struct {
	x: int,
	y: int,
}

// Should maybe put pointer to simulation here and stop passing full simulation to each function
Agent :: struct {
	start_pos:   Position,
	current_pos: Position,
	path:        [dynamic]Position,
	parent_sim:  ^Simulation,
    variant: union {
		^Agent,
        ^InteractiveAgent,
    }
}

agent_create :: proc(sim: ^Simulation, x, y: int) -> ^Agent {
    a := new(Agent)
	pos := Position{x, y}
	a.start_pos = pos
	a.current_pos = pos
	a.path = make_dynamic_array([dynamic]Position)
	a.parent_sim = sim
	a.variant = a
	return a
}

agent_free :: proc(agent: ^Agent) {
	delete(agent.path)
	switch s in agent.variant {
		case ^InteractiveAgent:
			free(s)
		case ^Agent:
			free(agent)
	}
}

agent_choose_action :: proc(using agent: ^Agent) -> Action {
	if rand.float32_range(0, 1) <= EXPLORE_RATE {
		return rand.choice_enum(Action)
	} else {
		max_reward: f32 = 0.0
		action: Action
		for a in Action {
			if cell, _, available := sim_next_cell(parent_sim, current_pos, a);
			   available && cell.reward >= max_reward {
				if cell.reward >= max_reward {
					max_reward = cell.reward
					action = a
				}
			}
		}
		if max_reward == 0.0 {
			return rand.choice_enum(Action)
		}
		return action
	}
}

agent_check_end :: proc(using agent: ^Agent) -> bool {
	if reward := parent_sim.mat[current_pos.y][current_pos.x].reward; reward != 0 {
		parent_sim.mat[current_pos.y][current_pos.x].utility = reward
		for p in path {
			utility := parent_sim.mat[p.y][p.x].utility
			r := utility + LEARNING_RATE * (reward - utility)
			parent_sim.mat[p.y][p.x].utility = r
		}
		// Reset agent here? or outside
		return true
	}
	return false
}

// Do round calculation outside
// Returns true when goal has been reached, otherwise false
agent_play :: proc(using agent: ^Agent) -> bool {
	if agent_check_end(agent) {
		return true
	}
	action := agent_choose_action(agent)
	sim_move_agent(parent_sim, action)
	return false
}

is_agent_start :: proc(using agent: ^Agent, x, y: int) -> bool {
	return start_pos.x == x && start_pos.y == y
}

is_agent_current :: proc(using agent: ^Agent, x, y: int) -> bool {
	return current_pos.x == x && current_pos.y == y
}

intersects_agent :: proc(using agent: ^Agent, x, y: int) -> bool {
	return is_agent_start(agent, x, y) || is_agent_current(agent, x, y)
}
