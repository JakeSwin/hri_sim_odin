package hri

import "core:fmt"
import mu "vendor:microui"
import SDL "vendor:sdl2"

ui_draw :: proc(using app: ^App) {
	render_texture :: proc(using app: ^App, dst: ^SDL.Rect, src: mu.Rect, color: mu.Color) {
		dst.w = src.w
		dst.h = src.h
		
		SDL.SetTextureAlphaMod(atlas_texture, color.a)
		SDL.SetTextureColorMod(atlas_texture, color.r, color.g, color.b)
		SDL.RenderCopy(renderer, atlas_texture, &SDL.Rect{src.x, src.y, src.w, src.h}, dst)
	}
	
	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(mu_ctx, &command_backing) {
		switch cmd in variant {
		case ^mu.Command_Text:
			dst := SDL.Rect{cmd.pos.x, cmd.pos.y, 0, 0}
			for ch in cmd.str do if ch&0xc0 != 0x80 {
				r := min(int(ch), 127)
				src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
				render_texture(app, &dst, src, cmd.color)
				dst.x += dst.w
			}
		case ^mu.Command_Rect:
			SDL.SetRenderDrawColor(renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
			SDL.RenderFillRect(renderer, &SDL.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h})
		case ^mu.Command_Icon:
			src := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - src.w)/2
			y := cmd.rect.y + (cmd.rect.h - src.h)/2
			render_texture(app, &SDL.Rect{x, y, 0, 0}, src, cmd.color)
		case ^mu.Command_Clip:
			SDL.RenderSetClipRect(renderer, &SDL.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h})
		case ^mu.Command_Jump: 
			unreachable()
		}
	}
}

slider :: proc(ctx: ^mu.Context, val: ^f32, lo, hi: f32) -> (res: mu.Result_Set) {
	mu.push_id(ctx, rawptr(val), 32)
	
	@static tmp: mu.Real
	tmp = mu.Real(val^)
	res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0.5, "%.1f", {.ALIGN_CENTER})
	val^ = f32(tmp)
	mu.pop_id(ctx)
	return
}

// TODO change this to make nicer
change_row_or_col :: proc(val: ^u32, amount: i32) {
	new_val := i32(val^) + amount
	if new_val >= 2 && new_val <= 15 {
		val^ = u32(new_val)
	}
}

ui_all_windows :: proc(using app: ^App) {
	@static opts := mu.Options{.NO_CLOSE}

    if mu.window(mu_ctx, "Simulation Options", {20, 20, 300, 400}, opts) {
		mu.layout_row(mu_ctx, {100, -50})
		mu.label(mu_ctx, "Reset Simulation")
		if .SUBMIT in mu.button(mu_ctx, "Reset") { 
			if app.simulation != nil {
				sim_destroy(app.simulation)
				app.simulation = sim_create(app.tmp_rows, app.tmp_cols)
			}
		}
		mu.layout_row(mu_ctx, {100, 50, 20, 50})
		mu.label(mu_ctx, "Simulation Rows")
		if .SUBMIT in mu.button(mu_ctx, "-1 rows") { change_row_or_col(&app.tmp_rows, -1) }
		mu.label(mu_ctx, fmt.tprintf("%d", app.tmp_rows))
		if .SUBMIT in mu.button(mu_ctx, "+1 rows") { change_row_or_col(&app.tmp_rows, 1) }
		mu.label(mu_ctx, "Simulation Cols")
		if .SUBMIT in mu.button(mu_ctx, "-1 cols") { change_row_or_col(&app.tmp_cols, -1) }
		mu.label(mu_ctx, fmt.tprintf("%d", app.tmp_cols))
		if .SUBMIT in mu.button(mu_ctx, "+1 cols") { change_row_or_col(&app.tmp_cols, 1) }
		mu.layout_row(mu_ctx, {100, 100})
		if .CHANGE in mu.checkbox(mu_ctx, "Show Utility", &app.show_utility) {
			if app.show_utility {
				app.show_policy = false
			}
		}
		if .CHANGE in mu.checkbox(mu_ctx, "Show Policy", &app.show_policy) {
			if app.show_policy {
				app.show_utility = false
			}
		}
		if .ACTIVE in mu.header(mu_ctx, "Tool Options") {
			mu.layout_row(mu_ctx, {92, 92, 92}, 0)
			for tool in Tool {
				state := current_tool == tool
				if .CHANGE in mu.checkbox(mu_ctx, fmt.tprintf("%v", tool), &state) {
					if state {
						current_tool = tool
					} else {
						current_tool = .NONE
					}
				}
			}
			if current_tool == .SET_REWARD {
				mu.layout_row(mu_ctx, {92, 92}, 0)
				mu.label(mu_ctx, "Reward Amount")
				slider(mu_ctx, &app.reward_add, -5, 5)
			}
		}
		if .ACTIVE in mu.header(mu_ctx, "Move Agent") {
			mu.layout_row(mu_ctx, {100, 100}, 0)
			if .SUBMIT in mu.button(mu_ctx, "Move Left") { sim_move_agent(app.simulation, .LEFT) }
			if .SUBMIT in mu.button(mu_ctx, "Move Right") { sim_move_agent(app.simulation, .RIGHT) }
			if .SUBMIT in mu.button(mu_ctx, "Move Up") { sim_move_agent(app.simulation, .UP) }
			if .SUBMIT in mu.button(mu_ctx, "Move Down") { sim_move_agent(app.simulation, .DOWN) }
			mu.label(mu_ctx, "Start Playing")
			if .SUBMIT in mu.button(mu_ctx, "Play") { playing = true }
		}
	}
}