mod application;
use application::game::Game;

fn main() {
    let mut game = Game::new();
    game.add_ticker(1);

    game.start_ticker(& || {
        println!("tick");
    });
}
