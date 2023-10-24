// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC777 } from "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BojackToken, TokenSaleManager } from "../../src/week-1/BondingCurve.sol";
import { ERC1363 } from "./utils/ERC1363.sol";

contract TokenSaleManagerTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);

    error Unauthorized();

    // solhint-disable-next-line max-line-length
    bytes private erc1820DeployedCode =
        hex"608060405234801561001057600080fd5b50600436106100885760003560e01c8063a41e7d511161005b578063a41e7d5114610113578063aabbb8ca14610126578063b705676514610139578063f712f3e81461015c57600080fd5b806329965a1d1461008d5780633d584063146100a25780635df8122f146100df57806365ba36c1146100f2575b600080fd5b6100a061009b366004610a3b565b61016f565b005b6100b56100b0366004610a77565b6104d2565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020015b60405180910390f35b6100a06100ed366004610a99565b610535565b610105610100366004610acc565b61067d565b6040519081526020016100d6565b6100a0610121366004610b3e565b6106b1565b6100b5610134366004610b9a565b610789565b61014c610147366004610b3e565b61082f565b60405190151581526020016100d6565b61014c61016a366004610b3e565b610902565b600073ffffffffffffffffffffffffffffffffffffffff8416156101935783610195565b335b9050336101a1826104d2565b73ffffffffffffffffffffffffffffffffffffffff1614610223576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152600f60248201527f4e6f7420746865206d616e61676572000000000000000000000000000000000060448201526064015b60405180910390fd5b7bffffffffffffffffffffffffffffffffffffffffffffffffffffffff83166102a8576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f4d757374206e6f7420626520616e204552433136352068617368000000000000604482015260640161021a565b73ffffffffffffffffffffffffffffffffffffffff8216158015906102e3575073ffffffffffffffffffffffffffffffffffffffff82163314155b15610449576040517f455243313832305f4143434550545f4d414749430000000000000000000000006020820152603401604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08184030181529082905280516020909101207f249cb3fa0000000000000000000000000000000000000000000000000000000082526004820185905273ffffffffffffffffffffffffffffffffffffffff838116602484015290919084169063249cb3fa90604401602060405180830381865afa1580156103be573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103e29190610bc4565b14610449576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f446f6573206e6f7420696d706c656d656e742074686520696e74657266616365604482015260640161021a565b73ffffffffffffffffffffffffffffffffffffffff81811660008181526020818152604080832088845290915280822080547fffffffffffffffffffffffff0000000000000000000000000000000000000000169487169485179055518692917f93baa6efbd2244243bfee6ce4cfdd1d04fc4c0e9a786abd3a41313bd352db15391a450505050565b73ffffffffffffffffffffffffffffffffffffffff818116600090815260016020526040812054909116610504575090565b5073ffffffffffffffffffffffffffffffffffffffff9081166000908152600160205260409020541690565b919050565b3361053f836104d2565b73ffffffffffffffffffffffffffffffffffffffff16146105bc576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152600f60248201527f4e6f7420746865206d616e616765720000000000000000000000000000000000604482015260640161021a565b8173ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16146105f557806105f8565b60005b73ffffffffffffffffffffffffffffffffffffffff83811660008181526001602052604080822080547fffffffffffffffffffffffff0000000000000000000000000000000000000000169585169590951790945592519184169290917f605c2dbf762e5f7d60a546d42e7205dcb1b011ebc62a61736a57c9089d3a43509190a35050565b60008282604051602001610692929190610bdd565b6040516020818303038152906040528051906020012090505b92915050565b6106bb828261082f565b6106c65760006106c8565b815b73ffffffffffffffffffffffffffffffffffffffff9283166000818152602081815260408083207fffffffff000000000000000000000000000000000000000000000000000000009690961680845295825280832080547fffffffffffffffffffffffff000000000000000000000000000000000000000016959097169490941790955590815260028452818120928152919092522080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001179055565b60008073ffffffffffffffffffffffffffffffffffffffff8416156107ae57836107b0565b335b90507bffffffffffffffffffffffffffffffffffffffffffffffffffffffff83166107f657826107e08282610902565b6107eb5760006107ed565b815b925050506106ab565b73ffffffffffffffffffffffffffffffffffffffff90811660009081526020818152604080832086845290915290205416905092915050565b6000808061085d857f01ffc9a7000000000000000000000000000000000000000000000000000000006109ca565b909250905081158061086d575080155b1561087d576000925050506106ab565b6108a7857fffffffff000000000000000000000000000000000000000000000000000000006109ca565b90925090508115806108b857508015155b156108c8576000925050506106ab565b6108d285856109ca565b90925090506001821480156108e75750806001145b156108f7576001925050506106ab565b506000949350505050565b73ffffffffffffffffffffffffffffffffffffffff821660009081526002602090815260408083207fffffffff000000000000000000000000000000000000000000000000000000008516845290915281205460ff1661096d57610966838361082f565b90506106ab565b5073ffffffffffffffffffffffffffffffffffffffff8083166000818152602081815260408083207fffffffff00000000000000000000000000000000000000000000000000000000871684529091529020549091161492915050565b6040517f01ffc9a7000000000000000000000000000000000000000000000000000000008082526004820183905260009182919060208160248189617530fa905190969095509350505050565b803573ffffffffffffffffffffffffffffffffffffffff8116811461053057600080fd5b600080600060608486031215610a5057600080fd5b610a5984610a17565b925060208401359150610a6e60408501610a17565b90509250925092565b600060208284031215610a8957600080fd5b610a9282610a17565b9392505050565b60008060408385031215610aac57600080fd5b610ab583610a17565b9150610ac360208401610a17565b90509250929050565b60008060208385031215610adf57600080fd5b823567ffffffffffffffff80821115610af757600080fd5b818501915085601f830112610b0b57600080fd5b813581811115610b1a57600080fd5b866020828501011115610b2c57600080fd5b60209290920196919550909350505050565b60008060408385031215610b5157600080fd5b610b5a83610a17565b915060208301357fffffffff0000000000000000000000000000000000000000000000000000000081168114610b8f57600080fd5b809150509250929050565b60008060408385031215610bad57600080fd5b610bb683610a17565b946020939093013593505050565b600060208284031215610bd657600080fd5b5051919050565b818382376000910190815291905056";

    TokenSaleManager private manager;
    BojackToken private bojackToken;

    // setting up test token
    IERC20 private testToken = new ERC20("Test Token", "TT");
    ERC777 private token777;
    ERC1363 private token1363;

    // setting up test users
    address private testUser = makeAddr("testUser");
    address private anotherUser = makeAddr("anotherUser");

    function setUp() public {
        vm.etch(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24, erc1820DeployedCode);
        token777 = new ERC777("Test Token777", "TT777", new address[](0));
        token1363 = new ERC1363("Test Token1363", "TT1363");

        manager = new TokenSaleManager();
        bojackToken = manager.token();
    }

    function testFuzz_CalculateAvgPrice(uint256 depositAmount) public {
        vm.assume(depositAmount < type(uint112).max);
        uint256 quotePrice = manager.calculateAvgPrice(depositAmount);
        uint256 expectedResult = Math.average(Math.sqrt(depositAmount * 2e18 / 100), 0);
        assertEq(quotePrice, expectedResult);
    }

    function test_Buy_WhenInitialPriceIsZero() public {
        uint256 depositAmount = 500e18;

        deal(address(testToken), testUser, depositAmount);
        vm.startPrank(testUser);
        testToken.approve(address(manager), depositAmount);

        vm.expectEmit(true, true, false, true);
        // should emit ~158e16 amount
        emit Transfer(address(0), testUser, 316_227_766_016_837_933_100);
        manager.buy(depositAmount, address(testToken));

        vm.stopPrank();

        // check for BojackToken balance. minted amount should be depositAmount*2/sqrt(10)
        assertEq(bojackToken.balanceOf(testUser), 316_227_766_016_837_933_100);
        assertEq(bojackToken.totalSupply(), 316_227_766_016_837_933_100);
        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e15, 3162);
    }

    modifier whenInitialPriceIsNotZero() {
        test_Buy_WhenInitialPriceIsZero();
        _;
    }

    function test_Buy() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(testToken), anotherUser, 10_000e18);
        vm.startPrank(anotherUser);
        testToken.approve(address(manager), 10_000e18);

        manager.buy(10_000e18, address(testToken));
        vm.stopPrank();

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
    }

    function test_Buy_SmallAmounts() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(testToken), anotherUser, 10_000e18);
        vm.startPrank(anotherUser);
        testToken.approve(address(manager), 10_000e18);
        manager.buy(1e18, address(testToken));
        vm.stopPrank();

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 316_069_810_050_346_400);
        assertEq(bojackToken.totalSupply(), prevSupply + 316_069_810_050_346_400);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e15, 3165);
    }

    function test_ERC777_Implementation() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(token777), anotherUser, 10_000e18);
        vm.prank(anotherUser);
        token777.send(address(manager), 10_000e18, "");

        // check for token777 balances
        assertEq(token777.balanceOf(anotherUser), 0);
        assertEq(token777.balanceOf(address(manager)), 10_000e18);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
    }

    function test_ERC1363_TransferReceived() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(token1363), anotherUser, 10_000e18);

        vm.startPrank(anotherUser);
        token1363.transferAndCall(address(manager), 10_000e18, "");
        vm.stopPrank();

        // check for token1363 balances
        assertEq(token1363.balanceOf(anotherUser), 0);
        assertEq(token1363.balanceOf(address(manager)), 10_000e18);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
    }

    function test_ERC1363_ApprovalReceived() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(token1363), anotherUser, 10_000e18);

        vm.startPrank(anotherUser);
        token1363.approveAndCall(address(manager), 10_000e18, "");
        vm.stopPrank();

        // check for token1363 balances
        assertEq(token1363.balanceOf(anotherUser), 0);
        assertEq(token1363.balanceOf(address(manager)), 10_000e18);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
    }

    function test_Sell() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();
        uint256 prevTokenbalance = testToken.balanceOf(address(manager));

        vm.startPrank(testUser);
        manager.sell(100e18, address(testToken));

        uint256 expectedNewSupply = prevSupply - 100e18;

        vm.stopPrank();

        // check for erc20 balances
        assertEq(testToken.balanceOf(testUser), 266_227_766_016_837_933_100);
        assertEq(testToken.balanceOf(address(manager)), prevTokenbalance - 266_227_766_016_837_933_100);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(testUser), expectedNewSupply);
        assertEq(bojackToken.totalSupply(), expectedNewSupply);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 216);
    }

    function test_Sell_RevertWhenRandomERC20() public whenInitialPriceIsNotZero {
        IERC20 randomToken = new ERC20("Random Token", "RT");

        vm.prank(testUser);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        manager.sell(100e18, address(randomToken));

        // check current price of the BojackToken. should be same as before
        assertEq(manager.getCurrentPrice() / 1e16, 316);
    }

    function test_TransferManager() public {
        // fail is msg.sendeer is not manager
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        bojackToken.transferManager(makeAddr("newManager"));

        // success
        vm.prank(address(manager));
        bojackToken.transferManager(makeAddr("newManager"));
    }

    function test_RevertWhenUnauthorized_Mint() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        bojackToken.mint(address(this), 1);
    }
}
