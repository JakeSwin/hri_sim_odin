package hri

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"
import "vendor:sdl2/ttf"

Action :: enum {
	NONE,
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

random_action_excluding :: proc(avoid_action: Action) -> Action {
    action := rand.choice_enum(Action)
    for action == avoid_action || action == .NONE {
        action = rand.choice_enum(Action)
    }
    return action
}

Content :: enum {
	NOTHING,
	WALL,
}

Cell :: struct {
	utility:  f32,
	policy:   Action,
	reward:   f32,
	contains: Content,
	rect:     SDL.Rect,
	selected: bool,
}

Simulation :: struct {
	rows:    u32,
	cols:    u32,
	mat:     [][]Cell,
	backing: []Cell,
	rect:    SDL.Rect,
	agent:   ^Agent,
}

GRID_SIZE :: 60
GAP_SIZE :: 3

sim_create :: proc(rows, cols: u32) -> ^Simulation {
	sim := new(Simulation)
	sim.rows = rows
	sim.cols = cols
	sim.mat = make([][]Cell, rows)
	sim.backing = make([]Cell, cols * rows)
	offset: u32 = 0
	for row_index in 0 ..< rows {
		row := sim.backing[offset:][:cols]
		sim.mat[row_index] = row
		offset += cols
	}
	return sim
}

sim_destroy :: proc(using sim: ^Simulation) {
	delete(mat)
	delete(backing)
	if sim.agent != nil {
		sim_destroy_agent(sim)
	}
}

sim_add_agent :: proc(using sim: ^Simulation, x, y: int) {
	sim.agent = agent_create(sim, x, y)
}

sim_add_interactive_agent :: proc(using sim: ^Simulation, x, y: int) {
	sim.agent = interactive_agent_create(sim, x, y)
}

sim_destroy_agent :: proc(using sim: ^Simulation) {
	agent_free(sim.agent)
	sim.agent = nil
}

sim_get_reward_at_position :: proc(using sim: ^Simulation, position: Position) -> f32 {
	return sim.mat[position.y][position.x].reward
}

sim_add_wall :: proc(using sim: ^Simulation, x, y: u32) {
	sim.mat[y][x].contains = .WALL
}

sim_add_reward :: proc(using sim: ^Simulation, x, y: u32, reward: f32) {
	sim.mat[y][x].reward = reward
}

sim_next_cell :: proc(
	using sim: ^Simulation,
	current_pos: Position,
	action: Action,
) -> (
	^Cell,
	Position,
	bool,
) {
	switch action {
	case .NONE:
		next_cell := &mat[current_pos.y][current_pos.x]
		return next_cell, Position{current_pos.x, current_pos.y}, true
	case .UP:
		if current_pos.y - 1 < 0 {
			return nil, {}, false
		}
		next_cell := &mat[current_pos.y - 1][current_pos.x]
		if next_cell.contains == .WALL {
			return nil, {}, false
		}
		return next_cell, Position{current_pos.x, current_pos.y - 1}, true
	case .DOWN:
		if current_pos.y + 1 > int(rows - 1) {
			return nil, {}, false
		}
		next_cell := &mat[current_pos.y + 1][current_pos.x]
		if next_cell.contains == .WALL {
			return nil, {}, false
		}
		return next_cell, Position{current_pos.x, current_pos.y + 1}, true
	case .LEFT:
		if current_pos.x - 1 < 0 {
			return nil, {}, false
		}
		next_cell := &mat[current_pos.y][current_pos.x - 1]
		if next_cell.contains == .WALL {
			return nil, {}, false
		}
		return next_cell, Position{current_pos.x - 1, current_pos.y}, true
	case .RIGHT:
		if current_pos.x + 1 > int(cols - 1) {
			return nil, {}, false
		}
		next_cell := &mat[current_pos.y][current_pos.x + 1]
		if next_cell.contains == .WALL {
			return nil, {}, false
		}
		return next_cell, Position{current_pos.x + 1, current_pos.y}, true
	}
	return nil, {}, false
}

sim_move_agent :: proc(sim: ^Simulation, action: Action) -> bool {
	if _, pos, available := sim_next_cell(sim, sim.agent.current_pos, action); available {
		append(&sim.agent.path, sim.agent.current_pos)
		// sim.mat[sim.agent.current_pos.y][sim.agent.current_pos.x].policy = action
		sim.agent.current_pos = pos
		return true
	}
	return false
}

sim_reset_agent :: proc(using sim: ^Simulation) {
	agent.current_pos = agent.start_pos
	clear(&agent.path)
}

// Checks that the policy does not create loops.
// TODO Check if this is necessary / actually part of the policy generation or 
// if it is something that I have just made up
sim_policy_check_repeat :: proc(action: Action, policy: Action) -> bool {
	if action == .LEFT && policy == .RIGHT ||
	   action == .RIGHT && policy == .LEFT ||
	   action == .UP && policy == .DOWN ||
	   action == .DOWN && policy == .UP {
		return true
	} else {
		return false
	}
}

sim_update_policy :: proc(using sim: ^Simulation) {
	for row, j in mat {
		for &cell, i in row {
			if cell.reward != 0.0 {
				cell.policy = .NONE
				continue
			}
			best_utility: f32 = -99.9
			best_action: Action
			for a in Action {
				// Otherwise if own cell is highest utility in region policy will stay still
				if a == .NONE {
					continue
				}
				if next_cell, pos, available := sim_next_cell(sim, {i, j}, a); available {
					if next_cell.utility > best_utility && !sim_policy_check_repeat(a, next_cell.policy) {
						best_utility = next_cell.utility
						best_action = a
					}
				}
			}
			cell.policy = best_action
		}
	}
}

sim_update :: proc(using app: ^App) {
	if simulation == nil {
		return
	}
	if playing {
		switch s in simulation.agent.variant {
		case ^Agent:
			if agent_play(s) {
				sim_reset_agent(simulation)
				current_round += 1
				if max_rounds == current_round {
					playing = false
					current_round = 0
				}
				sim_update_policy(simulation)
			}
		case ^InteractiveAgent:
			if interactive_agent_play(s) {
				sim_reset_agent(simulation)
				current_round += 1
				if max_rounds == current_round {
					playing = false
					current_round = 0
				}
				sim_update_policy(simulation)
			}
		}
		return
	}
	down, across, width, height: i32
	width = i32((simulation.cols * GRID_SIZE) + ((simulation.cols + 1) * GAP_SIZE))
	height = i32((simulation.rows * GRID_SIZE) + ((simulation.rows + 1) * GAP_SIZE))
	across = (app.viewport.w / 2) - (width / 2)
	down = (app.viewport.h / 2) - (height / 2)
	simulation.rect = SDL.Rect{across, down, width, height}

	for row, j in simulation.mat {
		for &cell, i in row {
			x := i32(i * (GRID_SIZE + GAP_SIZE)) + across + GAP_SIZE
			y := i32(j * (GRID_SIZE + GAP_SIZE)) + down + GAP_SIZE
			cell.rect = SDL.Rect{x, y, GRID_SIZE, GRID_SIZE}

			if mouse_pos_x > x &&
			   mouse_pos_x < x + GRID_SIZE &&
			   mouse_pos_y > y &&
			   mouse_pos_y < y + GRID_SIZE {
				cell.selected = true
				if mouse_down {
					switch current_tool {
					case .ADD_AGENT:
						new_agent: ^Agent
						if app.is_interactive {
							new_agent = interactive_agent_create(simulation, i, j)
						} else {
							new_agent = agent_create(simulation, i, j)
						}
						if simulation.agent == nil {
							simulation.agent = new_agent
						} else {
							cell.contains = .NOTHING
							sim_destroy_agent(simulation)
							simulation.agent = new_agent
							// sim_add_agent(simulation, i, j)
						}
					case .ADD_WALL:
						if simulation.agent != nil {
							if intersects_agent(simulation.agent, i, j) {
								sim_destroy_agent(simulation)
							}
						}
						cell.contains = .WALL
					case .CLEAR:
						if simulation.agent != nil {
							if intersects_agent(simulation.agent, i, j) {
								sim_destroy_agent(simulation)
							}
						}
						cell.contains = .NOTHING
						cell.reward = 0
					case .SET_REWARD:
						cell.reward = reward_add
					case .NONE:
					}
				}
			} else {
				cell.selected = false
			}
		}
	}
}

sim_draw :: proc(using app: ^App) {
	if simulation != nil {
		SDL.SetRenderDrawColor(renderer, 0, 0, 0, 255)
		SDL.RenderFillRect(renderer, &simulation.rect)
		SDL.SetRenderDrawColor(renderer, 255, 255, 255, 255)
		for row, j in simulation.mat {
			for &cell, i in row {
				if cell.contains == .WALL {
					SDL.SetRenderDrawColor(renderer, 0, 0, 0, 255)
					SDL.RenderFillRect(renderer, &cell.rect)
					SDL.SetRenderDrawColor(renderer, 255, 255, 255, 255)
					continue
				} else if cell.selected {
					SDL.SetRenderDrawColor(renderer, 200, 200, 200, 255)
					SDL.RenderFillRect(renderer, &cell.rect)
					SDL.SetRenderDrawColor(renderer, 255, 255, 255, 255)
				} else {
					SDL.RenderFillRect(renderer, &cell.rect)
				}
				if show_utility {
					sim_draw_value(app, &cell, cell.utility, "%.3f")
					continue
				}
				if show_policy {
					switch cell.policy {
					case .NONE:
						sim_draw_image_at_cell(app, &cell, "circle.png")
					case .UP:
						sim_draw_image_at_cell(app, &cell, "arrow_upward.png")
					case .DOWN:
						sim_draw_image_at_cell(app, &cell, "arrow_downward.png")
					case .LEFT:
						sim_draw_image_at_cell(app, &cell, "arrow_back.png")
					case .RIGHT:
						sim_draw_image_at_cell(app, &cell, "arrow_forward.png")
					}
					continue
				}
				if simulation.agent != nil {
					if is_agent_current(simulation.agent, i, j) {
						sim_draw_image_at_cell(app, &cell, "robot.png")
						continue
					}
				}
				if cell.reward != f32(0) {
					sim_draw_value(app, &cell, cell.reward, "%.1f")
				}
			}
		}
	}
}

sim_draw_image_at_cell :: proc(using app: ^App, cell: ^Cell, image_path: string) {
	texture := app_get_texture(app, image_path)

	// Don't need to know texture width and height becaus I can just set it to half grid size each time
	rect := SDL.Rect {
		cell.rect.x + (GRID_SIZE / 4),
		cell.rect.y + (GRID_SIZE / 4),
		GRID_SIZE / 2,
		GRID_SIZE / 2,
	}

	SDL.RenderCopyEx(renderer, texture, nil, &rect, 0.0, nil, .NONE)
}

sim_draw_value :: proc(using app: ^App, cell: ^Cell, val: f32, format: string) {
	font_colour: SDL.Color = {80, 80, 80, 255} if !cell.selected else {30, 30, 30, 255}
	surface_text := ttf.RenderText_Solid(font, fmt.caprintf(format, val), font_colour)
	message_text := SDL.CreateTextureFromSurface(renderer, surface_text)
	text_rect := SDL.Rect {
		cell.rect.x + ((GRID_SIZE - surface_text.w) / 2),
		cell.rect.y + ((GRID_SIZE - surface_text.h) / 2),
		surface_text.w,
		surface_text.h,
	}
	SDL.RenderCopy(renderer, message_text, nil, &text_rect)
	SDL.FreeSurface(surface_text)
	SDL.DestroyTexture(message_text)
}
