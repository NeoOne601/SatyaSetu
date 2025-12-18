use crate::domain::{InteractionType};
use regex::Regex;
use lazy_static::lazy_static;

lazy_static! {
    static ref UPI_REGEX: Regex = Regex::new(r"pa=([^&]+)&pn=([^&]+)").unwrap();
}

pub struct QrParser;

impl QrParser {
    pub fn parse_upi_string(qr_raw: &str) -> Option<(String, String)> {
        if let Some(caps) = UPI_REGEX.captures(qr_raw) {
            let vpa = caps.get(1).map_or("", |m| m.as_str()).to_string();
            let name = caps.get(2).map_or("", |m| m.as_str()).to_string();
            return Some((vpa, name));
        }
        None
    }

    pub fn determine_interaction_type(_metadata: &str) -> InteractionType {
        InteractionType::Payment 
    }
}
