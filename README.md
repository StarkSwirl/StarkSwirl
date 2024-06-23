# StarkSwirl

![StarkSwirl](logo.png)

StarkSwirl is a privacy preserving token mixer that allow users to use the public blockchain Starknet and keep their privacy.


In order to interact with the application you need to generate two secret numbers, you can do that on the web page, or you can use another random number generator that you trust. These two random numbers will be hashed together and will be send to the on-chain contract together with the tokens. The user should keep the numbers into a safe place because they will be used in the withdrawal process. Submitting just the hash of these numbers nobody can guess the numbers, or revert the hash, this property is called collision-resistant. Now the deposit is complete.

When the user want to withdraw the tokens from the contract he can do it from another wallet an nobody could link these two wallets. In order to withdraw, the user will input the secret numbers into a local script that he will run on his trusted computer. Nobody can see these numbers, but the script will generate a zk proof that will attend the fact that the user know two numbers that when are hashed together it will result in a specific hash that is stored on-chain in a merkle tree in the contract.
With this proof and nothing more, the user can withdraw tokens from any address that he want, without revealing any information that will link to the initial deposit address

### Step 1: Compile and run the program to generate the prover input files:
```bash
cd tools && ./cairo1-run ../src/lib.cairo \
    --layout recursive \
    --air_public_input ../public_input.json \
    --air_private_input ../private_input.json \
    --trace_file ../trace \
    --memory_file ../memory \
    --proof_mode

cd ../
```

### Step 2: Generate the cpu_air_params
```bash
python3 ./tools/fri_step_list.py public_input.json ./tools/new_cpu_air_params.json
```

### Step 3: Run the prover:

```bash
cd tools && ./cpu_air_prover \
    --out_file ../proof.json \
    --private_input_file ../private_input.json \
    --public_input_file ../public_input.json \
    --prover_config_file ./cpu_air_prover_config.json \
    --parameter_file cpu_air_params.json \
    --generate_annotations

cd ../
```
Now you can take the proof.json and submit it to the StarkSwirl web and make the withdraw


## If you want to test the proof locally here is what you need to do

#### Finally, run the verifier to verify the proof:
```bash
cd tools

./cpu_air_verifier --in_file=../proof.json && echo "Successfully verified example proof."

cd ../
```


#### Check on local with Herodotous verifier

Running the verifier locally

```bash
cd tools/herodotous && ./runner --program cairo_verifier.sierra.json -c cairo1 < ../../proof.json

cd ../../
```


#### Check on-chain with Herodotous Starknet Proof Verification
```bash
cd tools/herodotous && ./snfoundry_proof_serializer -c cairo1 <  ../../fibonacci_proof.json > ../../calldata

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
