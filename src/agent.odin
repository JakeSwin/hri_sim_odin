package hri

import "core:fmt"
import SDL "vendor:sdl2"
import "vendor:sdl2/ttf"
import "core:math/rand"

EXPLORE_RATE :: 0.3
// Maybe put on struct so can vary in UI
LEARNING_RATE :: 0.2

Position :: struct {
    x: int,
    y: int,
}

// Should maybe put pointer to simulation here and stop passing full simulation to each function
Agent :: struct {
    start_pos: Position,
    current_pos: Position,
    path: [dynamic]Position,
    parent_sim: ^Simulation,
}

agent_create :: proc(sim: ^Simulation, x, y: int) -> ^Agent {
    a := new(Agent)
    pos := Position{x,y}
    a.start_pos = pos
    a.current_pos = pos
    a.path = make_dynamic_array([dynamic]Position)
    a.parent_sim = sim
    return a
}

agent_free :: proc(agent: ^Agent) {
    delete(agent.path)
    free(agent)
}

agent_clear_simulation :: proc(using sim: ^Simulation) {
    free(agent)
    sim.agent = nil
}

agent_choose_action :: proc(using sim: ^Simulation) -> Action {
    if rand.float32_range(0, 1) <= EXPLORE_RATE {
        return rand.choice_enum(Action)
    } else {
        max_reward: f32 = 0.0
        action: Action
        for a in Action {
            if cell, _, available := sim_next_cell(sim, a); available && cell.reward >= max_reward {
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

// Do round calculation outside
// Returns true when goal has been reached, otherwise false
agent_play :: proc(sim: ^Simulation) -> bool {
    using sim.agent
    if reward := sim.mat[current_pos.y][current_pos.x].reward; reward != 0 {
        sim.mat[current_pos.y][current_pos.x].utility = reward
        for p in path {
            utility := sim.mat[p.y][p.x].utility
            r := utility + LEARNING_RATE * (reward - utility)
            sim.mat[p.y][p.x].utility = r
        }
        // Reset agent here? or outside
        return true
    } 
    action := agent_choose_action(sim)
    sim_move_agent(sim, action)
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