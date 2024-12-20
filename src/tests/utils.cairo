use consensus::types::transaction::{Transaction, TxOut};
use runes_lib::types::{Runestone, RuneId, Edict, Artifact, Etching};
use runes_lib::constants::{OP_RETURN, OP_13};

const POW_256_1: u128 = 0x100;
pub const OP_VERIFY: u8 = 0x69;
pub const OP_PUSHNUM_1: u8 = 0x51;
pub const OP_PUSHBYTES_4: u8 = 0x04;
pub const OP_PUSHBYTES_9: u8 = 0x09;
pub const MINT: u8 = 20;
pub const U128_MAX: u128 = 340282366920938463463374607431768211455;

pub fn transaction(mut op_return_scripts: Span<ByteArray>) -> Transaction {
    let mut outputs: Array<TxOut> = ArrayTrait::new();
    loop {
        match op_return_scripts.pop_front() {
            Option::Some(script) => {
                outputs.append(TxOut { value: 0, pk_script: script.into(), cached: false });
            },
            Option::None => { break; }
        }
    };
    Transaction {
        version: 2, inputs: array![].span(), outputs: outputs.span(), lock_time: 0, is_segwit: false
    }
}

pub fn append_string(string: ByteArray, ref array: ByteArray) {
    let mut index = 0;
    loop {
        if index >= string.len() {
            break;
        }
        let foo_byte: u8 = string[index];
        index += 1;
        array.append_byte(foo_byte);
    };
}

pub fn get_rune(
    mint: Option<RuneId>, edicts: Array<Edict>, etching: Option<Etching>, pointer: Option<u32>
) -> Artifact {
    let runestone: Runestone = Runestone {
        mint: mint, edicts: edicts, etching: etching, pointer: pointer,
    };
    Artifact::Runestone(runestone)
}

pub fn append_arr(ref op_return_script: ByteArray, mut arr: Span<u8>) {
    let mut index = 0;
    let arr_len = arr.len();
    op_return_script.append_byte(arr_len.try_into().unwrap());
    loop {
        if index >= arr_len {
            break;
        }
        let value = arr.pop_front().unwrap();
        op_return_script.append_byte(*value);
        index += 1;
    }
}

pub fn build_output(data: Array<u8>) -> ByteArray {
    let mut output: ByteArray = Default::default();
    output.append_byte(OP_RETURN);
    output.append_byte(OP_13);
    append_arr(ref output, data.span());

    output
}

pub mod CenotaphFlaw {
    use runes_lib::types::{Artifact, Cenotaph};

    pub fn EDICT_OUTPUT() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph {
                flaw: Option::Some("edict output greater than transaction output count"),
                ..Default::default()
            }
        )
    }

    pub fn EDICT_RUNE_ID() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph { flaw: Option::Some("invalid rune ID in edict"), ..Default::default() }
        )
    }

    pub fn INVALID_SCRIPT() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph { flaw: Option::Some("invalid script in OP_RETURN"), ..Default::default() }
        )
    }

    pub fn OPCODE() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph {
                flaw: Option::Some("non-pushdata opcode in OP_RETURN"), ..Default::default()
            }
        )
    }

    pub fn SUPPLY_OVERFLOW() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph { flaw: Option::Some("supply overflows u128"), ..Default::default() }
        )
    }

    pub fn TRAILING_INTEGERS() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph { flaw: Option::Some("trailing integers in body"), ..Default::default() }
        )
    }
    pub fn TRUNCATED_FIELD() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph { flaw: Option::Some("field with missing value"), ..Default::default() }
        )
    }
    pub fn UNRECOGNIZED_EVEN_TAG() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph { flaw: Option::Some("unrecognized even tag"), ..Default::default() }
        )
    }
    pub fn UNRECOGNIZED_FLAG() -> Artifact {
        Artifact::Cenotaph(
            Cenotaph { flaw: Option::Some("unrecognized field"), ..Default::default() }
        )
    }
    pub fn VARINT() -> Artifact {
        Artifact::Cenotaph(Cenotaph { flaw: Option::Some("invalid varint"), ..Default::default() })
    }
}

