use runes_lib::parser::extract_runestone;
use runes_lib::constants::{OP_RETURN, OP_13};
use runes_lib::types::{Runestone, Artifact, Cenotaph};
use super::utils::{transaction, OP_VERIFY, OP_PUSHNUM_1};

#[test]
fn test_all_pushdata_opcodes_are_valid() {
    let mut i: u8 = 0;

    loop {
        let mut op_return_script: ByteArray = Default::default();
        op_return_script.append_byte(OP_RETURN);
        op_return_script.append_byte(OP_13);
        op_return_script.append_byte(i);

        if i <= 75 {
            let mut j: u8 = 0;
            loop {
                if j >= i {
                    break;
                }
                let val: u8 = if j % 2 == 0 {
                    1_u8
                } else {
                    0_u8
                };
                op_return_script.append_byte(val);
                j += 1;
            };

            if i % 2 == 1 {
                op_return_script.append_byte(1);
                op_return_script.append_byte(1);
            }
        } else if i == 76 {
            op_return_script.append_byte(0);
        } else if i == 77 {
            op_return_script.append_byte(0);
            op_return_script.append_byte(0);
        } else if i == 78 {
            op_return_script.append_byte(0);
            op_return_script.append_byte(0);
            op_return_script.append_byte(0);
            op_return_script.append_byte(0);
        }

        let tx = transaction(array![op_return_script].span());
        let values = extract_runestone(tx);
        match values {
            Option::None => { panic!("Should not return None"); },
            Option::Some(output) => {
                let expected = Artifact::Runestone(Runestone { ..Default::default() });
                assert(output == expected, 'wrong runestone value');
            }
        }

        if i == 78 {
            break;
        }

        i += 1;
    };
}

#[test]
fn test_all_non_pushdata_opcodes_are_invalid() {
    let mut i: u8 = 79;

    loop {
        let mut op_return_script: ByteArray = Default::default();
        op_return_script.append_byte(OP_RETURN);
        op_return_script.append_byte(OP_13);
        op_return_script.append_byte(i);

        let tx = transaction(array![op_return_script].span());
        let values = extract_runestone(tx);
        match values {
            Option::None => { panic!("Should not return None"); },
            Option::Some(output) => {
                let expected = Artifact::Cenotaph(
                    Cenotaph {
                        flaw: Option::Some("non-pushdata opcode in OP_RETURN"), ..Default::default()
                    }
                );
                assert(output == expected, 'wrong cenotaph value');
            }
        }

        if i == 255 {
            break;
        }
        i += 1;
    };
}

#[test]
fn test_outputs_with_non_pushdata_opcodes_are_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    op_return_script.append_byte(OP_VERIFY);
    // Add single byte [0]
    op_return_script.append_byte(0x01); // Push size prefix (1 byte)
    op_return_script.append_byte(0x00); // The actual value [0]
    // Add varint::encode(1) twice (each as a single byte)
    op_return_script.append_byte(0x01); // Push size prefix (1 byte)
    op_return_script.append_byte(0x01); // First varint
    op_return_script.append_byte(0x01); // Push size prefix (1 byte)
    op_return_script.append_byte(0x01); // Second varint
    // Add [2, 0]
    op_return_script.append_byte(0x02); // Push size prefix (2 bytes)
    op_return_script.append_byte(0x02); // First byte
    op_return_script.append_byte(0x00); // Second byte

    let mut op_return_script_2: ByteArray = Default::default();
    op_return_script_2.append_byte(OP_RETURN);
    op_return_script_2.append_byte(OP_13);
    // Add single byte [0]
    op_return_script_2.append_byte(0x01); // Push size prefix (1 byte)
    op_return_script_2.append_byte(0x00); // The actual value [0]
    // Add varint::encode(1)
    op_return_script_2.append_byte(0x01); // Push size prefix (1 byte)
    op_return_script_2.append_byte(0x01); // First varint
    // Add varint::encode(2)
    op_return_script_2.append_byte(0x01); // Push size prefix (1 byte)
    op_return_script_2.append_byte(0x02); // Second varint
    // Add [3, 0]
    op_return_script_2.append_byte(0x02); // Push size prefix (2 bytes)
    op_return_script_2.append_byte(0x03); // First byte
    op_return_script_2.append_byte(0x00); // Second byte

    let tx = transaction(array![op_return_script, op_return_script_2].span());
    let values = extract_runestone(tx);
    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Cenotaph(
                Cenotaph {
                    flaw: Option::Some("non-pushdata opcode in OP_RETURN"), ..Default::default()
                }
            );
            assert(output == expected, 'wrong cenotaph value');
        }
    }
}

#[test]
fn test_pushnum_opcodes_in_runestone_produce_cenotaph() {
    let mut op_return_script: ByteArray = Default::default();
    op_return_script.append_byte(OP_RETURN);
    op_return_script.append_byte(OP_13);
    op_return_script.append_byte(OP_VERIFY);
    op_return_script.append_byte(OP_PUSHNUM_1);

    let tx = transaction(array![op_return_script].span());
    let values = extract_runestone(tx);
    match values {
        Option::None => { panic!("Should not return None"); },
        Option::Some(output) => {
            let expected = Artifact::Cenotaph(
                Cenotaph {
                    flaw: Option::Some("non-pushdata opcode in OP_RETURN"), ..Default::default()
                }
            );
            assert(output == expected, 'wrong cenotaph value');
        }
    }
}
