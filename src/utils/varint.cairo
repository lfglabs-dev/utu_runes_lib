use alexandria_math::pow;
use alexandria_data_structures::byte_array_ext::ByteArrayIntoArrayU8;

pub fn decode_integers(payload: ByteArray) -> Result<Array<u128>, ByteArray> {
    let payload : Array<u8> = payload.into();
    let mut integers: Array<u128> = ArrayTrait::new();
    let mut i = 0;
    let mut err: ByteArray = Default::default();

    loop {
        if i == payload.len() {
            break;
        }

        // Decode the integer starting at the current index
        let (integer, length) = match decode_integer(payload.clone(), i) {
            Result::Ok((integer, length)) => (integer, length),
            Result::Err(error) => {
                err = error;
                break;
            }
        };

        // Append the decoded integer to the result array
        integers.append(integer);

        // Move the index forward by the length of the decoded integer
        i += length;
    };

    if err.len() > 0 {
        return Result::Err(err);
    }

    Result::Ok(integers)
}

pub fn decode_integer(buffer: Array<u8>, start: usize) -> Result<(u128, usize), ByteArray> {
    let mut n: u128 = 0;
    let mut length: usize = 0;
    let mut i: usize = 0;
    let mut is_valid: bool = false;

    let mut err: ByteArray = Default::default();

    loop {
        if i >= buffer.len() - start {
            break;
        }

        let byte = buffer[start + i];
        // byte & 0b0111_1111;
        let (_, value) = DivRem::<u128>::div_rem((*byte).into(), 128);

        // Overflow check
        if i > 18 {
            err = "Overlong error";
            break;
        }

        if i == 18 && value & 0b0111_1100 != 0 {
            err = "Overflow error";
            break;
        }

        let shift: u128 = 7_u128 * i.into();
        n += (value.into() * pow(2_u128, shift));

        length += 1;

        // Check if it's the last byte of the varint
        let (q, _) = DivRem::<u128>::div_rem((*byte).into(), 128);
        if q == 0 {
            is_valid = true;
            break;
        }

        i += 1;
    };

    if err.len() > 0 {
        return Result::Err(err);
    }

    if !is_valid {
        return Result::Err("invalid varint");
    }

    Result::Ok((n, length))
}