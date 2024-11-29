use runes_lib::parser::{extract_runestone, OP_RETURN, OP_13};
use utils::hex::from_hex;
use consensus::types::transaction::{Transaction, TxOut};


#[test]
fn test_extract_runestone() {
    // Create a transaction with an OP_RETURN output containing encoded values
    let mut op_return_script: ByteArray = from_hex("6a5d0714c5953514df23");

    let tx = Transaction {
        version: 0,
        inputs: array![].span(),
        outputs: array![TxOut { value: 0, pk_script: @op_return_script.into(), cached: false }]
            .span(),
        lock_time: 0,
        is_segwit: false
    };

    // Extract values and verify
    let values = extract_runestone(tx);
    println!("values: {:?}", values);
    assert(values.len() == 2, 'wrong number of values');
    assert(*values[0] == 1, 'wrong value at index 0');
    assert(*values[1] == 2, 'wrong value at index 1');
}
