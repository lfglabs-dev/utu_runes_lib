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

        let is_set = bitwise_and(flags, mask) != 0;

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


fn bitwise_and(a: u128, b: u128) -> u128 {
    let mut result: u128 = 0;
    let mut bit_position: u128 = 1; // Start at 2^0
    let mut i: usize = 0;

    loop {
        if i == 128 {
            break;
        }

        // Perform bitwise AND for the current bit position
        let bit_a = a & bit_position;
        let bit_b = b & bit_position;

        if bit_a != 0 && bit_b != 0 {
            result += bit_position;
        }

        if bit_position > 340282366920938463463374607431768211455 / 2 {
            break;
        }

        // Update bit_position to the next power of 2
        bit_position *= 2;
        i += 1;
    };

    result
}
