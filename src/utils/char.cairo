use alexandria_data_structures::byte_array_ext::SpanU8IntoBytearray;

const SHIFT_6: u32 = 64; // 2^6
const SHIFT_12: u32 = 4096; // 2^12
const SHIFT_18: u32 = 262144; // 2^18

pub fn from_u32_to_char(symbol: Option<u32>) -> Option<ByteArray> {
    if symbol.is_none() {
        return Option::None;
    }

    let symbol = symbol.unwrap();
    if symbol > 0x10FFFF || (symbol >= 0xD800 && symbol <= 0xDFFF) {
        return Option::None; // Invalid Unicode scalar value
    }

    // Convert the u32 to a single-character UTF-8 string
    let buffer: Span<u8> = encode_utf8(symbol);

    // Create a single-character string from the buffer
    Option::Some(buffer.into())
}

fn encode_utf8(code_point: u32) -> Span<u8> {
    let mut buffer: Array<u8> = Default::default();
    if code_point <= 0x7F {
        buffer.append(code_point.try_into().unwrap());
    } else if code_point <= 0x7FF {
        buffer.append((0xC0 | (code_point / SHIFT_6)).try_into().unwrap());
        buffer.append((0x80 | (code_point % SHIFT_6)).try_into().unwrap());
    } else if code_point <= 0xFFFF {
        buffer.append((0xE0 | (code_point / SHIFT_12)).try_into().unwrap());
        buffer.append((0x80 | ((code_point / SHIFT_6) % SHIFT_6)).try_into().unwrap());
        buffer.append((0x80 | (code_point % SHIFT_6)).try_into().unwrap());
    } else {
        buffer.append((0xF0 | (code_point / SHIFT_18)).try_into().unwrap());
        buffer.append((0x80 | ((code_point / SHIFT_12) % SHIFT_6)).try_into().unwrap());
        buffer.append((0x80 | ((code_point / SHIFT_6) % SHIFT_6)).try_into().unwrap());
        buffer.append((0x80 | (code_point % SHIFT_6)).try_into().unwrap());
    }
    buffer.span()
}
