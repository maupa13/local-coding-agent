use rust_feature::{parse_port, PortError};

#[test]
fn parses_boundaries_and_whitespace() {
    assert_eq!(parse_port(" 1 "), Ok(1));
    assert_eq!(parse_port("65535"), Ok(65535));
}

#[test]
fn classifies_errors() {
    assert_eq!(parse_port(""), Err(PortError::Empty));
    assert_eq!(parse_port("12x"), Err(PortError::Invalid));
    assert_eq!(parse_port("0"), Err(PortError::OutOfRange));
    assert_eq!(parse_port("65536"), Err(PortError::OutOfRange));
}
