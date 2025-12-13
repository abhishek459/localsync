use crate::api::identity::NetworkIdentity;
use anyhow::{anyhow, Result};
use ed25519_dalek::{Signature, Signer, Verifier, VerifyingKey};

// --- TLS Certificate Generation ---
pub struct TlsConfig {
    pub key_pem: String,
    pub cert_pem: String,
}

/// Generates a self-signed X.509 certificate for the TLS handshake.
pub fn generate_ephemeral_cert() -> Result<TlsConfig> {
    let subject_alt_names = vec!["localsync.local".to_string()];

    // The function returns a CertifiedKey struct containing { cert, signing_key }
    let certified_key = rcgen::generate_simple_self_signed(subject_alt_names)?;

    Ok(TlsConfig {
        // Access the fields directly
        key_pem: certified_key.signing_key.serialize_pem(),
        cert_pem: certified_key.cert.pem(),
    })
}

/// Signs a challenge using the identity's private key.
pub fn sign_challenge(identity: &NetworkIdentity, challenge: &[u8]) -> Vec<u8> {
    let signature = identity.node_signing_key.sign(challenge);
    signature.to_bytes().to_vec()
}

/// Verifies that a response matches a known public key.
pub fn verify_response(
    public_key_hex: &str,
    challenge: &[u8],
    signature_bytes: &[u8],
) -> Result<bool> {
    let public_bytes =
        hex::decode(public_key_hex).map_err(|_| anyhow!("Invalid public key hex"))?;

    let public_bytes_array: [u8; 32] = public_bytes
        .try_into()
        .map_err(|_| anyhow!("Invalid public key length"))?;

    let verifying_key = VerifyingKey::from_bytes(&public_bytes_array)
        .map_err(|_| anyhow!("Could not build verifying key"))?;

    let signature =
        Signature::from_slice(signature_bytes).map_err(|_| anyhow!("Invalid signature format"))?;

    match verifying_key.verify(challenge, &signature) {
        Ok(_) => Ok(true),
        Err(_) => Ok(false),
    }
}
