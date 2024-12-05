use runes_lib::runestone::flag::{Flag, FlagTrait};
use alexandria_math::pow;

#[test]
fn test_mask() {
    assert_eq!(Flag::Etching.mask(), 0b1);
    assert_eq!(Flag::Cenotaph.mask(), pow(2_u128, 127));
}

#[test]
fn test_take() {
    let mut flags = 1;
    assert!(Flag::Etching.take(ref flags));
    assert_eq!(flags, 0);

    let mut flags = 0;
    assert!(!Flag::Etching.take(ref flags));
    assert_eq!(flags, 0);
}

#[test]
fn test_set() {
    let mut flags = 0;
    Flag::Etching.set(ref flags);
    assert_eq!(flags, 1);
}
