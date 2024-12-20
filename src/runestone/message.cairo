use core::dict::Felt252Dict;
use core::num::traits::CheckedMul;
use core::num::traits::CheckedAdd;

use super::{tag::{Tag, TagTrait}, flag::{Flag, FlagTrait}};
use runes_lib::{
    types::{Etching, Terms}, utils::char::from_u32_to_char,
    constants::{ETCHING_MAX_DIVISIBILITY, ETCHING_MAX_SPACERS}
};

pub fn extract_etching(
    ref flags: u128, ref fields: Felt252Dict<Nullable<Array<u128>>>, ref fields_keys: Array<u128>
) -> (Option<Etching>, Option<u128>, Option<u128>) {
    if !Flag::Etching.take(ref flags) {
        return (Option::None, Option::None, Option::None);
    }

    let divisibility: Option<u8> = get_divisibility(ref fields, ref fields_keys);
    let premine = extract_single(Tag::Premine, ref fields, ref fields_keys);
    let rune = extract_single(Tag::Rune, ref fields, ref fields_keys);
    let spacers = get_spacers(ref fields, ref fields_keys);
    let symbol = from_u32_to_char(
        extract_and_convert_to_u32(Tag::Symbol, ref fields, ref fields_keys)
    );
    let terms = get_terms(ref flags, ref fields, ref fields_keys);
    let turbo = Flag::Turbo.take(ref flags);

    let supply_check = check_supply(@premine, @terms);

    (
        Option::Some(Etching { divisibility, premine, rune, spacers, symbol, terms, turbo, }),
        supply_check,
        rune
    )
}

fn get_divisibility(
    ref fields: Felt252Dict<Nullable<Array<u128>>>, ref fields_keys: Array<u128>
) -> Option<u8> {
    match Tag::Divisibility.take(ref fields, ref fields_keys, 1) {
        Option::Some(span) => {
            let divisibility: u8 = (*span.at(0)).try_into()?;
            if divisibility <= ETCHING_MAX_DIVISIBILITY {
                Option::Some(divisibility)
            } else {
                Option::None
            }
        },
        Option::None => Option::None,
    }
}

fn get_spacers(
    ref fields: Felt252Dict<Nullable<Array<u128>>>, ref fields_keys: Array<u128>
) -> Option<u32> {
    match Tag::Spacers.take(ref fields, ref fields_keys, 1) {
        Option::Some(span) => {
            let spacers: u32 = (*span.at(0)).try_into()?;
            if spacers <= ETCHING_MAX_SPACERS {
                Option::Some(spacers)
            } else {
                Option::None
            }
        },
        Option::None => Option::None,
    }
}

pub fn get_terms(
    ref flags: u128, ref fields: Felt252Dict<Nullable<Array<u128>>>, ref fields_keys: Array<u128>
) -> Option<Terms> {
    if !Flag::Terms.take(ref flags) {
        return Option::None;
    }

    let cap = extract_single(Tag::Cap, ref fields, ref fields_keys);
    let height = (
        extract_and_convert_to_u64(Tag::HeightStart, ref fields, ref fields_keys),
        extract_and_convert_to_u64(Tag::HeightEnd, ref fields, ref fields_keys)
    );
    let amount = extract_single(Tag::Amount, ref fields, ref fields_keys);
    let offset = (
        extract_and_convert_to_u64(Tag::OffsetStart, ref fields, ref fields_keys),
        extract_and_convert_to_u64(Tag::OffsetEnd, ref fields, ref fields_keys)
    );

    Option::Some(Terms { cap, amount, height, offset, })
}

fn check_supply(premine: @Option<u128>, terms: @Option<Terms>) -> Option<u128> {
    let premine = (*premine).unwrap_or_default();
    let terms = (*terms).unwrap_or_default();
    let cap = terms.cap.unwrap_or_default();
    let amount = terms.amount.unwrap_or_default();

    premine.checked_add(cap.checked_mul(amount)?)
}

fn extract_single(
    tag: Tag, ref fields: Felt252Dict<Nullable<Array<u128>>>, ref fields_keys: Array<u128>
) -> Option<u128> {
    match tag.take(ref fields, ref fields_keys, 1) {
        Option::Some(span) => Option::Some(*span.at(0)),
        Option::None => Option::None,
    }
}

fn extract_and_convert_to_u64(
    tag: Tag, ref fields: Felt252Dict<Nullable<Array<u128>>>, ref fields_keys: Array<u128>
) -> Option<u64> {
    let val: u64 = extract_single(tag, ref fields, ref fields_keys)?.try_into()?;
    Option::Some(val)
}

fn extract_and_convert_to_u32(
    tag: Tag, ref fields: Felt252Dict<Nullable<Array<u128>>>, ref fields_keys: Array<u128>
) -> Option<u32> {
    let val: u32 = extract_single(tag, ref fields, ref fields_keys)?.try_into()?;
    Option::Some(val)
}

