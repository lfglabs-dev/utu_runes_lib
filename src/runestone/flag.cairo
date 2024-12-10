use alexandria_math::pow;

#[derive(Drop)]
pub enum Flag {
    Etching,
    Terms,
    Turbo,
    Cenotaph,
}

pub trait FlagTrait {
    fn get(self: Flag) -> u128;
    fn mask(self: Flag) -> u128;
    fn take(self: Flag, ref flags: u128) -> bool;
    fn set(self: Flag, ref flags: u128);
}

impl FlagImpl of FlagTrait {
    fn get(self: Flag) -> u128 {
        match self {
            Flag::Etching => 0,
            Flag::Terms => 1,
            Flag::Turbo => 2,
            Flag::Cenotaph => 127,
        }
    }

    fn mask(self: Flag) -> u128 {
        pow(2_u128, self.get())
    }

    // Takes the flag: Checks if it is set, then clears it
    fn take(self: Flag, ref flags: u128) -> bool {
        let mask = self.mask();

        let is_set = flags & mask != 0;

        // Clear the flag if set
        flags = if is_set {
            flags - mask
        } else {
            flags
        };
        is_set
    }

    fn set(self: Flag, ref flags: u128) {
        let mask = self.mask();
        let divider: NonZero<u128> = mask.try_into().unwrap();
        let (q, _) = DivRem::<u128>::div_rem(flags, divider);

        if q % 2 == 0 {
            flags += mask // Set the flag if not already set
        }
    }
}
