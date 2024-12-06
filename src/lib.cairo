pub mod parser;
pub mod types;
pub mod constants;

pub mod runestone {
    pub mod flag;
    pub mod tag;
    pub mod message;
}

pub mod utils {
    pub mod varint;
    pub mod fields;
    pub mod char;
}

#[cfg(test)]
mod tests {
    mod parser;
    mod opcodes;
    mod cenotaph;
    mod utils;
    mod varint;
    mod flag;
    mod transactions;
}
