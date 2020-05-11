mod core;
use crate::core::App;

fn main() {
    let mut app = App::new();
    app.add_ticker(1);

    app.start_ticker(& || {
        println!("tick");
    });
}
