use runes_lib::parser::{extract_runestone};
use runes_lib::types::{Runestone, RuneId, Artifact};
use consensus::types::transaction::{Transaction, TxOut, TxIn, OutPoint};
use utils::hex::{from_hex, hex_to_hash_rev};

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
        version: 2, inputs: array![].span(), outputs: outputs.into(), lock_time: 0, is_segwit: false
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
        version: 2, inputs: array![].span(), outputs: outputs.into(), lock_time: 0, is_segwit: false
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
        version: 2, inputs: array![].span(), outputs: outputs.into(), lock_time: 0, is_segwit: false
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

#[test]
fn test_tx_send() {
    // 34c0a5f659aadc9da4fc87b8b2179174979f9297a1b9d8a51d295b5ea9ccf878
    let outputs: Array<TxOut> = array![
        TxOut {
            value: 2121,
            pk_script: @from_hex(
                "512079a2aa2c82cd13dadc5e3c38338406b291a2c26c39feb5a65f08e498535c4109",
            ),
            cached: false
        },
        TxOut { value: 0, pk_script: @from_hex("6a5d0714c0a23314b802",), cached: false },
    ];

    let inputs: Array<TxIn> = array![
        TxIn {
            previous_output: OutPoint {
                txid: hex_to_hash_rev(
                    "3f6c165571e4202c2c2b67577a725b09bb0c2cc92d53e87596b0a74de4606e2f"
                ),
                vout: 0,
                block_height: 873484,
                median_time_past: 1733472864,
                is_coinbase: false,
                data: TxOut {
                    value: 1596,
                    pk_script: @from_hex(
                        "512079a2aa2c82cd13dadc5e3c38338406b291a2c26c39feb5a65f08e498535c4109",
                    ),
                    cached: false
                },
            },
            script: Default::default(),
            sequence: 4294967295,
            witness: array![
                from_hex(
                    "b2d374d3f0ec5018dcf7121cdfa11ba9e3a8f8a57f93d911ee3005747c779f6ce4929bac2cd65dcecc2d42636ae9edc5a2eb5967b37845db9172924091ee4ed8"
                )
            ]
                .span()
        }
    ];

    let tx = Transaction {
        version: 2, inputs: inputs.span(), outputs: outputs.into(), lock_time: 0, is_segwit: false
    };

    let values = extract_runestone(tx);
    match values {
        Option::None => { println!("Should not return None"); },
        Option::Some(output) => { println!("output: {:?}", output); }
    }
}

