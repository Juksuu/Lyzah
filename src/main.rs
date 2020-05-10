mod application;
use application::game::Game;

fn main() {
    let mut game = Game::new();
    game.add_ticker(128);

    game.start_ticker(& || {
        println!("test");
    });
}
