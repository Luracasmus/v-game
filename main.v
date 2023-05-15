import gg
import gx
import sokol.sapp
import math
import rand

struct Entity {
	mut:
		x int
		y int
}

struct Particle {
	mut:
		x int
		y int
		life f32
		scale f32
		brightness f32
}

struct Point {
	x int
	y int
}

enum Build as u8 {
	orb
	worm
}

enum Limb as u8 {
	tail
	beak
}

struct App {
	mut:
		ctx &gg.Context = unsafe { nil }

		mouse_last struct {
			mut:
				x int
				y int
		}

		cam struct {
			mut:
				x int
				y int
				x_speed f32
				y_speed f32
		}

		player struct {
			mut:
				build Build = .orb
				limbs []Limb
				limb_offset f64
				size int = 15
		}

		click f32
		hold bool

		entities []Entity
		particles []Particle
}

fn lerp32(a f32, b f32, f f32) f32 {
	return a * (1.0 - f) + b * f
}

fn lerp64(a f64, b f64, f f64) f64 {
	return a * (1.0 - f) + b * f
}

fn touch(x1 int, y1 int, x2 int, y2 int, size1 int, size2 int) bool {
	return math.sqrt(math.pow(x1 - x2, 2.0) + math.pow(y1 - y2, 2.0)) < (size1 + size2) / 2
}

fn main() {
	mut app := &App{}

	app.ctx = gg.new_context(
		bg_color: gx.rgb(25, 25, 35)
		window_title: 'Circular'

		frame_fn: frame
		keydown_fn: keydown
		init_fn: init
		click_fn: click
		unclick_fn: unclick

		user_data: app
	)
	app.ctx.run()
}

fn init(mut app App) {
	sapp.show_mouse(false)

	win := app.ctx.window_size()

	for i := 0; i < 5000; i++ {
		app.particles << Particle{
			x: int((rand.f32() - 0.25) * win.width * 2)
			y: int((rand.f32() - 0.25) * win.height * 2)
			life: rand.f32()
			scale: rand.f32()
			brightness: rand.f32()
		}
	}

	for i := 0; i < 3; i++ {
		app.entities << Entity{
			x: int((rand.f32() - 0.25) * win.width * 2) - app.cam.x
			y: int((rand.f32() - 0.25) * win.height * 2) - app.cam.y
		}
	}

	app.player.limbs = [.tail, .tail, .tail, .tail, .tail, .tail, .tail, .tail, .tail, .beak]
}

fn keydown(c gg.KeyCode, _ gg.Modifier, mut app App) {
	if c == gg.KeyCode.f11 {
		gg.toggle_fullscreen()
	}
}

fn click(x f32, y f32, _ gg.MouseButton, mut app App) {
	app.hold = true
	app.click = 1
}

fn unclick(_ f32, _ f32, _ gg.MouseButton, mut app App) {
	app.hold = false
}

fn frame(mut app App) {
	ctx := &app.ctx

	ctx.begin()

	frame_time := f32(sapp.frame_duration())
	mouse_x := ctx.mouse_pos_x
	mouse_y := ctx.mouse_pos_y
	width := ctx.window_size().width
	height := ctx.window_size().height

	// Input
		if ctx.pressed_keys[int(gg.KeyCode.w)] {
			app.cam.y_speed = lerp32(app.cam.y_speed, 2.1, f32(math.min(1.0, 10 * frame_time)))
		} else if !ctx.pressed_keys[int(gg.KeyCode.s)] {
			app.cam.y_speed *= 0.9
		}

		if ctx.pressed_keys[int(gg.KeyCode.s)] {
			app.cam.y_speed = lerp32(app.cam.y_speed, -2.1, f32(math.min(1.0, 10 * frame_time)))
		} else if !ctx.pressed_keys[int(gg.KeyCode.w)] {
			app.cam.y_speed *= 0.9
		}

		if ctx.pressed_keys[int(gg.KeyCode.a)] {
			app.cam.x_speed = lerp32(app.cam.x_speed, 2.1, f32(math.min(1.0, 10 * frame_time)))
		} else if !ctx.pressed_keys[int(gg.KeyCode.d)] {
			app.cam.x_speed *= 0.9
		}

		if ctx.pressed_keys[int(gg.KeyCode.d)] {
			app.cam.x_speed = lerp32(app.cam.x_speed, -2.1, f32(math.min(1.0, 10 * frame_time)))
		} else if !ctx.pressed_keys[int(gg.KeyCode.a)] {
			app.cam.x_speed *= 0.9
		}

		app.cam.x += int(app.cam.x_speed)
		app.cam.y += int(app.cam.y_speed)

	world_speed := math.sqrt(math.pow(app.cam.x_speed, 2.0) + math.pow(app.cam.y_speed, 2.0))

	// Cursor
		movement := math.abs(mouse_x - app.mouse_last.x) + math.abs(mouse_y - app.mouse_last.y)
		mouse_size := math.min(width, height) / 20 - movement / 8 - app.click * 25

		ctx.draw_circle_empty(mouse_x, mouse_y, mouse_size, gx.light_blue)

		if !app.hold {
			app.click = lerp32(app.click, 0, f32(math.min(1.0, 10 * frame_time)))
		} else {
			app.click = lerp32(app.click, 0.25, f32(math.min(1.0, 10 * frame_time)))
		}

		app.mouse_last.x = (app.mouse_last.x * 3 + mouse_x) / 4
		app.mouse_last.y = (app.mouse_last.y * 3 + mouse_y) / 4

		/*
			for i := 0; i < 5; i++ {
				rotation := math.radians(i * 360 / 10)
				pos_x := f32(mouse_x + app.click * 2 * math.sin(rotation))
				pos_y := f32(mouse_y + app.click * 2 * math.cos(rotation))

				ctx.draw_circle_empty(pos_x, pos_y, math.min(width, height) / 30, gx.light_blue)
			}
		*/
	// Character
		mut plr := &app.player

		ctx.draw_circle_empty(width / 2, height / 2, math.min(width, height) / (30 - plr.size), gx.light_blue)

		for i, limb in plr.limbs {
			plr.limb_offset = lerp64(plr.limb_offset, math.min(width, height) / (5 + world_speed), math.min(1.0, 0.1 * frame_time))
			rotation := math.radians(math.fmod(f64(ctx.frame) * frame_time * 25 - plr.limb_offset, 360) + i * 360 / plr.limbs.len)
			pos_x := int(width / 2 + plr.limb_offset * math.sin(rotation))
			pos_y := int(height / 2 + plr.limb_offset * math.cos(rotation))

			match limb {
				.tail {
					if app.hold == true && touch(pos_x, pos_y, mouse_x, mouse_y, math.min(width, height) / 30, int(mouse_size)) {
						ctx.draw_circle_filled(pos_x, pos_y, math.min(width, height) / 30, gx.light_blue)
					} else {
						ctx.draw_circle_empty(pos_x, pos_y, math.min(width, height) / 30, gx.light_blue)
					}
				}
				.beak {
					if app.hold == true && touch(pos_x, pos_y, mouse_x, mouse_y, math.min(width, height) / 30, int(mouse_size)) {
						ctx.draw_circle_filled(pos_x, pos_y, math.min(width, height) / 25, gx.red)
					} else {
						ctx.draw_circle_empty(pos_x, pos_y, math.min(width, height) / 25, gx.red)
					}
				}
			}
		}

	// Entities
		for mut entity in app.entities {
			if entity.x + app.cam.x - width / 2 > (width * 4)^2 || entity.y + app.cam.y - height / 2 > (height * 4)^2 {
				entity.x = int((rand.f32() - 0.25) * width * 2) - app.cam.x
				entity.y = int((rand.f32() - 0.25) * height * 2) - app.cam.y
			}

			ctx.draw_circle_empty(entity.x + app.cam.x, entity.y + app.cam.y, math.min(width, height) / 25, gx.red)
		}

	// Particles
		speed := 30 * frame_time

		for mut particle in app.particles {
			if particle.life > 0 {
				size := particle.scale * math.min(width, height) / 40 * (1 - particle.life)
				ctx.draw_circle_empty(particle.x + app.cam.x, particle.y + app.cam.y, size, gx.rgb(u8(particle.brightness * particle.life * 148 + 25), u8(particle.brightness * particle.life * 191 + 25), u8(particle.brightness * particle.life * 195 + 35)))
				particle.life -= 0.125 * frame_time
			} else {
				particle.x = int((rand.f32() - 0.25) * width * 2) - app.cam.x
				particle.y = int((rand.f32() - 0.25) * height * 2) - app.cam.y
				particle.life = 1
				particle.scale = rand.f32()
				particle.brightness = rand.f32()
			}

			mouse_x_dist := f32(particle.x - mouse_x + app.cam.x) / width
			mouse_y_dist := f32(particle.y - mouse_y + app.cam.y) / height
			mouse_dist := math.pow(1 + math.sqrt(mouse_x_dist * mouse_x_dist + mouse_y_dist * mouse_y_dist) - app.click / 20, 16.0)

			plr_x_dist := f32(particle.x - width / 2 + app.cam.x) / width
			plr_y_dist := f32(particle.y - height / 2 + app.cam.y) / height
			plr_dist := math.pow(1 + math.sqrt(plr_x_dist * plr_x_dist + plr_y_dist * plr_y_dist) - world_speed / 50, 16.0)

			particle.x += int(rand.f32() * 2 - 1 + width * speed * (
				math.clamp(mouse_x_dist, -0.01, 0.01) / mouse_dist * (app.click + 1) +
				math.clamp(plr_x_dist, -0.01, 0.01) / plr_dist
			))

			particle.y += int(rand.f32() * 2 - 1 + height * speed * (
				math.clamp(mouse_y_dist, -0.01, 0.01) / mouse_dist * (app.click + 1) +
				math.clamp(plr_y_dist, -0.01, 0.01) / plr_dist
			))
		}

	ctx.end()
}