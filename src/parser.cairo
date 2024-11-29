use consensus::{types::transaction::{Transaction}};

pub const OP_RETURN: u8 = 0x6a;
pub const OP_13: u8 = 0x8c;

pub fn extract_runestone(tx: Transaction) -> Option<Array<u128>> {
    let mut outputs = tx.outputs;
    let mut runestone_output = Option::None;
    loop {
        match outputs.pop_front() {
            Option::None => { break; },
            Option::Some(output) => {
                let pubscript = *output.pk_script;
                if pubscript[0] == OP_RETURN && pubscript[1] == OP_13 {
                    break;
                };
            },
        }
    };

    runestone_output
}

// would load bitcoin script instructions to add element in stack and panic on other instruction
fn load_payload(pubscript: ByteArray, mut index: usize) -> ByteArray {
    let mut output: ByteArray = Default::default();
    let mut current_index: u32 = index;
    loop {
        let opcode: u8 = pubscript[current_index];
        current_index += 1;

        // Handle direct size (1-75 bytes)
        if opcode > 0 && opcode <= 0x4b {
            let size: u32 = opcode.into();
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

        // Handle OP_PUSHDATA1 (76-255 bytes)
        if opcode == 0x4c {
            let size: u32 = pubscript[current_index].into();
            current_index += 1;
            // Copy the next 'size' bytes to output
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
            // * 256 is << 8z
            let size: u32 = ((pubscript[current_index]).into()
                // so it doesn't exceed the max value
                | ((pubscript[current_index + 1]).into() * 256)
                & 0xFF00);

            current_index += 2;
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

        // // Handle small integers (OP_0 to OP_16)
        // if opcode == 0 {
        //     output.append_byte(0);
        //     continue;
        // }
        // // if opcode >= 0x51 && opcode <= 0x60 {
        // //     output.append_byte(opcode - 0x50);
        // //     continue;
        // // }

        break; // Unknown opcode
    };

    output
}
