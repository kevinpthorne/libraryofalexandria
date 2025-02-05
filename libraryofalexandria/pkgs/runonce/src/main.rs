use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::process::{Command, Stdio};
use sha2::{Digest, Sha256};
use hex::encode;

fn get_job_id(entire_command: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input_string.as_bytes());
    let result = hasher.finalize();
    let hex_hash = encode(result);
    hex_hash
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <command> [args...]", args[0]);
        std::process::exit(1);
    }

    let entire_command = args.join(" ");
    let command = args.remove(1); // Remove the command from the argument list
    let job_id = get_job_id(&entire_command);
    let marker_file_path = format!("/var/local/runonce/.{}-{}-ran", command.replace("/", "_"), job_id);

    // Create the marker file directory if it doesn't exist
    fs::create_dir_all(Path::new(&marker_file_path).parent().unwrap())?;

    // Check if the command has already been run successfully
    if Path::new(&marker_file_path).exists() {
        println!("Command '{}' has already been run successfully.", entire_command);
        return Ok(());
    }

    // Run the command with arguments
    let output = Command::new(&command)
        .args(&args) // Pass remaining arguments to the command
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()?;

    // Print stdout and stderr
    io::stdout().write_all(&output.stdout)?;
    io::stderr().write_all(&output.stderr)?;

    // Create the marker file to indicate successful completion
    fs::File::create(&marker_file_path)?;

    Ok(())
}