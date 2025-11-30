use anyhow::Result;
use flutter_rust_bridge::frb;
use rcgen::{string::Ia5String, CertificateParams, DistinguishedName, DnType, KeyPair, SanType};
use sha2::{Digest, Sha256};
use time::{Duration, OffsetDateTime};

#[frb(non_final)]
pub struct LocalIdentity {
    pub device_id: String,
    pub device_name: String,
    pub private_key_pem: String,
    pub certificate_pem: String,
}

pub fn generate_identity(display_name: String) -> Result<LocalIdentity> {
    // 1. Generate KeyPair (ECDSA P-256)
    let key_pair = KeyPair::generate()?;

    // 2. Configure Certificate
    // Start with empty SANs to avoid auto-parsing errors in `new`
    let mut params = CertificateParams::new(vec![])?;

    // Validity: 100 Years
    let now = OffsetDateTime::now_utc();
    params.not_before = now;
    params.not_after = now + Duration::days(365 * 100);

    // Distinguished Name (Common Name supports UTF-8)
    params.distinguished_name = DistinguishedName::new();
    params
        .distinguished_name
        .push(DnType::CommonName, &display_name);
    params
        .distinguished_name
        .push(DnType::OrganizationName, "LocalSync P2P Mesh");

    // 3. Configure Subject Alternative Names (DNS Names)
    // These MUST be IA5String (Strict ASCII).

    // Standard local fallback
    let local_dns = Ia5String::try_from("localsync.local")?;
    let mut sans = vec![SanType::DnsName(local_dns)];

    // Attempt to add the display name as a DNS SAN if it's valid ASCII.
    // If user's name is "Jürgen's iPhone", this fails, so we skip adding it to SANs
    // (It will still appear in the Common Name above).
    if let Ok(ascii_name) = Ia5String::try_from(display_name.clone()) {
        sans.push(SanType::DnsName(ascii_name));
    }

    params.subject_alt_names = sans;

    // 4. Generate Certificate
    let cert = params.self_signed(&key_pair)?;

    // 5. Export PEMs
    let certificate_pem = cert.pem();
    let private_key_pem = key_pair.serialize_pem();

    // 6. Calculate Fingerprint
    let mut hasher = Sha256::new();
    hasher.update(cert.der());
    let fingerprint_bytes = hasher.finalize();
    let fingerprint = hex::encode(fingerprint_bytes);

    Ok(LocalIdentity {
        device_id: fingerprint,
        device_name: display_name,
        private_key_pem,
        certificate_pem,
    })
}
