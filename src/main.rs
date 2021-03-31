mod core;
mod sdl;

fn main() {
    let mut app = core::App::new();
    app.add_ticker(1);

    // app.start_ticker(& || {
    //     println!("tick");
    // });

    let game_window = sdl::GameWindowContext::new().init();
    game_window.run_loop();
}
