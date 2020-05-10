pub struct Game {
    ticker: Option<Ticker>,
}

impl Game {
    pub fn new() -> Game {
        Game {
            ticker: None,
        }
    }

    pub fn add_ticker(&mut self, tick_rate: u8) {
        self.ticker = Some(Ticker::new(tick_rate));
    }

    pub fn start_ticker(self, game_loop: &dyn Fn()) {
        match self.ticker {
            Some(mut ticker) => ticker.run(game_loop),
            None => println!("Ticker not instantiated")
        }
    }
}

struct Ticker {
    tickrate: u8
}

impl Ticker {
    pub fn new(tickRate: u8) -> Ticker {
        Ticker {
            tickrate: tickRate
        }
    }

    pub fn run(&mut self, game_loop: &dyn Fn()) {
        game_loop();
    }
}
