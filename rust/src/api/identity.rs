use anyhow::Result;
use flutter_rust_bridge::frb;
use hex;
use sha2::{Digest, Sha256};

#[frb(non_final)]
pub struct LocalIdentity {
    pub device_id: String,
}

pub fn generate_identity_simple(mnemonic: String) -> Result<LocalIdentity> {
    let mut hasher = Sha256::new();
    hasher.update(mnemonic.as_bytes());
    let result = hasher.finalize();
    let device_id = hex::encode(result);
    Ok(LocalIdentity { device_id })
}
