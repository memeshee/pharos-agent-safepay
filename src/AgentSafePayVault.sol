// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AgentSafePayVault
 * @notice Policy wallet for AI agents that need bounded payment authority on Pharos.
 * @dev Owner configures recipients and daily limits. Agent can execute allowed payments.
 */
contract AgentSafePayVault {
    error NotOwner();
    error NotAgentOrOwner();
    error Paused();
    error InvalidAddress();
    error InvalidAmount();
    error RecipientNotAllowed(address recipient);
    error DailyLimitExceeded(address token, uint256 requested, uint256 remaining);
    error DuplicatePayment(bytes32 paymentId);
    error NativeTransferFailed();
    error TokenTransferFailed(address token);
    error ReentrantCall();

    event AgentUpdated(address indexed previousAgent, address indexed newAgent);
    event RecipientUpdated(address indexed recipient, bool allowed);
    event DailyLimitUpdated(address indexed token, uint256 limit);
    event PausedUpdated(bool paused);
    event Deposited(address indexed sender, address indexed token, uint256 amount);
    event PaymentExecuted(
        bytes32 indexed paymentId,
        address indexed token,
        address indexed recipient,
        address operator,
        uint256 amount,
        uint256 day,
        uint256 spentAfter,
        bytes32 memoHash
    );
    event Swept(address indexed token, address indexed recipient, uint256 amount);

    address public owner;
    address public agent;
    bool public paused;

    mapping(address recipient => bool allowed) public allowedRecipients;
    mapping(address token => uint256 limit) public dailyLimits;
    mapping(address token => mapping(uint256 day => uint256 spent)) public spentByDay;
    mapping(bytes32 paymentId => bool used) public usedPaymentIds;

    uint256 private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAgentOrOwner() {
        if (msg.sender != agent && msg.sender != owner) revert NotAgentOrOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    /**
     * @notice Creates a SafePay vault with the deployer as owner.
     * @param initialAgent Address allowed to execute payments, or zero to set later.
     */
    constructor(address initialAgent) {
        owner = msg.sender;
        agent = initialAgent;
        emit AgentUpdated(address(0), initialAgent);
    }

    receive() external payable {
        emit Deposited(msg.sender, address(0), msg.value);
    }

    /**
     * @notice Updates the agent executor address.
     * @param newAgent New executor address.
     */
    function setAgent(address newAgent) external onlyOwner {
        address previousAgent = agent;
        agent = newAgent;
        emit AgentUpdated(previousAgent, newAgent);
    }

    /**
     * @notice Pauses or unpauses agent payments.
     * @param newPaused Pause state.
     */
    function setPaused(bool newPaused) external onlyOwner {
        paused = newPaused;
        emit PausedUpdated(newPaused);
    }

    /**
     * @notice Allows or blocks a payment recipient.
     * @param recipient Recipient address to update.
     * @param allowed Whether the recipient is allowed.
     */
    function setRecipientAllowed(address recipient, bool allowed) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        allowedRecipients[recipient] = allowed;
        emit RecipientUpdated(recipient, allowed);
    }

    /**
     * @notice Sets the daily spending limit for a token.
     * @param token Token address, or zero address for native PHRS.
     * @param amount Daily limit amount in token base units.
     */
    function setDailyLimit(address token, uint256 amount) external onlyOwner {
        dailyLimits[token] = amount;
        emit DailyLimitUpdated(token, amount);
    }

    /**
     * @notice Deposits native PHRS into the vault.
     */
    function depositNative() external payable {
        if (msg.value == 0) revert InvalidAmount();
        emit Deposited(msg.sender, address(0), msg.value);
    }

    /**
     * @notice Executes an allowed native PHRS payment.
     * @param recipient Allowed recipient.
     * @param amount Amount in wei.
     * @param paymentId Unique idempotency key.
     * @param memoHash Hash of off-chain payment memo or invoice.
     */
    function payNative(
        address payable recipient,
        uint256 amount,
        bytes32 paymentId,
        bytes32 memoHash
    ) external onlyAgentOrOwner whenNotPaused nonReentrant {
        uint256 spentAfter = _consumeBudget(address(0), recipient, amount, paymentId);

        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert NativeTransferFailed();

        emit PaymentExecuted(
            paymentId,
            address(0),
            recipient,
            msg.sender,
            amount,
            _currentDay(),
            spentAfter,
            memoHash
        );
    }

    /**
     * @notice Executes an allowed ERC20 payment.
     * @param token ERC20 token address.
     * @param recipient Allowed recipient.
     * @param amount Amount in token base units.
     * @param paymentId Unique idempotency key.
     * @param memoHash Hash of off-chain payment memo or invoice.
     */
    function payERC20(
        address token,
        address recipient,
        uint256 amount,
        bytes32 paymentId,
        bytes32 memoHash
    ) external onlyAgentOrOwner whenNotPaused nonReentrant {
        if (token == address(0)) revert InvalidAddress();
        uint256 spentAfter = _consumeBudget(token, recipient, amount, paymentId);

        _safeTransfer(token, recipient, amount);

        emit PaymentExecuted(
            paymentId, token, recipient, msg.sender, amount, _currentDay(), spentAfter, memoHash
        );
    }

    /**
     * @notice Returns remaining daily spend for a token.
     * @param token Token address, or zero address for native PHRS.
     * @return remaining Amount still spendable today.
     */
    function remainingToday(address token) external view returns (uint256 remaining) {
        uint256 limit = dailyLimits[token];
        uint256 spent = spentByDay[token][_currentDay()];
        if (spent >= limit) return 0;
        return limit - spent;
    }

    /**
     * @notice Sweeps native PHRS to a recipient.
     * @param recipient Destination address.
     * @param amount Amount in wei.
     */
    function sweepNative(address payable recipient, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert NativeTransferFailed();

        emit Swept(address(0), recipient, amount);
    }

    /**
     * @notice Sweeps ERC20 tokens to a recipient.
     * @param token ERC20 token address.
     * @param recipient Destination address.
     * @param amount Amount in token base units.
     */
    function sweepERC20(address token, address recipient, uint256 amount) external onlyOwner {
        if (token == address(0) || recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        _safeTransfer(token, recipient, amount);
        emit Swept(token, recipient, amount);
    }

    function _consumeBudget(address token, address recipient, uint256 amount, bytes32 paymentId)
        internal
        returns (uint256 spentAfter)
    {
        if (recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (!allowedRecipients[recipient]) revert RecipientNotAllowed(recipient);
        if (usedPaymentIds[paymentId]) revert DuplicatePayment(paymentId);

        uint256 day = _currentDay();
        uint256 limit = dailyLimits[token];
        uint256 spent = spentByDay[token][day];
        uint256 remaining = limit > spent ? limit - spent : 0;
        if (amount > remaining) revert DailyLimitExceeded(token, amount, remaining);

        usedPaymentIds[paymentId] = true;
        spentAfter = spent + amount;
        spentByDay[token][day] = spentAfter;
    }

    function _currentDay() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function _safeTransfer(address token, address recipient, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(
                bytes4(keccak256("transfer(address,uint256)")), recipient, amount
            )
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TokenTransferFailed(token);
        }
    }
}
