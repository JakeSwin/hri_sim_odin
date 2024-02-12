package hri

import "core:fmt"
import mu "vendor:microui"
import SDL "vendor:sdl2"
import "vendor:sdl2/image"
import "vendor:sdl2/ttf"

Tool :: enum {
	NONE,
	CLEAR,
	ADD_AGENT,
	ADD_WALL,
	SET_REWARD,
}

State :: struct {
	tmp_rows:      u32,
	tmp_cols:      u32,
	mouse_pos_x:   i32,
	mouse_pos_y:   i32,
	show_utility:  bool,
	show_policy:   bool,
	textures:      map[cstring]^SDL.Texture,
	current_tool:  Tool,
	mouse_down:    bool,
	playing:       bool,
	max_rounds:    u32,
	current_round: u32,
	reward_add:    f32,
}

App :: struct {
	mu_ctx:        ^mu.Context,
	window:        ^SDL.Window,
	renderer:      ^SDL.Renderer,
	atlas_texture: ^SDL.Texture,
	simulation:    ^Simulation,
	viewport:      SDL.Rect,
	using state:   State,
	is_running:    bool,
}

font: ^ttf.Font

app_create :: proc() -> (App, bool) {
	if err := SDL.Init({.VIDEO}); err != 0 {
		fmt.eprintln("Initialising Video: ", err)
		return App{}, false
	}

	window := SDL.CreateWindow(
		"Human Robot Interaction Simulation",
		SDL.WINDOWPOS_UNDEFINED,
		SDL.WINDOWPOS_UNDEFINED,
		1440,
		810,
		{.SHOWN, .RESIZABLE},
	)
	if window == nil {
		fmt.eprintln("Creating Window: ", SDL.GetError())
		return App{}, false
	}

	renderer := SDL.CreateRenderer(window, -1, {.ACCELERATED, .PRESENTVSYNC})
	if renderer == nil {
		fmt.eprintln("Creating Renderer: ", SDL.GetError())
		return App{}, false
	}

	if err := ttf.Init(); err != 0 {
		fmt.eprintln("Initialising Font: ", SDL.GetError())
		return App{}, false
	}

	if image.Init(image.InitFlags{.PNG}) == nil {
		fmt.eprintln("Unable to Initialise SDL Image: ", SDL.GetError())
		return App{}, false
	}

	atlas_texture := SDL.CreateTexture(
		renderer,
		u32(SDL.PixelFormatEnum.RGBA32),
		.TARGET,
		mu.DEFAULT_ATLAS_WIDTH,
		mu.DEFAULT_ATLAS_HEIGHT,
	)
	assert(atlas_texture != nil)
	if err := SDL.SetTextureBlendMode(atlas_texture, .BLEND); err != 0 {
		fmt.eprintln("Setting Texture Blend Mode: ", SDL.GetError())
		return App{}, false
	}

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
	for alpha, i in mu.default_atlas_alpha {
		pixels[i].rgb = 0xff
		pixels[i].a = alpha
	}

	if err := SDL.UpdateTexture(atlas_texture, nil, raw_data(pixels), 4 * mu.DEFAULT_ATLAS_WIDTH);
	   err != 0 {
		fmt.println("Update Texture :", SDL.GetError())
		return App{}, false
	}

	mu_ctx := new(mu.Context)
	mu.init(mu_ctx)

	mu_ctx.text_width = mu.default_atlas_text_width
	mu_ctx.text_height = mu.default_atlas_text_height

	sim := sim_create(5, 10)
	sim.agent = agent_create(0, 0)
	sim_add_wall(sim, 2, 2)
	sim_add_wall(sim, 2, 3)

	font = ttf.OpenFont("assets\\Roboto-Regular.ttf", 20)

	state: State
	state.tmp_rows = 5
	state.tmp_cols = 10
	state.max_rounds = 15

	return App{mu_ctx, window, renderer, atlas_texture, sim, SDL.Rect{}, state, true}, true
}

app_run_loop :: proc(using app: ^App) {
	for is_running {
		app_process_input(app)
		app_update_state(app)
		app_render(app)
	}
}

app_process_input :: proc(using app: ^App) {
	e: SDL.Event
	for SDL.PollEvent(&e) != false {
		#partial switch e.type {
		case .QUIT:
			is_running = false
		case .MOUSEMOTION:
			mu.input_mouse_move(mu_ctx, e.motion.x, e.motion.y)
			mouse_pos_x = e.motion.x
			mouse_pos_y = e.motion.y
		case .MOUSEWHEEL:
			mu.input_scroll(mu_ctx, e.wheel.x * 30, e.wheel.y * -30)
		case .TEXTINPUT:
			mu.input_text(mu_ctx, string(cstring(&e.text.text[0])))

		case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP:
			fn := mu.input_mouse_down if e.type == .MOUSEBUTTONDOWN else mu.input_mouse_up
			mouse_down = true if e.type == .MOUSEBUTTONDOWN else false
			switch e.button.button {
			case SDL.BUTTON_LEFT:
				fn(mu_ctx, e.button.x, e.button.y, .LEFT)
			case SDL.BUTTON_MIDDLE:
				fn(mu_ctx, e.button.x, e.button.y, .MIDDLE)
			case SDL.BUTTON_RIGHT:
				fn(mu_ctx, e.button.x, e.button.y, .RIGHT)
			}

		case .KEYDOWN, .KEYUP:
			if e.type == .KEYUP && e.key.keysym.sym == .ESCAPE {
				SDL.PushEvent(&SDL.Event{type = .QUIT})
			}

			fn := mu.input_key_down if e.type == .KEYDOWN else mu.input_key_up

			#partial switch e.key.keysym.sym {
			case .LSHIFT:
				fn(mu_ctx, .SHIFT)
			case .RSHIFT:
				fn(mu_ctx, .SHIFT)
			case .LCTRL:
				fn(mu_ctx, .CTRL)
			case .RCTRL:
				fn(mu_ctx, .CTRL)
			case .LALT:
				fn(mu_ctx, .ALT)
			case .RALT:
				fn(mu_ctx, .ALT)
			case .RETURN:
				fn(mu_ctx, .RETURN)
			case .KP_ENTER:
				fn(mu_ctx, .RETURN)
			case .BACKSPACE:
				fn(mu_ctx, .BACKSPACE)
			}
		}
	}
}

// Add code for mouse hover over grid square here
// Update the state of the grid array
// When mouse butten is also pressed under grid square then add currently selected element to that square
app_update_state :: proc(using app: ^App) {
	mu.begin(mu_ctx)
	ui_all_windows(app)
	mu.end(mu_ctx)
	sim_update(app)
}

app_render :: proc(using app: ^App) {
	// Changes render size based on window size, for resizable window
	SDL.GetRendererOutputSize(renderer, &app.viewport.w, &app.viewport.h)
	SDL.RenderSetViewport(renderer, &app.viewport)
	SDL.RenderSetClipRect(renderer, &app.viewport)
	SDL.SetRenderDrawColor(renderer, 23, 122, 244, 255)
	SDL.RenderClear(renderer)

	sim_draw(app)
	ui_draw(app)

	SDL.RenderPresent(renderer)
}


app_load_texture :: proc(using app: ^App, filename: cstring) -> ^SDL.Texture {
	surface := image.Load(filename)
	defer SDL.FreeSurface(surface)
	if surface == nil {
		fmt.println("Failed to load texture file: ", SDL.GetError())
		return nil
	}

	texture := SDL.CreateTextureFromSurface(renderer, surface)
	if texture == nil {
		fmt.println("Failed to convert surface to texture for ", filename)
		return nil
	}

	return texture
}

app_get_texture :: proc(using app: ^App, filename: cstring) -> ^SDL.Texture {
	if texture, ok := textures[filename]; ok {
		return texture
	}
	texture := app_load_texture(app, filename)
	textures[filename] = texture
	return texture
}
