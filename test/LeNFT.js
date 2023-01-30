const { RelayProvider } = require('@opengsn/provider')
const { GsnTestEnvironment } = require('@opengsn/dev')
const { LazyMinter } = require('../lib/LazyMinter')

const { expect } = require("chai");

const Web3HttpProvider = require( 'web3-providers-http')

const RelayHubAbi = require('../abi/RelayHub.json')
const nftAbi = require('../artifacts/contracts/LeNFT.sol/LeNFT');

describe("LeNFT", function () {
  let nftAddress, nft, nftFactory, paymaster, utility, redeem, relayHub, nftTest;
  const price = ethers.utils.parseUnits('0.01', 'ether'); 
  let owner, user, receiver
  let forwarderAddress, relayHubAddress
  let minterRole

  const web3provider = new Web3HttpProvider('http://localhost:8545')
  const provider= new ethers.providers.Web3Provider(web3provider)

  let redeemProvider

  before(async () => {
    ([owner, user, receiver] = await ethers.getSigners())
    console.log({owner, user})

    let env = await GsnTestEnvironment.startGsn('localhost')

	  const gsnEnv = env.contractsDeployment
    forwarderAddress = gsnEnv.forwarderAddress
    relayHubAddress = gsnEnv.relayHubAddress

    relayHub = new ethers.Contract(relayHubAddress, RelayHubAbi, provider)

    const NFT = await ethers.getContractFactory("LeNFT");
    nft = await NFT.deploy();
    await nft.deployed();
    console.log('LeNFT: ', nft.address)

    const NFTFactory = await ethers.getContractFactory("LeNFTFactory");
    nftFactory = await NFTFactory.deploy(nft.address)
    await nftFactory.deployed();
    console.log('LeNFTFactory: ', nftFactory.address)

    await nftFactory.createNFT('LeTest', 'LETEST', 'http://localhost/')
    nftAddress = await nftFactory.getLatestNFT()
    // console.log(nftAddress)
    console.log('LeTest: ', nftAddress)

    const Paymaster = await ethers.getContractFactory("LeNFTPaymaster");
    paymaster = await Paymaster.deploy()
    await paymaster.deployed()
    console.log('LeNFTPaymaster: ', paymaster.address)

    await paymaster.setTrustedForwarder(forwarderAddress)
    await paymaster.setRelayHub(relayHubAddress)

    const Utility = await ethers.getContractFactory("LeNFTUtility");
    utility = await Utility.deploy(nftAddress, price, receiver.address, paymaster.address)
    await utility.deployed()
    console.log('LeNFTUtility: ', utility.address)

    const Redeem = await ethers.getContractFactory("LeNFTRedeem");
    redeem = await Redeem.deploy(forwarderAddress, nftAddress)
    await redeem.deployed()
    console.log('LeNFTRedeem: ', redeem.address)

    minterRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"))
    console.log({minterRole})

    // grant minter role
    nftTest = new ethers.Contract(nftAddress, nftAbi.abi, owner)
    const name = await nftTest.name()
    console.log({name})
    await nftTest.grantRole(minterRole, redeem.address)

    // relay provider setup
    const config = await {
      loggerConfiguration: { logLevel: 'error'},
      paymasterAddress: paymaster.address,
      auditorsCount: 0
    }
    let gsnProvider = await RelayProvider.newProvider({provider: web3provider, config}).init()

    redeemProvider = new ethers.providers.Web3Provider(gsnProvider)
    redeem = redeem.connect(redeemProvider.getSigner(user.address))
  });

  it("Mint", async function () {
    utility = utility.connect(user)
    await expect(utility.purchase(1, {
      value: price,
      //gasLimit: 3000000
    })).to.emit(utility, 'Purchased').withArgs(user.address, 1);

    // receiver wallet balance
    const balance = await provider.getBalance(receiver.address);
    expect(balance)
      .to
      .equal(ethers.utils.parseUnits('10000.005', 'ether'));

    // relayhub balance
    const relayBalance = await relayHub.balanceOf(paymaster.address)
    expect(relayBalance)
      .to
      .equal(ethers.utils.parseUnits('0.005', 'ether'));
  })

  it("Redeem", async function () {
    const balance = await provider.getBalance(user.address);

    const lazyMinter = new LazyMinter({ contractAddress: redeem.address, signer: user })
    const { voucher, signature } = await lazyMinter.createVoucher(1, "12345")

    console.log({ voucher, signature})

    await expect(redeem.redeem(voucher, signature, {
      gasLimit: 3000000
    }))
      .to.emit(redeem, 'Redeem')
      .withArgs(user.address, 1, "12345")

    const ownerOf = await nftTest.ownerOf(1)
    expect(ownerOf).to.equal(user.address)

    const balance2 = await provider.getBalance(user.address);

    const relayBalance = await relayHub.balanceOf(paymaster.address)

    console.log({balance, balance2, relayBalance})

    expect(balance).to.equal(balance2)
  })
});

