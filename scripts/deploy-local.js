// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const Web3HttpProvider = require( 'web3-providers-http')

const LeNFT = require('../artifacts/contracts/LeNFT.sol/LeNFT.json')
const LeNFTFactory = require('../artifacts/contracts/LeNFTFactory.sol/LeNFTFactory.json')
const LeNFTPaymaster = require('../artifacts/contracts/LeNFTPaymaster.sol/LeNFTPaymaster.json')
const LeNFTUtility = require('../artifacts/contracts/LeNFTUtility.sol/LeNFTUtility.json')
const LeNFTRedeem = require('../artifacts/contracts/LeNFTRedeem.sol/LeNFTRedeem.json')
const nftAbi = require('../artifacts/contracts/LeNFT.sol/LeNFT');

async function main() {
  const price = ethers.utils.parseUnits('0.01', 'ether')
  const accounts = await ethers.getSigners()

  const web3provider = new Web3HttpProvider('http://localhost:8545')
 
  const deploymentProvider= new ethers.providers.Web3Provider(web3provider)
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, deploymentProvider)

  await accounts[0].sendTransaction({to: signer.address, value: ethers.utils.parseUnits('1', 'ether')})

  const NFT = new ethers.ContractFactory(LeNFT.abi, LeNFT.bytecode, signer)

  const nft = await NFT.deploy();
  await nft.deployed();
  console.log('LeNFT: ', nft.address)

  const NFTFactory = new ethers.ContractFactory(LeNFTFactory.abi, LeNFTFactory.bytecode, signer)
  const nftFactory = await NFTFactory.deploy(nft.address)
  await nftFactory.deployed();
  console.log('LeNFTFactory: ', nftFactory.address)

  await nftFactory.createNFT('LeFish', 'LEFISH', 'https://fluence.xfero.io/db/')
  const nftAddress = await nftFactory.getLatestNFT()
  // console.log(nftAddress)
  console.log('LeTest: ', nftAddress)

  const Paymaster = new ethers.ContractFactory(LeNFTPaymaster.abi, LeNFTPaymaster.bytecode, signer)
  const paymaster = await Paymaster.deploy()
  await paymaster.deployed()
  console.log('LeNFTPaymaster: ', paymaster.address)

  await paymaster.setTrustedForwarder(process.env.FORWARDER)
  await paymaster.setRelayHub(process.env.RELAY_HUB)

  const Utility = new ethers.ContractFactory(LeNFTUtility.abi, LeNFTUtility.bytecode, signer)
  const utility = await Utility.deploy(nftAddress, price, process.env.RECEIVER, paymaster.address)
  await utility.deployed()
  console.log('LeNFTUtility: ', utility.address)

  const Redeem = new ethers.ContractFactory(LeNFTRedeem.abi, LeNFTRedeem.bytecode, signer)
  const redeem = await Redeem.deploy(process.env.FORWARDER, nftAddress)
  await redeem.deployed()
  console.log('LeNFTRedeem: ', redeem.address)

  minterRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"))
  console.log({minterRole})

  // grant minter role
  const nftTest = new ethers.Contract(nftAddress, nftAbi.abi, signer)
  const name = await nftTest.name()
  console.log({name})
  await nftTest.grantRole(minterRole, redeem.address)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
