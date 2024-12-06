use core::nullable::NullableTrait;
use core::dict::{Felt252Dict, Felt252DictEntryTrait};
use alexandria_data_structures::byte_array_ext::SpanU8IntoBytearray;

pub fn store_field_key(ref fields_keys: Array<u128>, key: u128) {
    let mut i = 0;
    let mut found = false;
    loop {
        if i >= fields_keys.len() {
            break;
        }
        if *fields_keys[i] == key {
            found = true;
            break;
        }
        i += 1;
    };

    if !found {
        fields_keys.append(key);
    }
}

pub fn append_value(ref dict: Felt252Dict<Nullable<Array<u128>>>, index: felt252, value: u128) {
    let (entry, arr) = dict.entry(index);
    let mut unboxed_val = arr.deref_or(array![]);
    unboxed_val.append(value);
    dict = entry.finalize(NullableTrait::new(unboxed_val));
}

pub fn get_array_entry(ref dict: Felt252Dict<Nullable<Array<u128>>>, index: felt252) -> Span<u128> {
    let (entry, _arr) = dict.entry(index);
    let mut arr = _arr.deref_or(array![]);
    let span = arr.span();
    dict = entry.finalize(NullableTrait::new(arr));
    span
}

pub fn remove_field_key(ref fields_keys: Array<u128>, key: u128) {
    let mut new_fields_keys: Array<u128> = array![];
    let mut i = 0;

    loop {
        if i >= fields_keys.len() {
            break;
        }

        let value = *fields_keys[i];
        if value != key {
            new_fields_keys.append(value);
        }

        i += 1;
    };
    fields_keys = new_fields_keys;
}

pub fn get_new_field_val(mut new_field: Span<u128>) -> Array<u128> {
    let mut new_field_arr = array![];
    let mut index = 0;
    loop {
        if index >= new_field.len() {
            break;
        }
        let value = new_field.pop_front().unwrap();
        new_field_arr.append(*value);
        index += 1;
    };
    new_field_arr
}

pub fn has_even_tag(mut fields_keys: Span<u128>) -> bool {
    let mut i = 0;
    let mut is_err = false;
    loop {
        if i >= fields_keys.len() {
            break;
        }
        let key = fields_keys.pop_front().unwrap();
        let (_, r) = DivRem::<u128>::div_rem(*key, 2);
        if r == 0 {
            is_err = true;
            break;
        }
        i += 1;
    };
    is_err
}
