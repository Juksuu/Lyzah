use std::thread;
use std::time::Duration;
use crossbeam::channel;

pub struct App {
    ticker: Option<Ticker>,
}

impl App {
    pub fn new() -> App {
        App {
            ticker: None,
        }
    }

    pub fn add_ticker(&mut self, tick_rate: u64) {
        self.ticker = Some(Ticker::new(tick_rate));
    }

    pub fn start_ticker(self, game_loop: &dyn Fn()) {
        match self.ticker {
            Some(ticker) => ticker.run(game_loop),
            None => println!("Ticker not instantiated")
        }
    }
}

struct Ticker {
    tickrate: u64
}

impl Ticker {
    pub fn new(tick_rate: u64) -> Ticker {
        Ticker {
            tickrate: tick_rate
        }
    }

    pub fn run(self, game_loop: &dyn Fn()) {
        let (tick_tx, tick_rx) = channel::bounded(0);
        let ms = 1000 / self.tickrate;

        thread::spawn(move || {
            loop {
                thread::sleep(Duration::from_millis(ms));
                tick_tx.send("tick").unwrap();
            }
        });

        loop {
            channel::select! {
                // default => {
                //     println!("update");
                // },
                recv(tick_rx) -> _msg => game_loop()
            }
        }
    }
}
