pragma solidity ^0.8.18;

import {IRouterClient} from "./interfaces/IRouterClient.sol";
import {IAny2EVMMessageReceiver} from "./interfaces/IAny2EVMMessageReceiver.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import {Client} from "./libraries/Client.sol";

import {IERC165} from "./interfaces/IERC165.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/VaultAPI.sol";
import "./interfaces/IBofRouter.sol";

// @notice Example of an immutable client example which supports EVM/non-EVM chains.
// @dev If chain specific logic is required for different chain families (e.g. particular
// decoding the bytes sender for authorization checks), it may be required to point to a helper
// authorization contract unless all chain families are known up front.
// @dev If contract does not implement IAny2EVMMessageReceiver and IERC165,
// and tokens are sent to it, ccipReceive will not be called but tokens will be transferred.
// @dev If the client is upgradeable you have significantly more flexibility and
// can avoid storage based options.
contract ChainZapTUP is Initializable, OwnableUpgradeable, IAny2EVMMessageReceiver, IERC165 {
  error InvalidConfig();
  error InvalidChain(uint64 chainId);
  error OnlyRouter();
  error OnlyGov();

  event MessageSent(bytes32 messageId);
  event MessageReceived(bytes32 messageId);
  event GovernanceUpdated(address pendingGov, address gov);
  // Can consider making mutable up until mainnet.
  IRouterClient public i_router;
  // Current feeToken
  IERC20 public s_feeToken;
  address public gov;
  IBofRouter public bofRouter;
  address public pendingGov;
  uint64 homeChainId;
  // Below is a simplistic example (same params for all messages) of using storage to allow for new options without
  // upgrading the dapp. Note that extra args are chain family specific (e.g. gasLimit is EVM specific etc.).
  // and will always be backwards compatible i.e. upgrades are opt-in.
  // Offchain we can compute the V1 extraArgs:
  //    Client.EVMExtraArgsV1 memory extraArgs = Client.EVMExtraArgsV1({gasLimit: 300_000, strict: false});
  //    bytes memory encodedV1ExtraArgs = Client._argsToBytes(extraArgs);
  // Then later compute V2 extraArgs, for example if a refund feature was added:
  //    Client.EVMExtraArgsV2 memory extraArgs = Client.EVMExtraArgsV2({gasLimit: 300_000, strict: false, destRefundAddress: 0x1234});
  //    bytes memory encodedV2ExtraArgs = Client._argsToBytes(extraArgs);
  // and update storage with the new args.
  mapping(uint64 => bytes) public s_chains;

  // constructor(IRouterClient router, IERC20 feeToken, address _gov, address _bofRouter, uint64 _homeChainId ) {
  //   i_router = router;
  //   s_feeToken = feeToken;
  //   s_feeToken.approve(address(i_router), 2 ** 256 - 1);
  //   gov = _gov;
  //   bofRouter = IBofRouter(_bofRouter);
  //   homeChainId = _homeChainId;
  // }
  function initialize(
    address _owner,
    IRouterClient router, 
    IERC20 feeToken, 
    address _gov, 
    address _bofRouter, 
    uint64 _homeChainId
  ) public payable initializer {
    _transferOwnership(_owner);
    pendingGov = address(0);
    i_router = router;
    s_feeToken = feeToken;
    s_feeToken.approve(address(i_router), type(uint256).max );
    gov = _gov;
    bofRouter = IBofRouter(_bofRouter);
    homeChainId = _homeChainId;
  }

    //--- setter functions ---//
    /**
     * @dev Sets the pending governance to the provided address
     * @param newGov The address of the new pending governance
     */
    function setGovernance(address newGov) external onlyGov {
        pendingGov = newGov;
    }

    /**
     * @dev Accepts the pending governance as the new governance
     */
    function acceptGovernance() external onlyPendingGov {
        emit GovernanceUpdated(pendingGov, gov);
        gov = pendingGov;
        pendingGov = address(0);
    }

  function setCCIPRouter(address _router) external onlyGov {
    i_router = IRouterClient(_router);
  }

  function setBofRouter(address _router) external onlyGov {
    bofRouter = IBofRouter(_router);
  }

  // TODO: permissions on enableChain/disableChain
  function enableChain(uint64 chainId, bytes memory extraArgs) external onlyGov {
    s_chains[chainId] = extraArgs;
  }

  function disableChain(uint64 chainId) external onlyGov {
    delete s_chains[chainId];
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function ccipReceive(Client.Any2EVMMessage calldata message)
    external
    override
    onlyRouter
    validChain(message.sourceChainId)
  {
    // Extremely important to ensure only router calls this.
    // Tokens in message if any will be transferred to this contract
    // TODO: Validate sender/origin chain and process message and/or tokens.

    (address[] memory vaults) = abi.decode(message.data, (address[]));
    for(uint256 i = 0; i < message.tokenAmounts.length; i++){
      Client.EVMTokenAmount calldata tokenAmt = message.tokenAmounts[i];
      IERC20 token = IERC20(tokenAmt.token);
      token.approve(address(bofRouter), tokenAmt.amount);
      bofRouter.deposit(tokenAmt.token, vaults[i], tokenAmt.amount);
    }
    emit MessageReceived(message.messageId);
  }

  /// @notice sends data to receiver on dest chain. Assumes address(this) has sufficient native asset.
	//   function sendDataPayNative(
  //   uint64 destChainId,
  //   bytes memory receiver,
  //   bytes memory data
  // ) external validChain(destChainId) {
  //   Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
  //   Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
  //     receiver: receiver,
  //     data: data,
  //     tokenAmounts: tokenAmounts,
  //     extraArgs: s_chains[destChainId],
  //     feeToken: address(0) // We leave the feeToken empty indicating we'll pay raw native.
  //   });
  //   bytes32 messageId = i_router.ccipSend{value: i_router.getFee(destChainId, message)}(destChainId, message);
  //   emit MessageSent(messageId);
  // }

  /// @notice sends data to receiver on dest chain. Assumes address(this) has sufficient feeToken.
  // function sendDataPayFeeToken(
  //   uint64 destChainId,
  //   bytes memory receiver,
  //   bytes memory data
  // ) external validChain(destChainId) {
  //   Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
  //   Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
  //     receiver: receiver,
  //     data: data,
  //     tokenAmounts: tokenAmounts,
  //     extraArgs: s_chains[destChainId],
  //     feeToken: address(s_feeToken)
  //   });
  //   // Optional uint256 fee = i_router.getFee(destChainId, message);
  //   // Can decide if fee is acceptable.
  //   // address(this) must have sufficient feeToken or the send will revert.
  //   bytes32 messageId = i_router.ccipSend(destChainId, message);
  //   emit MessageSent(messageId);
  // }

  /// @notice sends data to receiver on dest chain. Assumes address(this) has sufficient native token.
  function sendDataAndTokens(
    uint64 destChainId,
    bytes memory receiver,
    bytes memory data,
    Client.EVMTokenAmount[] memory tokenAmounts
  ) public validChain(destChainId) {
    for (uint256 i = 0; i < tokenAmounts.length; i++) {
      IERC20(tokenAmounts[i].token).transferFrom(msg.sender, address(this), tokenAmounts[i].amount);
      IERC20(tokenAmounts[i].token).approve(address(i_router), tokenAmounts[i].amount);
    }
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: receiver,
      data: data,
      tokenAmounts: tokenAmounts,
      extraArgs: s_chains[destChainId],
      feeToken: address(s_feeToken)
    });
    // Optional uint256 fee = i_router.getFee(destChainId, message);
    // Can decide if fee is acceptable.
    // address(this) must have sufficient feeToken or the send will revert.
    bytes32 messageId = i_router.ccipSend(destChainId, message);
    emit MessageSent(messageId);
  }

  modifier validChain(uint64 chainId) {
    if (s_chains[chainId].length == 0) revert InvalidChain(chainId);
    _;
  }

  modifier onlyRouter() {
    if (msg.sender != address(i_router)) revert OnlyRouter();
    _;
  }
  modifier onlyGov() {
    if (msg.sender != gov) revert OnlyGov();
    _;
  }
  modifier onlyPendingGov() {
      require(msg.sender == pendingGov, "!PendingGov");
      _;
  }
}