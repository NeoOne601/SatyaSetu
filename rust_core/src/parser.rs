// Adding Persistence and Security
use crate::domain::UpiIntent;
use regex::Regex;
use anyhow::{Result, anyhow};

pub fn parse_upi_url(url: &str) -> Result<UpiIntent> {
    if !url.starts_with("upi://pay") {
        return Err(anyhow!("Not a valid UPI URL"));
    }

    let re = Regex::new(r"pa=([^&]+)(?:&pn=([^&]+))?(?:&am=([^&]+))?(?:&cu=([^&]+))?").unwrap();
    
    if let Some(caps) = re.captures(url) {
        // PRINCIPAL FIX: Explicit mapping to resolve type inference E0282
        let vpa = caps.get(1).map(|m| m.as_str()).unwrap_or("").to_string();
        let name = caps.get(2).map(|m| m.as_str()).unwrap_or("").to_string();
        let amount = caps.get(3).map(|m| m.as_str()).unwrap_or("").to_string();
        let currency = caps.get(4).map(|m| m.as_str()).unwrap_or("INR").to_string();

        Ok(UpiIntent { vpa, name, amount, currency })
    } else {
        Err(anyhow!("Failed to parse UPI components"))
    }
}