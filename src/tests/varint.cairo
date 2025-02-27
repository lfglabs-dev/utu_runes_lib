use runes_lib::utils::varint::{decode_integer, decode_integers};
use alexandria_math::pow;
use alexandria_data_structures::byte_array_ext::SpanU8IntoBytearray;

fn encode_to_vec(mut n: u128) -> Array<u8> {
    let mut result: Array<u8> = Default::default();

    loop {
        // Extract the lower 7 bits of `n`
        let (q, r) = DivRem::<u128>::div_rem(n, 128);
        let value: u8 = r.try_into().unwrap();

        if q > 0 {
            // Add the lower 7 bits with the MSB set (0b1000_0000)
            result.append(value + 128_u8);
            n = q;
        } else {
            // Add the last byte without setting the MSB
            result.append(value);
            break;
        }
    };

    result
}

// gas: ~2
#[test]
fn test_zero_round_trips_successfully() {
    let n = 0;
    let encoded: Array<u8> = array![0];
    let (decoded, length) = match decode_integer(encoded.clone(), 0) {
        Result::Ok((integer, length)) => (integer, length),
        Result::Err(error) => panic!("Error: {:?}", error),
    };
    assert_eq!(decoded, n);
    assert_eq!(length, encoded.len());
}

// gas: ~113
#[test]
fn test_u128_max_round_trips_successfully() {
    let n = 340282366920938463463374607431768211455;
    let encoded = array![
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 3
    ];
    let (decoded, length) = match decode_integer(encoded.clone(), 0) {
        Result::Ok((integer, length)) => (integer, length),
        Result::Err(error) => panic!("Error: {:?}", error),
    };
    assert_eq!(decoded, n);
    assert_eq!(length, encoded.len());
}

// gas: ~7364
#[test]
fn test_powers_of_two_round_trip_successfully() {
    let mut i = 0;

    loop {
        let n = pow(2_u128, i);
        let encoded: Array<u8> = encode_to_vec(n);
        let (decoded, length) = match decode_integer(encoded.clone(), 0) {
            Result::Ok((integer, length)) => (integer, length),
            Result::Err(error) => panic!("Error: {:?}", error),
        };
        assert_eq!(decoded, n);
        assert_eq!(length, encoded.len());

        i += 1;

        if i == 128 {
            break;
        }
    };
}

// gas: ~6737
#[test]
fn test_alternating_bit_strings_round_trip_successfully() {
    let mut i = 0;
    let mut n = 0;

    loop {
        let shifted_n = n * 2_u128;
        n = shifted_n + (i % 2);

        let encoded = encode_to_vec(n);
        let (decoded, length) = match decode_integer(encoded.clone(), 0) {
            Result::Ok((integer, length)) => (integer, length),
            Result::Err(error) => panic!("Error: {:?}", error),
        };
        assert_eq!(decoded, n);
        assert_eq!(length, encoded.len());

        i += 1;

        if i == 128 {
            break;
        }
    };
}

// gas: ~113
#[test]
fn test_varints_may_not_be_longer_than_19_bytes() {
    let VALID: Array<u8> = array![
        128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 0,
    ];

    let (decoded, length) = match decode_integer(VALID.clone(), 0) {
        Result::Ok((integer, length)) => (integer, length),
        Result::Err(error) => panic!("Error: {:?}", error),
    };
    assert_eq!(decoded, 0);
    assert_eq!(length, 19);
}

// gas: ~114
#[test]
#[should_panic(expected: "Overlong error")]
fn test_varints_may_not_be_longer_than_19_bytes_fails() {
    let INVALID: Array<u8> = array![
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        0,
    ];
    match decode_integer(INVALID.clone(), 0) {
        Result::Ok(_) => {},
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

// gas: ~106
#[test]
#[should_panic(expected: "Overflow error")]
fn test_varints_may_not_overflow_u128_fails_1() {
    let INVALID: Array<u8> = array![
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        64,
    ];
    match decode_integer(INVALID.clone(), 0) {
        Result::Ok(_) => {},
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

// gas: ~106
#[test]
#[should_panic(expected: "Overflow error")]
fn test_varints_may_not_overflow_u128_fails_2() {
    let INVALID: Array<u8> = array![
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        32,
    ];
    match decode_integer(INVALID.clone(), 0) {
        Result::Ok(_) => {},
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

#[test]
#[should_panic(expected: "Overflow error")]
fn test_varints_may_not_overflow_u128_fails_3() {
    let INVALID: Array<u8> = array![
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        128,
        16,
    ];
    match decode_integer(INVALID.clone(), 0) {
        Result::Ok(_) => {},
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

#[test]
#[should_panic(expected: "Overflow error")]
fn test_varints_may_not_overflow_u128_fails_4() {
    let INVALID: Array<u8> = array![
        128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 8,
    ];
    match decode_integer(INVALID.clone(), 0) {
        Result::Ok(_) => {},
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

#[test]
#[should_panic(expected: "Overflow error")]
fn test_varints_may_not_overflow_u128_fails_5() {
    let INVALID: Array<u8> = array![
        128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 4,
    ];
    match decode_integer(INVALID.clone(), 0) {
        Result::Ok(_) => {},
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

// gas: ~119
#[test]
fn test_varints_may_not_overflow_u128() {
    let VALID: Array<u8> = array![
        128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 2,
    ];
    let (decoded, length) = match decode_integer(VALID.clone(), 0) {
        Result::Ok((integer, length)) => (integer, length),
        Result::Err(error) => panic!("Error: {:?}", error),
    };
    let expected = pow(2_u128, 127);
    assert_eq!(decoded, expected);
    assert_eq!(length, 19);
}

#[test]
#[should_panic(expected: "invalid varint")]
fn test_varints_must_be_terminated() {
    let data: Array<u8> = array![128];
    match decode_integer(data.clone(), 0) {
        Result::Ok(_) => {},
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

// gas: ~37
#[test]
fn test_decode_integers_tx_mint() {
    let payload_u8: Array<u8> = array![20, 188, 228, 51, 20, 193, 1];
    let payload: ByteArray = payload_u8.span().into();
    let expected_integers: Array<u128> = array![20, 848444, 20, 193];
    match decode_integers(payload) {
        Result::Ok(res) => { assert_eq!(res, expected_integers); },
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}

// gas: ~226
#[test]
fn test_decode_integers_tx_etching() {
    let payload_u8: Array<u8> = array![
        2,
        7,
        4,
        155,
        140,
        183,
        252,
        238,
        182,
        251,
        234,
        225,
        187,
        226,
        11,
        1,
        0,
        3,
        136,
        66,
        5,
        204,
        78,
        6,
        152,
        227,
        6,
        10,
        232,
        7,
        8,
        129,
        171,
        1,
        22,
        1
    ];
    let payload: ByteArray = payload_u8.span().into();
    let expected_integers: Array<u128> = array![
        2,
        7,
        4,
        1778522209552757531985435,
        1,
        0,
        3,
        8456,
        5,
        10060,
        6,
        111000,
        10,
        1000,
        8,
        21889,
        22,
        1
    ];
    match decode_integers(payload) {
        Result::Ok(res) => { assert_eq!(res, expected_integers); },
        Result::Err(error) => panic!("Error: {:?}", error),
    };
}
