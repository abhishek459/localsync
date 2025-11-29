use anyhow::{Context, Result};
use byteorder::{ByteOrder, LittleEndian};
use chacha20poly1305::{
    aead::{Aead, KeyInit},
    Key, XChaCha20Poly1305, XNonce,
};
use flutter_rust_bridge::frb;
use std::fs::File;
use std::io::{BufReader, BufWriter, Read, Write};
use zeroize::{Zeroize, ZeroizeOnDrop};

const CHUNK_SIZE: usize = 16 * 1024 * 1024; // 16MB chunks
const TAG_SIZE: usize = 16; // Poly1305 MAC tag size

#[derive(Zeroize, ZeroizeOnDrop)]
pub struct SecureKey(Vec<u8>);

#[frb(dart_metadata = ("freezed"))]
pub struct EncryptionResult {
    pub nonce: Vec<u8>, // We return the BASE nonce
}

pub fn encrypt_file_stream(
    input_path: String,
    output_path: String,
    key_bytes: Vec<u8>,
) -> Result<EncryptionResult> {
    let secure_key = SecureKey(key_bytes);
    if secure_key.0.len() != 32 {
        return Err(anyhow::anyhow!("Invalid key length"));
    }

    // 1. Setup XChaCha20Poly1305
    let key = Key::from_slice(&secure_key.0);
    let cipher = XChaCha20Poly1305::new(key);

    // 2. Generate Base Nonce
    let mut nonce_bytes = [0u8; 24];
    rand::Rng::fill(&mut rand::thread_rng(), &mut nonce_bytes[0..20]);
    // nonce_bytes[20..24] is the counter, starts at 0

    // 3. Open Files
    let input_file = File::open(&input_path).context("Open input failed")?;
    let mut reader = BufReader::with_capacity(CHUNK_SIZE, input_file);

    let temp_path = format!("{}.tmp", output_path);
    let output_file = File::create(&temp_path).context("Create output failed")?;
    let mut writer = BufWriter::with_capacity(CHUNK_SIZE + TAG_SIZE, output_file);

    // 4. Streaming Loop
    // Initialize buffer with zeros to reuse memory
    let mut buffer = vec![0u8; CHUNK_SIZE];
    let mut chunk_counter: u32 = 0;

    loop {
        // Read into the existing buffer slice, overwriting previous data
        let read_count = reader.read(&mut buffer).context("Read failed")?;
        if read_count == 0 {
            break; // EOF
        }

        // Construct Nonce
        let mut chunk_nonce = nonce_bytes;
        LittleEndian::write_u32(&mut chunk_nonce[20..24], chunk_counter);
        let nonce = XNonce::from_slice(&chunk_nonce);

        // Encrypt
        let encrypted_chunk = cipher
            .encrypt(nonce, &buffer[..read_count])
            .map_err(|e| anyhow::anyhow!("Encryption failed at chunk {}: {}", chunk_counter, e))?;

        writer.write_all(&encrypted_chunk).context("Write failed")?;

        // Secure cleanup of plaintext in buffer (Optional but recommended)
        buffer[..read_count].zeroize();

        chunk_counter = chunk_counter
            .checked_add(1)
            .ok_or_else(|| anyhow::anyhow!("File too large (counter overflow)"))?;
    }

    writer.flush()?;
    drop(writer);
    std::fs::rename(&temp_path, &output_path).context("Rename failed")?;

    Ok(EncryptionResult {
        nonce: nonce_bytes.to_vec(),
    })
}

pub fn decrypt_file_stream(
    input_path: String,
    output_path: String,
    nonce_bytes: Vec<u8>,
    key_bytes: Vec<u8>,
) -> Result<()> {
    let secure_key = SecureKey(key_bytes);
    if secure_key.0.len() != 32 {
        return Err(anyhow::anyhow!("Invalid key length"));
    }
    if nonce_bytes.len() != 24 {
        return Err(anyhow::anyhow!("Invalid nonce length"));
    }

    let key = Key::from_slice(&secure_key.0);
    let cipher = XChaCha20Poly1305::new(key);

    let input_file = File::open(&input_path).context("Open input failed")?;
    let mut reader = BufReader::with_capacity(CHUNK_SIZE + TAG_SIZE, input_file);

    let temp_path = format!("{}.tmp", output_path);
    let output_file = File::create(&temp_path).context("Create output failed")?;
    let mut writer = BufWriter::with_capacity(CHUNK_SIZE, output_file);

    // FIX: Use with_capacity (len=0), NOT vec![0; N] (len=N)
    // This allows read_to_end to append correctly from index 0 after clear()
    let mut buffer = Vec::with_capacity(CHUNK_SIZE + TAG_SIZE);
    let mut chunk_counter: u32 = 0;

    loop {
        // FIX: Clear buffer before reading.
        // This resets length to 0 but keeps the allocated memory capacity.
        buffer.clear();

        let mut handle = reader.by_ref().take((CHUNK_SIZE + TAG_SIZE) as u64);

        // read_to_end appends to the vector. Since we cleared it, it starts at 0.
        let read_count = handle.read_to_end(&mut buffer)?;

        if read_count == 0 {
            break; // EOF
        }

        if read_count < TAG_SIZE {
            return Err(anyhow::anyhow!("Corrupt file: Chunk smaller than MAC tag"));
        }

        let mut chunk_nonce_bytes = [0u8; 24];
        chunk_nonce_bytes.copy_from_slice(&nonce_bytes);
        LittleEndian::write_u32(&mut chunk_nonce_bytes[20..24], chunk_counter);
        let nonce = XNonce::from_slice(&chunk_nonce_bytes);

        // Decrypt
        let plaintext = cipher
            .decrypt(nonce, buffer.as_ref()) // buffer is now exactly the size of read data
            .map_err(|e| anyhow::anyhow!("Decryption failed at chunk {}: {}", chunk_counter, e))?;

        writer.write_all(&plaintext)?;

        // Secure cleanup: Plaintext vector created by decrypt needs wiping
        // (The `plaintext` var is a Vec<u8> returned by the cipher, we drop it here,
        // but Rust doesn't zeroize standard Vecs on drop automatically.
        // For "Perfect" security, we rely on the OS, or we could wrap it,
        // but standard practice usually accepts this short-lived vec.)

        chunk_counter += 1;
    }

    writer.flush()?;
    drop(writer);
    std::fs::rename(&temp_path, &output_path)?;

    Ok(())
}
