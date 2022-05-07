const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const tokens = require("./whitelist_addresses.json");

async function main() {
    let tab = [];
    tokens.map((token) => {
        tab.push(token.address);
    });
    const leaves = tab.map((address) => keccak256(address));
    const tree = new MerkleTree(leaves, keccak256, { sort: true });
    const root = tree.getHexRoot();
    const leaf = keccak256("0x292398ce6f4806420347854Ad42BeBd80Fb81d78");
    const proof = tree.getHexProof(leaf);
    console.log("root : " + root);
    console.log("proof : " + proof);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });



