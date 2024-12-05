use core::num::traits::Zero;
use consensus::{types::transaction::{Transaction}};
use core::traits::Into;
use core::dict::Felt252Dict;

use runes_lib::runestone::{tag::{Tag, TagTrait}, message::extract_etching};
use runes_lib::utils::{
    varint::decode_integers, fields::{append_value, store_field_key, has_even_tag}
};
use runes_lib::types::{Edict, RuneId, Runestone, Artifact, Cenotaph, Payload, Rune};
use runes_lib::constants::{OP_RETURN, OP_13};


pub fn extract_runestone(tx: Transaction) -> Option<Artifact> {
    let mut outputs = tx.outputs;
    let mut runestone_output = Option::None;
    loop {
        match outputs.pop_front() {
            Option::None => { break; },
            Option::Some(output) => {
                let pubscript = *output.pk_script;
                if pubscript.len() < 2 {
                    continue;
                }
                if pubscript[0] == OP_RETURN && pubscript[1] == OP_13 {
                    // load payload
                    let payload = match load_payload(pubscript.clone(), 2) {
                        Option::Some(payload) => {
                            match payload {
                                Payload::Valid(p) => p,
                                Payload::Invalid(flaw) => {
                                    runestone_output =
                                        Option::Some(
                                            Artifact::Cenotaph(
                                                Cenotaph {
                                                    flaw: Option::Some(flaw), ..Default::default()
                                                }
                                            )
                                        );
                                    break;
                                },
                            }
                        },
                        Option::None => { break; },
                    };

                    // decode integers
                    let decoded = match decode_integers(payload) {
                        Result::Ok(decoded) => decoded,
                        Result::Err(flaw) => {
                            runestone_output =
                                Option::Some(
                                    Artifact::Cenotaph(
                                        Cenotaph { flaw: Option::Some(flaw), ..Default::default() }
                                    )
                                );
                            break;
                        },
                    };
                    // parse message
                    let (edicts, fields, flaws, fields_keys) = parse_message(tx, decoded);

                    // get runestone
                    runestone_output = get_runestone(tx, edicts, fields, fields_keys, flaws);
                    break;
                };
            },
        }
    };

    runestone_output
}

// would load bitcoin script instructions to add element in stack and panic on other instruction
pub fn load_payload(pubscript: ByteArray, mut index: usize) -> Option<Payload> {
    let mut output: ByteArray = Default::default();
    let mut current_index: u32 = index;
    let mut flaw: ByteArray = Default::default();

    loop {
        if current_index >= pubscript.len() {
            break;
        }

        let opcode: u8 = pubscript[current_index];
        current_index += 1;

        if opcode == 0 {
            continue;
        }

        // Handle direct size (1-75 bytes)
        if opcode > 0 && opcode <= 0x4b {
            let size: u32 = opcode.into();

            if current_index + size > pubscript.len() {
                flaw = "invalid script in OP_RETURN";
                break;
            }

            let mut i: usize = 0;
            loop {
                if i >= size {
                    break;
                }
                output.append_byte(pubscript[current_index + i]);
                i += 1;
            };
            current_index += size;
            continue;
        }

        // Handle OP_PUSHDATA1 (76-255 bytes)
        if opcode == 0x4c {
            let size: u32 = pubscript[current_index].into();

            if current_index + size > pubscript.len() {
                flaw = "invalid script in OP_RETURN";
                break;
            }

            current_index += 1;
            let mut i = 0;
            loop {
                if i >= size {
                    break;
                }
                output.append_byte(pubscript[current_index + i]);
                i += 1;
            };
            current_index += size;
            continue;
        }

        // Handle OP_PUSHDATA2 (256-65535 bytes)
        if opcode == 0x4d {
            if current_index + 2 > pubscript.len() {
                flaw = "Not enough data for OP_PUSHDATA2 size field";
                break;
            }

            // * 256 is << 8z
            let size: u32 = ((pubscript[current_index]).into()
                // so it doesn't exceed the max value
                | ((pubscript[current_index + 1]).into() * 256)
                & 0xFF00);

            if current_index + size > pubscript.len() {
                flaw = "Not enough data for OP_PUSHDATA2 size field";
                break;
            }

            current_index += 2;
            let mut i: usize = 0;
            loop {
                if i >= size {
                    break;
                }
                output.append_byte(pubscript[current_index + i]);
                i += 1;
            };
            current_index += size;
            continue;
        }

        // Handle OP_PUSHDATA4 (256-65535 bytes)
        if opcode == 0x4e {
            if current_index + 4 > pubscript.len() {
                flaw = "Not enough data for OP_PUSHDATA4 size field";
                break;
            }

            // * 256 is << 8z
            let size: u32 = ((pubscript[current_index]).into()
                // so it doesn't exceed the max value
                | ((pubscript[current_index + 1]).into() * 256)
                & 0xFF00);

            if current_index + size > pubscript.len() {
                flaw = "Not enough data for OP_PUSHDATA4 size field";
                break;
            }

            current_index += 4;
            // Copy the next 'size' bytes to output
            let mut i: usize = 0;
            loop {
                if i >= size {
                    break;
                }
                output.append_byte(pubscript[current_index + i]);
                i += 1;
            };
            current_index += size;
            continue;
        }

        flaw = "non-pushdata opcode in OP_RETURN";
        break;
    };

    if flaw.len() > 0 {
        return Option::Some(Payload::Invalid(flaw));
    }

    Option::Some(Payload::Valid(output))
}

fn build_edict(tx: Transaction, id: RuneId, amount: u128, output: u128) -> Option<Edict> {
    let output: u32 = match output.try_into() {
        Option::None => { return Option::None; },
        Option::Some(o) => o,
    };

    if output > tx.outputs.len() {
        return Option::None;
    }

    Option::Some(Edict { id, amount, output })
}

pub fn parse_message(
    tx: Transaction, payload: Array<u128>
) -> (Array<Edict>, Felt252Dict<Nullable<Array<u128>>>, Option<ByteArray>, Array<u128>) {
    let mut edicts: Array<Edict> = ArrayTrait::new();
    let mut fields: Felt252Dict<Nullable<Array<u128>>> = Default::default();
    let mut fields_keys: Array<u128> = ArrayTrait::new();
    let mut flaw: ByteArray = Default::default();

    let mut i = 0;

    loop {
        if i >= payload.len() {
            break;
        }

        let tag: u128 = *payload[i];

        if tag == Tag::Body.get() {
            let mut id: RuneId = Default::default();

            let mut j = i + 1;

            loop {
                if j >= payload.len() {
                    break;
                }

                let mut chunk: Array<u128> = ArrayTrait::new();
                let mut k = 0;
                // Collect up to 4 elements into `chunk`
                loop {
                    if k >= 4 || j + k >= payload.len() {
                        break;
                    }
                    chunk.append(*payload[j + k]);
                    k += 1;
                };

                if chunk.len() != 4 {
                    flaw = "trailing integers in body";
                    break;
                }

                // Process chunk
                let next = id.next(*chunk[0], *chunk[1]);
                match next {
                    Option::Some(next_id) => {
                        match build_edict(tx, next_id, *chunk[2], *chunk[3]) {
                            Option::None => {
                                flaw = "edict output greater than transaction output count";
                                break;
                            },
                            Option::Some(edict) => {
                                id = next_id;
                                edicts.append(edict);
                            },
                        };
                    },
                    Option::None => {
                        flaw = "invalid rune ID in edict";
                        break;
                    }
                }
                j += 4;
            };
            break;
        } else {
            // value
            match payload.get(i + 1) {
                Option::None => {
                    flaw = "field with missing value";
                    break;
                },
                Option::Some(v) => {
                    append_value(ref fields, tag.into(), *v.deref());
                    store_field_key(ref fields_keys, tag);
                },
            };
        }

        i += 2;
    };

    (edicts, fields, Option::Some(flaw), fields_keys)
}


pub fn get_runestone(
    tx: Transaction,
    edicts: Array<Edict>,
    mut fields: Felt252Dict<Nullable<Array<u128>>>,
    mut fields_keys: Array<u128>,
    flaw: Option<ByteArray>
) -> Option<Artifact> {
    let mut flaw: ByteArray = flaw.unwrap_or_default();
    let mut flags = match Tag::Flags.take(ref fields, ref fields_keys, 1) {
        Option::None => { 0 },
        Option::Some(flags) => { *flags.at(0) },
    };

    let (etching, supply_check, rune) = extract_etching(ref flags, ref fields, ref fields_keys);

    let mint: Option<RuneId> = Tag::Mint.take_mint(ref fields, ref fields_keys);

    let pointer: Option<u32> = Tag::Pointer
        .take_pointer(ref fields, ref fields_keys, tx.outputs.len().into());

    if etching.is_some() && supply_check.is_none() {
        flaw = "supply overflows u128";
    }

    if !flags.is_zero() {
        flaw = "unrecognized field";
    }

    if has_even_tag(fields_keys.span()) {
        flaw = "unrecognized even tag";
    }

    if flaw.len() > 0 {
        return Option::Some(
            Artifact::Cenotaph(Cenotaph { flaw: Option::Some(flaw), mint, etching: rune })
        );
    }

    Option::Some(Artifact::Runestone(Runestone { edicts, mint, etching, pointer }))
}
