use core::fmt::Error;
use std::fs;
use std::process::Command;

pub fn run_stone_prover() -> Result<(), Error> {
    let path = fs::canonicalize("prover/cpu_air_prover").unwrap();
    let output = Command::new(path.as_os_str()).args(
        ["--out_file ../proof.json \
          --private_input_file private_input.json \
          --public_input_file public_input.json \
          --prover_config_file cpu_air_prover_config.json \
          --parameter_file cpu_air_params.json \
          --generate_annotations"]).output().unwrap();
    println!("{:}", String::from_utf8_lossy(&output.stdout));

    Ok(())
}