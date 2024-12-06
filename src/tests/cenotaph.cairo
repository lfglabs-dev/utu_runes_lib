use runes_lib::parser::extract_runestone;
use runes_lib::constants::{OP_RETURN, OP_13};
use runes_lib::types::{Runestone, Artifact, Cenotaph, Edict, RuneId};
use runes_lib::runestone::{tag::{Tag, TagTrait}, flag::{Flag, FlagTrait}};
use super::utils::{transaction, OP_PUSHBYTES_4, append_arr, build_output, CenotaphFlaw};

#[test]
fn test_deciphering_valid_runestone_with_invalid_script_postfix_returns_invalid_payload() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    op_return_script.append_byte(OP_PUSHBYTES_4);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);
    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::INVALID_SCRIPT(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_terms_flag_without_etching_flag_produces_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Terms.mask().try_into().unwrap(),
            Tag::Body.get().try_into().unwrap(),
            0,
            0,
            0,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::UNRECOGNIZED_FLAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_recognized_fields_without_flag_produces_cenotaph() {
    let mut cases = array![
        array![Tag::Premine.get().try_into().unwrap(), 0],
        array![Tag::Rune.get().try_into().unwrap(), 0],
        array![Tag::Cap.get().try_into().unwrap(), 0],
        array![Tag::Amount.get().try_into().unwrap(), 0],
        array![Tag::OffsetStart.get().try_into().unwrap(), 0],
        array![Tag::OffsetEnd.get().try_into().unwrap(), 0],
        array![Tag::HeightStart.get().try_into().unwrap(), 0],
        array![Tag::HeightEnd.get().try_into().unwrap(), 0],
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.get().try_into().unwrap(),
            Tag::Cap.get().try_into().unwrap(),
            0
        ],
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.get().try_into().unwrap(),
            Tag::Amount.get().try_into().unwrap(),
            0
        ],
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.get().try_into().unwrap(),
            Tag::OffsetStart.get().try_into().unwrap(),
            0
        ],
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.get().try_into().unwrap(),
            Tag::OffsetEnd.get().try_into().unwrap(),
            0
        ],
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.get().try_into().unwrap(),
            Tag::HeightStart.get().try_into().unwrap(),
            0
        ],
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.get().try_into().unwrap(),
            Tag::HeightEnd.get().try_into().unwrap(),
            0
        ],
    ]
        .span();
    let mut i = 0;

    loop {
        let case = match cases.pop_front() {
            Option::Some(value) => value,
            Option::None => { break; }
        };
        let op_return_script: ByteArray = build_output(case.clone());

        let tx = transaction(array![op_return_script].span());
        let values = extract_runestone(tx);
        match values {
            Option::None => { panic!("Should not return None"); },
            Option::Some(output) => {
                assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
            }
        }

        i += 1;
    }
}

#[test]
fn test_invalid_varint_produces_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    // push number 128
    op_return_script.append_byte(0x01); // Push size prefix (1 byte)
    op_return_script.append_byte(128);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::VARINT(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_duplicate_even_tags_produce_cenotaph() {
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
            Tag::Rune.get().try_into().unwrap(),
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
            let expected = Artifact::Cenotaph(
                Cenotaph {
                    flaw: Option::Some("unrecognized even tag"),
                    etching: Option::Some(4),
                    ..Default::default()
                }
            );
            assert(output == expected, 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestone_with_unrecognized_even_tag_is_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Cenotaph.get().try_into().unwrap(),
            0,
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
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestone_with_unrecognized_flag_is_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
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
            2,
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
            assert(output == CenotaphFlaw::UNRECOGNIZED_FLAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestone_with_edict_id_with_zero_block_and_nonzero_tx_is_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script, array![Tag::Body.get().try_into().unwrap(), 0, 1, 2, 0].span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::EDICT_RUNE_ID(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestone_with_overflowing_edict_id_delta_is_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Body.get().try_into().unwrap(),
            1,
            0,
            0,
            0,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            1,
            0,
            0,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::EDICT_RUNE_ID(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestone_with_overflowing_edict_id_delta_is_cenotaph_2() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            0,
            0,
            0,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            255,
            1,
            0,
            0
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::EDICT_RUNE_ID(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestone_with_output_over_max_is_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script, array![Tag::Body.get().try_into().unwrap(), 1, 1, 2, 2].span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::EDICT_OUTPUT(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_tag_with_no_value_is_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![Tag::Flags.get().try_into().unwrap(), 1, Tag::Flags.get().try_into().unwrap()].span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::TRUNCATED_FIELD(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_trailing_integers_in_body_is_cenotaph() {
    let mut cases = array![
        array![Tag::Body.get().try_into().unwrap(), 1, 1, 2, 0],
        array![Tag::Body.get().try_into().unwrap(), 1, 1, 2, 0, 0],
        array![Tag::Body.get().try_into().unwrap(), 1, 1, 2, 0, 0, 0],
        array![Tag::Body.get().try_into().unwrap(), 1, 1, 2, 0, 0, 0, 0],
    ]
        .span();
    let mut i = 0;

    loop {
        let case = match cases.pop_front() {
            Option::Some(value) => value,
            Option::None => { break; }
        };

        let op_return_script: ByteArray = build_output(case.clone());
        let tx = transaction(array![op_return_script].span());
        let values = extract_runestone(tx);

        match values {
            Option::None => { panic!("Should not return None"); },
            Option::Some(output) => {
                if i == 0 {
                    let expected = Artifact::Runestone(
                        Runestone {
                            edicts: array![
                                Edict { id: RuneId { block: 1, tx: 1 }, amount: 2, output: 0 }
                            ],
                            ..Default::default()
                        }
                    );
                    assert(output == expected, 'wrong runestone value');
                } else {
                    assert(output == CenotaphFlaw::TRAILING_INTEGERS(), 'wrong cenotaph value');
                }
            }
        }
        i += 1;
    }
}

#[test]
fn test_recognized_even_etching_fields_produce_cenotaph_if_etching_flag_is_not_set() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(ref op_return_script, array![Tag::Rune.get().try_into().unwrap(), 4,].span());

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestones_with_invalid_rune_id_blocks_are_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0,
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
            3,
            1,
            0,
            0,
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::EDICT_RUNE_ID(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_runestones_with_invalid_rune_id_txs_are_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            2,
            0,
            1,
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
            3,
            0,
            0,
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::EDICT_RUNE_ID(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_etching_with_term_greater_than_maximum_is_still_an_etching() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap(),
            Tag::OffsetEnd.get().try_into().unwrap(),
            128,
            128,
            128,
            128,
            128,
            128,
            128,
            128,
            128,
            2
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_edict_output_greater_than_32_max_produces_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Body.get().try_into().unwrap(),
            1,
            1,
            1,
            128,
            128,
            128,
            128,
            128,
            128,
            128,
            128,
            128,
            2
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::EDICT_OUTPUT(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_partial_mint_produces_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(ref op_return_script, array![Tag::Mint.get().try_into().unwrap(), 1,].span());

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_mint_produces_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![Tag::Mint.get().try_into().unwrap(), 0, Tag::Mint.get().try_into().unwrap(), 1,]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_deadline_produces_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::OffsetEnd.get().try_into().unwrap(),
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
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_default_output_produces_cenotaph_1() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(ref op_return_script, array![Tag::Pointer.get().try_into().unwrap(), 1].span());

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_default_output_produces_cenotaph_2() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Pointer.get().try_into().unwrap(),
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
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_term_produces_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::OffsetEnd.get().try_into().unwrap(),
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
            assert(output == CenotaphFlaw::UNRECOGNIZED_EVEN_TAG(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_supply_produces_cenotaph() {
    let op_return_script = build_output(
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap() | Flag::Terms.mask().try_into().unwrap(),
            Tag::Cap.get().try_into().unwrap(),
            2,
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
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::SUPPLY_OVERFLOW(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_supply_produces_cenotaph_2() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap() | Flag::Terms.mask().try_into().unwrap(),
            Tag::Cap.get().try_into().unwrap(),
            2,
            Tag::Amount.get().try_into().unwrap(),
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
            2
        ]
            .span()
    );

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::SUPPLY_OVERFLOW(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_supply_produces_cenotaph_3() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    append_arr(
        ref op_return_script,
        array![
            Tag::Flags.get().try_into().unwrap(),
            Flag::Etching.mask().try_into().unwrap() | Flag::Terms.mask().try_into().unwrap(),
            Tag::Premine.get().try_into().unwrap(),
            1,
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
            assert(output == CenotaphFlaw::SUPPLY_OVERFLOW(), 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_invalid_scripts_in_op_returns_with_magic_number_produce_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    op_return_script.append_byte(OP_PUSHBYTES_4);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);

    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            assert(output == CenotaphFlaw::INVALID_SCRIPT(), 'wrong cenotaph value');
        }
    }
}
