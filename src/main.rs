mod core;
mod sdl;

fn main() {
    let mut app = core::App::new();
    app.add_ticker(1);

    app.start_ticker(Box::new(|| {
        println!("tick");
    }));

    let game_window = sdl::context::GameWindowContext::new().init();

    println!(
        "Using SDL renderer: {}",
        game_window.get_info().unwrap().name
    );

    game_window.run_render_loop();
}
