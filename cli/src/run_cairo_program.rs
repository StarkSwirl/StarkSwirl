use std::fmt::Error;
use std::fs;
use cairo1_run::{Cairo1RunConfig, cairo_run_program, FuncArg};
use cairo_vm::types::layout_name::LayoutName;

pub fn run_program(args: &[FuncArg]) -> Result<(), Error> {
    let cairo_run_config = Cairo1RunConfig { layout: LayoutName::recursive_with_poseidon, args, proof_mode: true, ..Default::default() };
    let program_content = match fs::read("cli.sierra.json") {
        Ok(content) => content,
        Err(_) => panic!("There is no sierra program in the current folder")
    };

    let sierra_program = match serde_json::from_slice(&program_content) {
        Ok(program) => program,
        Err(_) => panic!("Invalid program format")
    };
    let mut cairo_runner = cairo_run_program(&sierra_program, cairo_run_config).unwrap();

    let mut output_buffer = "Program Output:\n".to_string();
    cairo_runner.0.vm.write_output(&mut output_buffer).unwrap();
    print!("{output_buffer}");
    
    Ok(())
}
