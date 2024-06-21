from starknet_py.hash.utils import pedersen_hash
from poseidon_py import poseidon_hash



current = pedersen_hash(poseidon_hash.poseidon_hash_single(0), poseidon_hash.poseidon_hash_single(0))
for i in range(8):
    print(f"{i} : {current}")
    current = pedersen_hash(current, current)

