use core::dict::{Felt252Dict, Felt252DictEntryTrait};
use runes_lib::{
    types::{RuneId, Rune}, utils::fields::{get_array_entry, get_new_field_val, remove_field_key}
};

#[derive(Drop, Copy)]
pub enum Tag {
    Body,
    Flags,
    Rune,
    Premine,
    Cap,
    Amount,
    HeightStart,
    HeightEnd,
    OffsetStart,
    OffsetEnd,
    Mint,
    Pointer,
    Cenotaph,
    Divisibility,
    Spacers,
    Symbol,
    Nop,
}

pub trait TagTrait {
    fn get(self: Tag) -> u128;
    fn take(
        self: Tag,
        ref fields: Felt252Dict<Nullable<Array<u128>>>,
        ref field_key: Array<u128>,
        n: usize,
    ) -> Option<Span<u128>>;
    fn take_mint(
        self: Tag, ref fields: Felt252Dict<Nullable<Array<u128>>>, ref field_key: Array<u128>,
    ) -> Option<RuneId>;
    fn take_pointer(
        self: Tag,
        ref fields: Felt252Dict<Nullable<Array<u128>>>,
        ref field_key: Array<u128>,
        output_len: u64
    ) -> Option<u32>;
}

impl TagImpl of TagTrait {
    // Maps each tag to its corresponding value
    fn get(self: Tag) -> u128 {
        match self {
            Tag::Body => 0,
            Tag::Flags => 2,
            Tag::Rune => 4,
            Tag::Premine => 6,
            Tag::Cap => 8,
            Tag::Amount => 10,
            Tag::HeightStart => 12,
            Tag::HeightEnd => 14,
            Tag::OffsetStart => 16,
            Tag::OffsetEnd => 18,
            Tag::Mint => 20,
            Tag::Pointer => 22,
            Tag::Cenotaph => 126,
            Tag::Divisibility => 1,
            Tag::Spacers => 3,
            Tag::Symbol => 5,
            Tag::Nop => 127,
        }
    }

    fn take(
        self: Tag,
        ref fields: Felt252Dict<Nullable<Array<u128>>>,
        ref field_key: Array<u128>,
        n: usize,
    ) -> Option<Span<u128>> {
        let index = self.get();
        let field = get_array_entry(ref fields, index.into());

        if field.len() < n {
            return Option::None;
        }

        let res = field.slice(0, n);

        // Update fields value
        let (entry, _) = fields.entry(index.into());
        if field.len() == n {
            // We remove the field & field key
            fields = entry.finalize(NullableTrait::new(Default::default()));
            remove_field_key(ref field_key, index);
        } else {
            let new_field = field.slice(n, field.len() - 1);
            fields = entry.finalize(NullableTrait::new(get_new_field_val(new_field)));
        }

        // Return the first `n` elements
        Option::Some(res)
    }

    fn take_mint(
        self: Tag, ref fields: Felt252Dict<Nullable<Array<u128>>>, ref field_key: Array<u128>,
    ) -> Option<RuneId> {
        let index = self.get();
        let field = get_array_entry(ref fields, index.into());

        if field.len() < 2 {
            return Option::None;
        }

        let res = field.slice(0, 2);

        let block: u64 = (*res.at(0)).try_into()?;
        let tx: u32 = (*res.at(1)).try_into()?;
        let rune = Rune::new(block, tx)?;

        // Update fields value
        let (entry, _) = fields.entry(index.into());
        if field.len() == 2 {
            // We remove the field & field key
            fields = entry.finalize(NullableTrait::new(Default::default()));
            remove_field_key(ref field_key, index);
        } else {
            let new_field = field.slice(2, field.len() - 1);
            fields = entry.finalize(NullableTrait::new(get_new_field_val(new_field)));
        }

        Option::Some(rune)
    }

    fn take_pointer(
        self: Tag,
        ref fields: Felt252Dict<Nullable<Array<u128>>>,
        ref field_key: Array<u128>,
        output_len: u64
    ) -> Option<u32> {
        let index = self.get();
        let field = get_array_entry(ref fields, index.into());

        if field.len() < 1 {
            return Option::None;
        }

        let res = field.slice(0, 1);
        let pointer: u32 = (*res.at(0)).try_into()?;
        if pointer.into() >= output_len {
            return Option::None;
        }

        // Update fields value
        let (entry, _) = fields.entry(index.into());
        if field.len() == 1 {
            // We remove the field & field key
            fields = entry.finalize(NullableTrait::new(Default::default()));
            remove_field_key(ref field_key, index);
        } else {
            let new_field = field.slice(1, field.len() - 1);
            fields = entry.finalize(NullableTrait::new(get_new_field_val(new_field)));
        }

        Option::Some(pointer)
    }
}

