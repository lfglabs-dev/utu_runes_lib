use runes_lib::parser::{extract_runestone};
use runes_lib::types::{Runestone, RuneId, Artifact};
use consensus::types::transaction::{Transaction, TxOut};

fn hex_char_to_nibble(hex_char: u8) -> u8 {
    if hex_char >= 48 && hex_char <= 57 {
        // 0-9
        hex_char - 48
    } else if hex_char >= 65 && hex_char <= 70 {
        // A-F
        hex_char - 55
    } else if hex_char >= 97 && hex_char <= 102 {
        // a-f
        hex_char - 87
    } else {
        panic!("Invalid hex character: {hex_char}");
        0
    }
}


/// Gets bytes from hex (base16).
fn from_hex(hex_string: ByteArray) -> ByteArray {
    let num_characters = hex_string.len();
    assert!(num_characters & 1 == 0, "Invalid hex string length");

    let mut bytes: ByteArray = Default::default();
    let mut i = 0;

    while i != num_characters {
        let hi = hex_char_to_nibble(hex_string[i]);
        let lo = hex_char_to_nibble(hex_string[i + 1]);
        bytes.append_byte(hi * 16 + lo);
        i += 2;
    };

    bytes
}

#[test]
fn test_tx_mint_1() {
    // a795ede3bec4b9095eb207bff4abacdbcdd1de065788d4ffb53b1ea3fe5d67fb
    let outputs: Array<TxOut> = array![
        TxOut { value: 0, pk_script: @from_hex("6a5d0714f6a73514d50d",), cached: false },
        TxOut {
            value: 546,
            pk_script: @from_hex(
                "5120f6c5b32ab6926f66fc96eaf5bcacb968c93317b10700e43e779589ab3e59db2e",
            ),
            cached: false
        },
        TxOut {
            value: 1500,
            pk_script: @from_hex("001452dfd69700e8e1a2a3256799e5b7c30a221f6568",),
            cached: false
        },
        TxOut {
            value: 50419,
            pk_script: @from_hex(
                "5120f63388b3e7360898c655d3fb062654b4dc39f86f0e93649df425770147f03f66",
            ),
            cached: false
        }
    ];

    let tx = Transaction {
        version: 0, inputs: array![].span(), outputs: outputs.into(), lock_time: 0, is_segwit: false
    };

    let values = extract_runestone(tx);
    match values {
        Option::None => { println!("Should not return None"); },
        Option::Some(output) => {
            println!("{:?}", output);
            let expected: Artifact = Artifact::Runestone(
                Runestone {
                    mint: Option::Some(RuneId { block: 873462, tx: 1749 }), ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_tx_mint_2() {
    // 8f47e81d3777d442f45a1984bbc391b951b4808f3ea44e5c35aaa348e95e71e4
    let outputs: Array<TxOut> = array![
        TxOut {
            value: 1596,
            pk_script: @from_hex(
                "5120eb0dfe9f2b5c7744a2497b8c5f8b68e5f6fbd8f3d1d4dfcd208c2ea12b1a61ce",
            ),
            cached: false
        },
        TxOut { value: 0, pk_script: @from_hex("6a5d0714bce43314c101",), cached: false }
    ];

    let tx = Transaction {
        version: 0, inputs: array![].span(), outputs: outputs.into(), lock_time: 0, is_segwit: false
    };

    let values = extract_runestone(tx);
    match values {
        Option::None => { println!("Should not return None"); },
        Option::Some(output) => {
            let expected: Artifact = Artifact::Runestone(
                Runestone {
                    mint: Option::Some(RuneId { block: 848444, tx: 193 }), ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_tx_etching() {
    // 7781853fab708e7dbe2086449fdb6c917bb3ee94b062934d3397cb8b744a44d2
    let outputs: Array<TxOut> = array![
        TxOut {
            value: 546,
            pk_script: @from_hex(
                "51208d50fca97fc75365e648e7b68d4710a3920df6e54086a0a067a128a233140826",
            ),
            cached: false
        },
        TxOut {
            value: 546,
            pk_script: @from_hex(
                "5120f6c5b32ab6926f66fc96eaf5bcacb968c93317b10700e43e779589ab3e59db2e",
            ),
            cached: false
        },
        TxOut {
            value: 546,
            pk_script: @from_hex(
                "51208d50fca97fc75365e648e7b68d4710a3920df6e54086a0a067a128a233140826",
            ),
            cached: false
        },
        TxOut {
            value: 0,
            pk_script: @from_hex(
                "6a5d240207049b8cb7fceeb6fbeae1bbe20b010003884205cc4e0698e3060ae8070881ab011601",
            ),
            cached: false
        }
    ];

    let tx = Transaction {
        version: 0, inputs: array![].span(), outputs: outputs.into(), lock_time: 0, is_segwit: false
    };

    let values = extract_runestone(tx);
    match values {
        Option::None => { println!("Should not return None"); },
        Option::Some(output) => {
            match output {
                Artifact::Runestone(runestone) => {
                    let etching = runestone.etching.unwrap();
                    let terms = etching.terms.unwrap();
                    assert(etching.premine == Option::Some(111000), 'wrong etching value');
                    assert(etching.divisibility == Option::Some(0), 'wrong pointer value');
                    assert(
                        etching.rune == Option::Some(1778522209552757531985435),
                        'wrong etching value'
                    );
                    assert(etching.spacers == Option::Some(8456), 'wrong etching value');
                    assert(terms.amount == Option::Some(1000), 'wrong terms value');
                    assert(terms.cap == Option::Some(21889), 'wrong terms value');
                    assert(
                        terms.height == (Option::None(()), Option::None(())), 'wrong terms value'
                    );
                    assert(
                        terms.offset == (Option::None(()), Option::None(())), 'wrong terms value'
                    );
                    assert(etching.turbo == true, 'wrong etching value');
                    assert(runestone.pointer == Option::Some(1), 'wrong pointer value');
                    assert(runestone.mint.is_none(), 'wrong mint value');
                    assert(runestone.edicts.len() == 0, 'wrong edicts value');
                },
                _ => { panic!("Expected Runestone"); }
            }
        }
    }
}

