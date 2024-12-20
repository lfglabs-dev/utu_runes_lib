use runes_lib::parser::{extract_runestone};
use runes_lib::constants::{OP_RETURN, OP_13, ETCHING_MAX_DIVISIBILITY};
use runes_lib::types::{Runestone, RuneId, Edict, Artifact, Etching, Terms};
use runes_lib::runestone::{tag::{Tag, TagTrait}, flag::{Flag, FlagTrait}};
use super::utils::{
    append_string, append_arr, transaction, OP_PUSHBYTES_4, OP_PUSHBYTES_9, MINT, U128_MAX
};

#[test]
fn test_decipher_returns_none_if_first_opcode_is_malformed() {
    // Create a transaction with an OP_PUSHBYTES_4 output containing encoded values
    let mut op_return_script: ByteArray = "4";

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);
    assert(values.is_none(), 'values found');
}

#[test]
fn test_deciphering_transaction_with_no_outputs_returns_none() {
    let tx = transaction(array![].span());
    let values = extract_runestone(tx);
    assert(values.is_none(), 'values found');
}

#[test]
fn test_deciphering_transaction_with_non_op_return_output_returns_none() {
    let mut op_return_script: ByteArray = Default::default();

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);
    assert(values.is_none(), 'should return None');
}

#[test]
fn test_deciphering_transaction_with_bare_op_return_returns_none() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);
    assert(values.is_none(), 'should return None');
}

#[test]
fn test_deciphering_transaction_with_non_matching_op_return_returns_none() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    append_string("FOOO", ref op_return_script);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);
    assert(values.is_none(), 'values found');
}

#[test]
fn test_deciphering_runestone_with_truncated_varint_succeeds() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    // push number 128
    op_return_script.append_byte(0x01);
    op_return_script.append_byte(128);

    let tx = transaction(array![op_return_script].span());

    let values = extract_runestone(tx);
    assert(values.is_some(), 'should return Some');
}

#[test]
fn test_deciphering_empty_runestone_is_successful() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(Runestone { ..Default::default() });
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_invalid_input_scripts_are_skipped_when_searching_for_runestone() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_PUSHBYTES_9);
    op_return_script.append_byte(OP_13);
    op_return_script.append_byte(OP_PUSHBYTES_4);

    let mut op_return_script_2: ByteArray = Default::default();
    op_return_script_2.append_byte(OP_RETURN);
    op_return_script_2.append_byte(OP_13);
    // Add [MINT, 1, MINT, 1];
    op_return_script_2.append_byte(OP_PUSHBYTES_4);
    op_return_script_2.append_byte(MINT);
    op_return_script_2.append_byte(1);
    op_return_script_2.append_byte(MINT);
    op_return_script_2.append_byte(1);

    let tx = transaction(array![op_return_script, op_return_script_2].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(
                Runestone { mint: Option::Some(RuneId { block: 1, tx: 1 }), ..Default::default() }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_deciphering_non_empty_runestone_is_successful() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script, array![Tag::Body.get().try_into().unwrap(), 1, 1, 2, 0].span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(
                Runestone {
                    mint: Option::None,
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::None,
                    pointer: Option::None,
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Default::default();
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching_with_rune() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            4,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching { rune: Option::Some(4), ..Default::default() };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching_with_term() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap() | Flag::Terms.mask().try_into().unwrap(),
            Tag::OffsetEnd.get().try_into().unwrap(),
            4,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                terms: Option::Some(
                    Terms { offset: (Option::None, Option::Some(4)), ..Default::default() }
                ),
                ..Default::default()
            };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching_with_amount() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap() | Flag::Terms.mask().try_into().unwrap(),
            Tag::Amount.get().try_into().unwrap(),
            4,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                terms: Option::Some(Terms { amount: Option::Some(4), ..Default::default() }),
                ..Default::default()
            };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_duplicate_odd_tags_are_ignored() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Divisibility.get().try_into().unwrap(),
            4,
            Tag::Divisibility.get().try_into().unwrap(),
            5,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                rune: Option::None, divisibility: Option::Some(4), ..Default::default()
            };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_unrecognized_odd_tag_is_ignored() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Nop.get().try_into().unwrap(), 100, Tag::Body.get().try_into().unwrap(), 1, 1, 2, 0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());

    let values = extract_runestone(tx);
    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching_with_divisibility() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            4,
            Tag::Divisibility.get().try_into().unwrap(),
            5,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                rune: Option::Some(4), divisibility: Option::Some(5), ..Default::default()
            };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_divisibility_above_max_is_ignored() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            4,
            Tag::Divisibility.get().try_into().unwrap(),
            (ETCHING_MAX_DIVISIBILITY + 1).try_into().unwrap(),
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching { rune: Option::Some(4), ..Default::default() };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_symbol_above_max_is_ignored() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Symbol.get().try_into().unwrap(),
            128,
            128,
            68,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching { ..Default::default() };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching_with_symbol() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            4,
            Tag::Symbol.get().try_into().unwrap(),
            'a'.try_into().unwrap(),
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                rune: Option::Some(4), symbol: Option::Some("a"), ..Default::default()
            };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching_with_all_etching_tags() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap()
                | Flag::Terms.mask().try_into().unwrap()
                | Flag::Turbo.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            4,
            Tag::Divisibility.get().try_into().unwrap(),
            1,
            Tag::Spacers.get().try_into().unwrap(),
            5,
            Tag::Symbol.get().try_into().unwrap(),
            'a'.try_into().unwrap(),
            Tag::OffsetEnd.get().try_into().unwrap(),
            2,
            Tag::Amount.get().try_into().unwrap(),
            3,
            Tag::Premine.get().try_into().unwrap(),
            8,
            Tag::Cap.get().try_into().unwrap(),
            9,
            Tag::Pointer.get().try_into().unwrap(),
            0,
            Tag::Mint.get().try_into().unwrap(),
            1,
            Tag::Mint.get().try_into().unwrap(),
            1,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                divisibility: Option::Some(1),
                premine: Option::Some(8),
                rune: Option::Some(4),
                spacers: Option::Some(5),
                symbol: Option::Some("a"),
                terms: Option::Some(
                    Terms {
                        amount: Option::Some(3),
                        height: (Option::None, Option::None),
                        cap: Option::Some(9),
                        offset: (Option::None, Option::Some(2)),
                    }
                ),
                turbo: true,
            };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    pointer: Option::Some(0),
                    mint: Option::Some(RuneId { block: 1, tx: 1 }),
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_decipher_etching_with_divisibility_and_symbol() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            4,
            Tag::Divisibility.get().try_into().unwrap(),
            1,
            Tag::Symbol.get().try_into().unwrap(),
            'a'.try_into().unwrap(),
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                divisibility: Option::Some(1),
                rune: Option::Some(4),
                symbol: Option::Some("a"),
                ..Default::default()
            };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_tag_values_are_not_parsed_as_tags() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Divisibility.get().try_into().unwrap(),
            Tag::Body.get().try_into().unwrap(),
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching { divisibility: Option::Some(0), ..Default::default() };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_runestone_may_contain_multiple_edicts() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![Tag::Body.get().try_into().unwrap(), 1, 1, 2, 0, 0, 3, 5, 0].span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![
                        Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 },
                        Edict { id: RuneId { block: 1, tx: 3 }, amount: 5, output: 0 },
                    ],
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_payload_pushes_are_concatenated() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Divisibility.get().try_into().unwrap(),
            5,
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching { divisibility: Option::Some(5), ..Default::default() };
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 },],
                    etching: Option::Some(etching),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_runestone_may_be_in_second_output() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(ref op_return_script, array![0, 1, 1, 2, 0].span());

    let tx = transaction(array![Default::default(), op_return_script.into(),].span());

    let values = extract_runestone(tx);
    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 },],
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_runestone_may_be_after_non_matching_op_return() {
    let mut op_return_script_1: ByteArray = Default::default();
    op_return_script_1.append_byte(OP_RETURN);
    append_string("FOO", ref op_return_script_1);

    let mut op_return_script_2: ByteArray = Default::default();
    op_return_script_2.append_byte(OP_RETURN);
    op_return_script_2.append_byte(OP_13);
    append_arr(ref op_return_script_2, array![0, 1, 1, 2, 0].span());

    let tx = transaction(array![op_return_script_1, op_return_script_2].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(
                Runestone {
                    edicts: array![Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 },],
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_min_runes_is_not_cenotaphs() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching { rune: Option::Some(0), ..Default::default() };
            let expected = Artifact::Runestone(
                Runestone { etching: Option::Some(etching), ..Default::default() }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}
#[test]
fn test_max_runes_is_not_cenotaphs() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::Rune.get().try_into().unwrap(),
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            3
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching { rune: Option::Some(U128_MAX), ..Default::default() };
            let expected = Artifact::Runestone(
                Runestone { etching: Option::Some(etching), ..Default::default() }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_invalid_spacers_does_not_produce_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Spacers.get().try_into().unwrap(),
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            3
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(Runestone { ..Default::default() });
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_invalid_symbol_does_not_produce_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Symbol.get().try_into().unwrap(),
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            3
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(Runestone { ..Default::default() });
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_amount_does_not_produce_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap() | Flag::Terms.mask().try_into().unwrap(),
            Tag::Cap.get().try_into().unwrap(),
            1,
            Tag::Amount.get().try_into().unwrap(),
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            3
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let etching: Etching = Etching {
                terms: Option::Some(
                    Terms {
                        cap: Option::Some(1),
                        amount: Option::Some(U128_MAX),
                        height: (Option::None, Option::None),
                        offset: (Option::None, Option::None),
                    }
                ),
                ..Default::default()
            };
            let expected = Artifact::Runestone(
                Runestone { etching: Option::Some(etching), ..Default::default() }
            );
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_invalid_scripts_in_op_returns_without_magic_number_are_ignored_1() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_PUSHBYTES_4);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    assert(values.is_none(), 'should not return output');
}

#[test]
fn test_invalid_scripts_in_op_returns_without_magic_number_are_ignored_2() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);

    let tx = transaction(array![op_return_script].span());

    let values = extract_runestone(tx);
    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(Runestone { ..Default::default() });
            assert(output == expected, 'wrong runestone value');
        }
    }
}

#[test]
fn test_invalid_divisibility_does_not_produce_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Divisibility.get().try_into().unwrap(),
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            3
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Runestone(Runestone { ..Default::default() });
            assert(output == expected, 'wrong runestone value');
        }
    }
}
