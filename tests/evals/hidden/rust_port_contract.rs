use rust_feature::{parse_port, PortError};

#[test]
fn strict_decimal_contract() {
    assert_eq!(parse_port("+80"), Err(PortError::Invalid));
    assert_eq!(parse_port("８０"), Err(PortError::Invalid));
    assert_eq!(parse_port(" 443\n"), Ok(443));
}

#[test]
fn very_large_input_does_not_panic() {
    assert_eq!(parse_port("999999999999999999999"), Err(PortError::OutOfRange));
}
