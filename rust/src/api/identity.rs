use anyhow::Result;
use bip39::Mnemonic;
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use flutter_rust_bridge::frb;
use hkdf::Hkdf;
use sha2::Sha256;
use std::str::FromStr;

#[frb(opaque)]
pub struct NetworkIdentity {
    /// Unique key for THIS device (TLS/Handshake)
    pub(crate) node_signing_key: SigningKey,
    pub(crate) node_verifying_key: VerifyingKey,

    /// Shared key for the Cluster (Proof of Membership)
    pub(crate) cluster_verifying_key: VerifyingKey,
    // We keep the signing key private, but we need it once to generate the proof.
    cluster_proof: Vec<u8>,
}

impl NetworkIdentity {
    pub fn from_mnemonic(phrase: &str, salt: &str) -> Result<Self> {
        let mnemonic =
            Mnemonic::from_str(phrase).map_err(|e| anyhow::anyhow!("Invalid mnemonic: {}", e))?;
        let root_seed = mnemonic.to_seed("");

        // 1. Derive CLUSTER Key (Shared across all devices)
        // No salt, so it's identical on every device.
        let hkdf_cluster = Hkdf::<Sha256>::new(None, &root_seed);
        let mut cluster_okm = [0u8; 32];
        hkdf_cluster
            .expand(b"localsync_cluster_identity_v1", &mut cluster_okm)
            .map_err(|_| anyhow::anyhow!("Cluster key derivation failed"))?;

        let cluster_signing_key = SigningKey::from_bytes(&cluster_okm);
        let cluster_verifying_key = cluster_signing_key.verifying_key();

        // 2. Derive NODE Key (Unique to this device)
        // Uses the salt (UUID) to ensure uniqueness.
        let hkdf_node = Hkdf::<Sha256>::new(Some(salt.as_bytes()), &root_seed);
        let mut node_okm = [0u8; 32];
        hkdf_node
            .expand(b"localsync_node_identity_v1", &mut node_okm)
            .map_err(|_| anyhow::anyhow!("Node key derivation failed"))?;

        let node_signing_key = SigningKey::from_bytes(&node_okm);
        let node_verifying_key = node_signing_key.verifying_key();

        // 3. Generate Cluster Proof (Self-Signed Certificate)
        // We sign our own Node Public Key using the Cluster Private Key.
        // Peer devices can verify this using their copy of the Cluster Public Key.
        let proof_signature = cluster_signing_key.sign(node_verifying_key.as_bytes());

        Ok(Self {
            node_signing_key,
            node_verifying_key,
            cluster_verifying_key,
            cluster_proof: proof_signature.to_bytes().to_vec(),
        })
    }

    pub fn public_id(&self) -> String {
        hex::encode(self.node_verifying_key.as_bytes())
    }

    /// Returns the proof that this Node belongs to the Cluster.
    pub fn get_cluster_proof(&self) -> Vec<u8> {
        self.cluster_proof.clone()
    }

    /// Verifies that a peer's Node ID was signed by OUR Cluster Key.
    pub fn verify_cluster_membership(&self, peer_node_id_hex: String, proof: Vec<u8>) -> bool {
        let peer_bytes = match hex::decode(&peer_node_id_hex) {
            Ok(b) => b,
            Err(_) => return false,
        };

        let signature = match Signature::from_slice(&proof) {
            Ok(s) => s,
            Err(_) => return false,
        };

        // We use OUR cluster key to verify THEIR proof.
        // If it passes, they possess the same Mnemonic we do.
        self.cluster_verifying_key
            .verify(&peer_bytes, &signature)
            .is_ok()
    }
}

/// Generates a new 24-word BIP39 mnemonic.
pub fn generate_mnemonic_words() -> String {
    let mnemonic = Mnemonic::generate(24).expect("Failed to generate mnemonic");
    mnemonic.to_string()
}

/// Validates if a string is a valid BIP39 mnemonic.
pub fn validate_mnemonic_words(phrase: String) -> bool {
    Mnemonic::parse(&phrase).is_ok()
}
