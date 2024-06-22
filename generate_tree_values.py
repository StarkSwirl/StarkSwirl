from starknet_py.hash.utils import pedersen_hash


current = pedersen_hash(0,0)
for i in range(4):
    print(f"{i} : {current}")
    current = pedersen_hash(current, current)

