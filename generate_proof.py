from starknet_py.hash.utils import pedersen_hash
from poseidon_py.poseidon_hash import poseidon_hash
from starkware.cairo.common.poseidon_utils import PoseidonParams, hades_permutation



# known commitments, in order, from the on-chain events
secret = 10
nullifier = 11 # some hard to guess random numbers
known_commitments = pedersen_hash(secret, nullifier)


elem1 = poseidon_hash(1,1)
elem2 = known_commitments
elem3 = poseidon_hash(elem1, elem2)
elem4 = poseidon_hash(4,4)
elem5 = poseidon_hash(5,5)
elem6 = poseidon_hash(elem4, elem5)
elem7 = poseidon_hash(elem3, elem6)
elem8 = poseidon_hash(8, 8)



root = poseidon_hash(8, poseidon_hash(elem7, elem8))
last_pos = 8

proof = [elem2, elem6]
peaks = [elem7, elem8]
index = 1
nullifier_hash = pedersen_hash(0, nullifier)


args = f'[{secret}, {nullifier}, "{nullifier_hash}", "{known_commitments}", "{root}", {index}, {last_pos}, {peaks}, {proof}]'
print(args)

