// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "./BaseSetup.t.sol";
import "../src/BofRouterFactory.sol";
import "../src/AccountRegistry.sol";
import "../src/RouterProxyAdmin.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";


contract MockVault is VaultAPI{
    address public token;
    uint256 public balance;
    constructor (address _token) {
        token = _token;
        balance = 0;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balance;
    }

    function deposit(uint256 amount) external returns (uint256) {
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        balance += amount;
        return amount;
    }

    function withdraw(uint256 amount) external returns (uint256) {
        ERC20(token).transfer(msg.sender, amount);
        balance -= amount;
        return amount;
    }

    function pricePerShare() external pure returns (uint256) {
        return 1;
    }

    function decimals() external pure returns (uint256) {
        return 1;
    }
    
}

contract MockImmersve {
    address public usdc;
	
    uint256 public balance;
    uint256 public lockedFunds;
    constructor (address _usdc) {
        balance = 0;
        lockedFunds = 0;
        usdc = _usdc;
    }

    function getBalance() external view returns (uint256) {
        return balance;
    }

    function getLockedBalance() external view returns (uint256) {
        return lockedFunds;
    }


    function deposit(uint256 amount) external returns (uint256) {
        ERC20(usdc).transferFrom(msg.sender, address(this), amount);
        balance += amount;
        return amount;
    }

    function withdraw(uint256 amount) external returns (uint256) {
        ERC20(usdc).transfer(msg.sender, amount);
        balance -= amount;
        return amount;
    }

    function createLockedFund(uint256 amount) external {
        require(amount <= balance, "!WrongAmount");
        balance -= amount;
        lockedFunds += amount;
    }
}


contract SimpleToken is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract BofRouterTest is BaseSetup {

    BofRouterFactory public routerFactory;
    address public constant random_address_1 = 0xEb9b53d7601a086661Bb02d43F5edA850d0955C2;
    address public constant random_address_2 = 0xD4EB788824779eE6AC7A8a2Cd943c41C0f3D947D;
    address public constant random_address_account_registry = 0xD123B70Ced1EEfa4d14c4dF62106E8d018f9dA8C;
    address public constant random_ownerCallProxy = 0x6F520449438c834B13321f946487A26Bc9AA14a2;
	AccountRegistry public accountRegistry;
    address public whitelister;
    MockImmersve public immersve;
    BofRouter public wallet;
    SimpleToken public token1;
    SimpleToken public token2;
    SimpleToken public fakeusdc;
    MockVault public vaultToken1;
    MockVault public vaultToken1B;
    MockVault public vaultUsdc1;

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        token1 = new SimpleToken("AAA", "AAA", 10000);
        vm.prank(user);
        token2 = new SimpleToken("BBB", "BBB", 10000);
        vm.prank(user);
        fakeusdc = new SimpleToken("Usdc", "USDC", 10000);
        whitelister = createUsers(1)[0];
        vm.label(whitelister, "whitelister");

        immersve = new MockImmersve(address(fakeusdc));
        accountRegistry = new AccountRegistry(address(fakeusdc), address(immersve));
		BofRouter routerImpl = new BofRouter();
		RouterProxyAdmin routerProxyAdmin = new RouterProxyAdmin(OwnerCallProxy(random_ownerCallProxy));
		ProxyAdmin proxyAdmin = new ProxyAdmin();
        BofRouterFactory impl = new BofRouterFactory();
		routerFactory = BofRouterFactory(address(new TransparentUpgradeableProxy(
			address(impl), 
			address(proxyAdmin), 
			abi.encodeWithSelector(
				BofRouterFactory.initialize.selector, 
				whitelister, 
				address(accountRegistry), 
				address(routerImpl),
				address(routerProxyAdmin)
			)
		)));
        routerFactory.setGovernance(gov);
        accountRegistry.setGovernance(gov);
        vm.startPrank(gov);
        routerFactory.acceptGovernance();
        accountRegistry.acceptGovernance();

        //User deploys a wallet
        vm.stopPrank();
        vm.prank(whitelister);
        routerFactory.setWhitelist(user, true);
        vm.prank(user);
        routerFactory.createWallet();
        wallet = BofRouter(routerFactory.wallets(user));

        console.log("Whitelister ", whitelister);
        console.log("RouterFactory ", address(routerFactory));
        console.log("Account registry ", address(accountRegistry));
        console.log("Wallet ", address(wallet));

        vm.startPrank(gov);

        accountRegistry.addToken(address(token1));
        //not adding token2
        accountRegistry.addToken(address(fakeusdc));

        // Deploy mock vaults
        vaultToken1 = new MockVault(address(token1));
        vaultToken1B = new MockVault(address(token1));
        vaultUsdc1 = new MockVault(address(fakeusdc));
        vm.stopPrank();

    }

    function testChangeAccountRegistry() public {
        assert(accountRegistry.gov() == wallet.gov());
        
        console.log("Account registry is: ", address(wallet.accountRegistry()));        
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        wallet.setAccountRegistry(random_address_1);
        vm.prank(gov);
        wallet.setAccountRegistry(random_address_2);
        assertEq(wallet.pendingAccountRegistry(), random_address_2);
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.acceptAccountRegistry();
        vm.prank(user);
        wallet.acceptAccountRegistry();
        assertEq(wallet.pendingAccountRegistry(), address(0));
        assertEq(address(wallet.accountRegistry()), random_address_2);
        console.log("Account registry after: ", address(wallet.accountRegistry()));          
    }

    function testTransferOwnership() public {
        //Must be called by owner
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.transferOwnership(rando);
        //Address can't be 0
        vm.prank(user);
        vm.expectRevert("Ownable: new owner is the zero address");
        wallet.transferOwnership(address(0));

        vm.prank(user);
        wallet.transferOwnership(random_address_1);

        assertEq(random_address_1, wallet.owner());
    }

    function testDeposit() public {
        //Must be called by owner
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.deposit(address(token1), address(vaultToken1), 10);

        vm.prank(user);
        token1.approve(address(wallet), 100);
        vm.prank(user);
        token2.approve(address(wallet), 100);

        //Token should be supported
        vm.prank(user);
        vm.expectRevert("!Supported");
        wallet.deposit(address(token2), address(vaultToken1), 0);

        //Vault should be supported
        vm.prank(user);
        vm.expectRevert("!Supported");
        wallet.deposit(address(token1), address(vaultToken1), 100);

        vm.prank(gov);
        accountRegistry.addVault(address(token1), address(vaultToken1));

        //Balance should be enough
        vm.prank(user);
        vm.expectRevert("ERC20: insufficient allowance");
        wallet.deposit(address(token1), address(vaultToken1), 101);

        vm.prank(user);
        wallet.deposit(address(token1), address(vaultToken1), 100);

        assertEq(token1.balanceOf(address(vaultToken1)), 100);
    }

    function testWithdraw() public {
        //Must be called by owner
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.withdraw(address(token1), address(vaultToken1), 10);

        vm.prank(user);
        token1.approve(address(wallet), 100);
        vm.prank(user);
        token2.approve(address(wallet), 100);

        //Token should be supported
        vm.prank(user);
        vm.expectRevert("!Supported");
        wallet.withdraw(address(token2), address(vaultToken1), 0);

        //Vault should be supported
        vm.prank(user);
        vm.expectRevert("!Supported");
        wallet.withdraw(address(token1), address(vaultToken1), 100);

        vm.prank(gov);
        accountRegistry.addVault(address(token1), address(vaultToken1));

        //Balance should be enough
        vm.prank(user);
        vm.expectRevert();
        wallet.withdraw(address(token1), address(vaultToken1), 101);

        vm.prank(user);
        wallet.deposit(address(token1), address(vaultToken1), 100);

        assertEq(token1.balanceOf(address(vaultToken1)), 100);

        vm.prank(user);
        wallet.withdraw(address(token1), address(vaultToken1), 100);

        assertEq(token1.balanceOf(address(vaultToken1)), 0);
        // assertEq(token1.balanceOf(address(wallet)), 100);
    }

    function testDepositImmersve() public {
        //Must be called by owner
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.deposit(address(fakeusdc), address(immersve), 10);

        vm.prank(user);
        fakeusdc.approve(address(wallet), 100);

        //Balance should be enough
        vm.prank(user);
        vm.expectRevert("ERC20: insufficient allowance");
        wallet.deposit(address(fakeusdc), address(immersve), 101);

        vm.prank(user);
        wallet.deposit(address(fakeusdc), address(immersve), 100);

        assertEq(fakeusdc.balanceOf(address(immersve)), 100);
    }

    function testWithdrawImmersve() public {
		uint256 balance = fakeusdc.balanceOf(address(user));
        //Must be called by owner
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.withdraw(address(fakeusdc), address(immersve), 10);

        vm.prank(user);
        fakeusdc.approve(address(wallet), 100);

        vm.prank(user);
        wallet.deposit(address(fakeusdc), address(immersve), 100);
        assertEq(fakeusdc.balanceOf(address(immersve)), 100);

        //Balance should be enough
        vm.prank(user);
        vm.expectRevert("!EnoughWithdraw");
        wallet.withdraw(address(fakeusdc), address(immersve), 101);

        vm.prank(user);
        wallet.withdraw(address(fakeusdc), address(immersve), 100);
        assertEq(fakeusdc.balanceOf(address(immersve)), 0);
        assertEq(fakeusdc.balanceOf(address(wallet)), 0);
        assertEq(fakeusdc.balanceOf(address(user)), balance);
    }

    function testLockAmountImmersve() public {
        //Must be called by owner
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.lockAmountImmersve(10);

        vm.prank(user);
        fakeusdc.approve(address(wallet), 100);

        vm.prank(user);
        wallet.deposit(address(fakeusdc), address(immersve), 100);
        assertEq(fakeusdc.balanceOf(address(immersve)), 100);

        //Balance should be enough
        vm.prank(user);
        vm.expectRevert("!EnoughLock");
        wallet.lockAmountImmersve(101);

        vm.prank(user);
        wallet.lockAmountImmersve(100);
        assertEq(fakeusdc.balanceOf(address(immersve)), 100);
        assertEq(immersve.getBalance(), 0);
        assertEq(immersve.getLockedBalance(), 100);
    }

    function testTransfer() public {
        vm.prank(gov);
        accountRegistry.addVault(address(token1), address(vaultToken1));
        vm.prank(gov);
        accountRegistry.addVault(address(token1), address(vaultToken1B));
        vm.prank(gov);
        accountRegistry.addVault(address(fakeusdc), address(vaultUsdc1));
        
        //Must be called by owner
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.transfer(address(token1), address(vaultToken1), address(vaultToken1B), 10);

        //Same address
        vm.startPrank(user);
        vm.expectRevert("!TransferSameAddresses");
        wallet.transfer(address(token1), address(vaultToken1), address(vaultToken1), 10);

        //Deposit something in vaultToken1
        token1.approve(address(wallet), 100);        
        wallet.deposit(address(token1), address(vaultToken1), 100);
        
        vm.expectRevert("!TransferZero");
        wallet.transfer(address(token1), address(0), address(vaultToken1), 10);
        vm.expectRevert("!TransferZero");
        wallet.transfer(address(token1), address(vaultToken1), address(0), 10);
        
        wallet.transfer(address(token1), address(vaultToken1), address(vaultToken1B), 10);

        //Now test immersve: deposit something on immersve
        fakeusdc.approve(address(wallet), 100);        
        wallet.deposit(address(fakeusdc), address(immersve), 100);

        wallet.transfer(address(fakeusdc), address(immersve), address(vaultUsdc1), 10);
        wallet.transfer(address(fakeusdc), address(vaultUsdc1), address(immersve), 10);
    }
}
