#[derive(Debug, PartialEq, Eq)]
pub enum PortError {
    Empty,
    Invalid,
    OutOfRange,
}

pub fn parse_port(value: &str) -> Result<u16, PortError> {
    let value = value.trim();
    if value.is_empty() {
        return Err(PortError::Empty);
    }
    if !value.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err(PortError::Invalid);
    }
    let parsed = value.parse::<u32>().map_err(|_| PortError::OutOfRange)?;
    if !(1..=u16::MAX as u32).contains(&parsed) {
        return Err(PortError::OutOfRange);
    }
    Ok(parsed as u16)
}
