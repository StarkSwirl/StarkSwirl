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




```bash
cd tools/

./cairo1-run ../src/lib.cairo \
    --layout recursive \
    --air_public_input ../public_input.json \
    --air_private_input ../private_input.json \
    --trace_file ../trace \
    --memory_file ../memory \
    --proof_mode \
    --args '10 11 1185026453756345180447389579861961357449548829146247015391369301029199699166 2308695618287988771354853634984546027218391505022071524672454787070787600216 [2494688673636795699140731058621453752305163011358859803833341381092752778782 2536973504930841035827773298593592681327550267909021527759854774781372267024 3168820576294055788093137617219701204279874680027811909268770663640987151107 893557775024593676856405225307484293889203777646349164712834287110724191802] 893557775024593676856405225307484293889203777646349164712834287110724191802' 


```
