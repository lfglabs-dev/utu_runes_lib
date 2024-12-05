use core::num::traits::CheckedSub;
use core::num::traits::CheckedAdd;

#[derive(Copy, Drop, Default, PartialEq, Debug)]
pub struct RuneId {
    pub block: u64,
    pub tx: u32,
}

#[derive(Copy, Drop, PartialEq, Default, Debug)]
pub struct Edict {
    pub id: RuneId,
    pub amount: u128,
    pub output: u32,
}

#[derive(Copy, Drop, PartialEq, Default, Debug)]
pub struct Terms {
    pub amount: Option<u128>,
    pub cap: Option<u128>,
    pub height: (Option<u64>, Option<u64>),
    pub offset: (Option<u64>, Option<u64>),
}

#[derive(Drop, PartialEq, Default, Debug)]
pub struct Etching {
    pub divisibility: Option<u8>,
    pub premine: Option<u128>,
    pub rune: Option<u128>,
    pub spacers: Option<u32>,
    pub symbol: Option<ByteArray>,
    pub terms: Option<Terms>,
    pub turbo: bool,
}

#[derive(Default, Drop, PartialEq, Debug)]
pub struct Runestone {
    pub edicts: Array<Edict>,
    pub etching: Option<Etching>,
    pub mint: Option<RuneId>,
    pub pointer: Option<u32>,
}

#[derive(Default, Drop, PartialEq, Debug)]
pub struct Cenotaph {
    pub etching: Option<u128>,
    pub flaw: Option<ByteArray>,
    pub mint: Option<RuneId>,
}

#[derive(Drop, PartialEq, Debug)]
pub enum Artifact {
    Cenotaph: Cenotaph,
    Runestone: Runestone,
}

#[derive(Debug, PartialEq)]
pub enum Payload {
    Valid: ByteArray,
    Invalid: ByteArray
}

pub trait Rune {
    fn new(block: u64, tx: u32) -> Option<RuneId>;
    fn delta(self: RuneId, next: RuneId) -> Option<(u128, u128)>;
    fn next(self: RuneId, block: u128, tx: u128) -> Option<RuneId>;
}

impl RuneImpl of Rune {
    fn new(block: u64, tx: u32) -> Option<RuneId> {
        let id = RuneId { block, tx, };

        if id.block == 0 && id.tx > 0 {
            return Option::None;
        }

        Option::Some(id)
    }

    fn delta(self: RuneId, next: RuneId) -> Option<(u128, u128)> {
        let block = match next.block.checked_sub(self.block) {
            Option::None => { return Option::None; },
            Option::Some(b) => b,
        };

        let tx = if block == 0 {
            match next.tx.checked_sub(self.tx) {
                Option::None => { return Option::None; },
                Option::Some(t) => t,
            }
        } else {
            next.tx
        };

        return Option::Some((block.into(), tx.into()));
    }

    fn next(self: RuneId, block: u128, tx: u128) -> Option<RuneId> {
        let block: u64 = match self.block.checked_add(block.try_into()?) {
            Option::None => { return Option::None; },
            Option::Some(b) => b,
        };

        let tx: u32 = if block == 0 {
            match self.tx.checked_add(tx.try_into()?) {
                Option::None => { return Option::None; },
                Option::Some(t) => t.try_into()?,
            }
        } else {
            tx.try_into()?
        };

        return Self::new(block, tx);
    }
}

