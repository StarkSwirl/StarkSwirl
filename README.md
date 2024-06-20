# StarkSwirl




Compile and run the program to generate the prover input files:
```bash
cd tools

./cairo1-run ../examples/fibonacci.cairo \
    --layout recursive \
    --air_public_input ../fibonacci_public_input.json \
    --air_private_input ../fibonacci_private_input.json \
    --trace_file ../fibonacci_trace \
    --memory_file ../fibonacci_memory \
    --proof_mode

cd ../
```

Run the prover:

```bash
cd tools

./cpu_air_prover \
    --out_file ../proof.json \
    --private_input_file ../fibonacci_private_input.json \
    --public_input_file ../fibonacci_public_input.json \
    --prover_config_file ./cpu_air_prover_config.json \
    --parameter_file cpu_air_params.json \
    --generate_annotations

cd ../
```


Finally, run the verifier to verify the proof:
```bash
cd tools

./cpu_air_verifier --in_file=../fibonacci_proof.json && echo "Successfully verified example proof."

cd ../
```


### Herodotous verifier

Running the verifier locally

```bash
cd tools/herodotous

./runner --program cairo_verifier.sierra.json -c cairo1 < ../../proof.json

cd ../../
```


Starknet Proof Verification
```bash
cd tools/herodotous

./snfoundry_proof_serializer -c cairo1 <  ../../fibonacci_proof.json > ../../calldata

./1-verify-proof.sh 0x274d8165a19590bdeaa94d1dd427e2034462d7611754ab3e15714a908c60df7 ../../calldata

cd ../../
```




