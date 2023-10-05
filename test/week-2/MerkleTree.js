import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

const values = [
    ["0x0000000000000000000000000000000000001001", 1],
    ["0x0000000000000000000000000000000000001002", 2],
    ["0x0000000000000000000000000000000000001003", 3],
    ["0x0000000000000000000000000000000000001004", 4],
    ["0x0000000000000000000000000000000000001005", 5]
];

function generateRoot() {
      const tree = StandardMerkleTree.of(values, ["address", "uint256"]);
      console.log('Merkle Root:', tree.root);
      fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));
}

function getProof() {
    const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json", "utf8")));

    for (const [i, v] of tree.entries()) {
    const proof = tree.getProof(i);
    console.log('Value:', v);
    console.log('Proof:', proof);
    }
}


generateRoot()
// 0x7ac231947135471a6af7f1b944c422bac53b5eee7759b82171feadff411a423f

getProof()
// Value: [ '0x0000000000000000000000000000000000001001', '1' ]
// Proof: [
//   '0xc4a4487caaaaa1fd5f6a29a75cb3cad10e405d17052c36a1a12dbf1beb67d2b5',
//   '0x77ceaa9a6b391c16a2ef5ff8d0586361c6aaad37062e9af77f9efdec30d06b8f'
// ]
// Value: [ '0x0000000000000000000000000000000000001002', '2' ]
// Proof: [
//   '0x967ebca7ecce097d70b8baf32cd4b8df5d90d63758c72af16a8ff93987e9d99e',
//   '0xd7aea9f1542f8d29a90e5cd76b68c53234f175c0c223968de6cb9bb9f7e6a05b'
// ]
// Value: [ '0x0000000000000000000000000000000000001003', '3' ]
// Proof: [
//   '0x1df37ecc76ddacb47d721470b4ffa1f5e86efd1856b54aeda6266e14804b3f47',
//   '0xfb87a8546b051e852ad01fb1acc823d4066ae61881e2bb9ec7230d5070dba278',
//   '0x77ceaa9a6b391c16a2ef5ff8d0586361c6aaad37062e9af77f9efdec30d06b8f'
// ]
// Value: [ '0x0000000000000000000000000000000000001004', '4' ]
// Proof: [
//   '0x886322874472ea135ea840331d9d2011f6099abaea004a2a3173fdc15702f5f1',
//   '0xfb87a8546b051e852ad01fb1acc823d4066ae61881e2bb9ec7230d5070dba278',
//   '0x77ceaa9a6b391c16a2ef5ff8d0586361c6aaad37062e9af77f9efdec30d06b8f'
// ]
// Value: [ '0x0000000000000000000000000000000000001005', '5' ]
// Proof: [
//   '0xbf5d6c48a3995a0027f6c16da483f9bf63d91f634bbe2e283d78bf602bfc0cac',
//   '0xd7aea9f1542f8d29a90e5cd76b68c53234f175c0c223968de6cb9bb9f7e6a05b'
// ]